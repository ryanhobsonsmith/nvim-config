-- One-shot chat completion over curl. No SDK, no streaming: the whole point
-- of the plugin is fast single-turn edits.

local M = {}

---@param tier QuillTier
---@return string|nil key, string|nil err
function M.read_api_key(tier)
  if tier.api_key_env and vim.env[tier.api_key_env] then
    return vim.env[tier.api_key_env]
  end
  if tier.api_key_file then
    local path = vim.fn.expand(tier.api_key_file)
    local f = io.open(path, "r")
    if f then
      local key = vim.trim(f:read("*a") or "")
      f:close()
      if key ~= "" then
        return key
      end
    end
    return nil, "could not read API key from " .. path
  end
  return nil
end

-------------------------------------------------------------------------------
-- ChatGPT-plan auth via the Codex CLI login (tier.auth == "codex")
-------------------------------------------------------------------------------
--
-- Codex stores its OAuth bundle in ~/.codex/auth.json. We use the access token
-- as-is and never refresh: OpenAI rotates refresh tokens on use, so a second
-- refresher would invalidate the CLI's own login. Codex refreshes its bundle
-- whenever it runs, so an expired token just means "run codex once".

local CODEX_ACCOUNT_CLAIM = "https://api.openai.com/auth"

--- Decodes a JWT payload without verifying it (we only need `exp` and the
--- account claim).
local function jwt_claims(token)
  local payload = token:match("^[^.]+%.([^.]+)%.")
  if not payload then
    return nil
  end
  payload = payload:gsub("-", "+"):gsub("_", "/")
  payload = payload .. string.rep("=", (4 - #payload % 4) % 4)
  local ok, decoded = pcall(vim.base64.decode, payload)
  if not ok then
    return nil
  end
  local ok2, claims = pcall(vim.json.decode, decoded)
  return ok2 and type(claims) == "table" and claims or nil
end

---@param tier QuillTier
---@return {token: string, account_id: string}|nil, string|nil err
function M.read_codex_auth(tier)
  local path = vim.fn.expand(tier.auth_file or "~/.codex/auth.json")
  local f = io.open(path, "r")
  if not f then
    return nil, "no Codex login at " .. path .. "; run `codex login`"
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil, path .. " is not valid JSON"
  end
  local tokens = type(data.tokens) == "table" and data.tokens or {}
  local token = tokens.access_token
  if type(token) ~= "string" or token == "" then
    return nil, path .. " has no ChatGPT login (auth_mode=" .. tostring(data.auth_mode) .. "); run `codex login`"
  end
  local claims = jwt_claims(token) or {}
  if type(claims.exp) == "number" and claims.exp <= os.time() + 60 then
    return nil, "Codex access token expired; run any `codex` command to refresh it, then retry"
  end
  local account_id = tokens.account_id
  if type(account_id) ~= "string" or account_id == "" then
    account_id = vim.tbl_get(claims, CODEX_ACCOUNT_CLAIM, "chatgpt_account_id")
  end
  if type(account_id) ~= "string" or account_id == "" then
    return nil, "could not determine the ChatGPT account id from " .. path
  end
  return { token = token, account_id = account_id }
end

--- Parses a full Responses-API SSE body into the final text.
---@return string|nil text, string|nil err, boolean truncated
function M.parse_responses_sse(body)
  local deltas, final, err, truncated = {}, nil, nil, false
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    local data = line:gsub("\r$", ""):match("^data:%s*(.*)$")
    if data and data ~= "" and data ~= "[DONE]" then
      local ok, ev = pcall(vim.json.decode, data)
      if ok and type(ev) == "table" then
        local t = ev.type
        if t == "response.output_text.delta" and type(ev.delta) == "string" then
          deltas[#deltas + 1] = ev.delta
        elseif t == "response.completed" or t == "response.incomplete" then
          local resp = ev.response or {}
          truncated = t == "response.incomplete" or resp.status == "incomplete"
          local parts = {}
          for _, item in ipairs(resp.output or {}) do
            if item.type == "message" then
              for _, c in ipairs(item.content or {}) do
                if c.type == "output_text" and type(c.text) == "string" then
                  parts[#parts + 1] = c.text
                end
              end
            end
          end
          if #parts > 0 then
            final = table.concat(parts, "")
          end
        elseif t == "response.failed" then
          err = vim.tbl_get(ev, "response", "error", "message") or "response failed"
        elseif t == "error" then
          err = ev.message or (ev.error and ev.error.message) or "stream error"
        end
      end
    end
  end
  if err then
    return nil, err, truncated
  end
  local text = final or table.concat(deltas, "")
  if text == "" then
    -- Not SSE at all? Surface whatever the server said.
    local ok, data = pcall(vim.json.decode, body)
    if ok and type(data) == "table" and data.error then
      return nil, "provider error: " .. (data.error.message or vim.inspect(data.error)), false
    end
    return nil, "empty reply from provider", truncated
  end
  return text, nil, truncated
end

---@class QuillReply
---@field content string
---@field truncated boolean true when the model hit max_tokens

--- Sends `messages` to the tier's endpoint. `cb(reply)` on success,
--- `cb(nil, err)` on failure; `err == "cancelled"` when the process was killed.
--- Returns the vim.system handle, or nil if the request never started.
---@param tier QuillTier
---@param messages table
---@param cb fun(reply: QuillReply|nil, err: string|nil)
---@return vim.SystemObj|nil
function M.request(tier, messages, cb)
  local codex = tier.auth == "codex"
  local headers, body
  if codex then
    local auth, aerr = M.read_codex_auth(tier)
    if not auth then
      cb(nil, aerr)
      return nil
    end
    -- Codex backend: Responses API, streaming and non-stored are mandatory,
    -- no token cap or temperature accepted. System text goes in `instructions`.
    local instructions, inputs = {}, {}
    for _, m in ipairs(messages) do
      if m.role == "system" then
        instructions[#instructions + 1] = m.content
      else
        inputs[#inputs + 1] = { role = m.role, content = { { type = "input_text", text = m.content } } }
      end
    end
    body = vim.json.encode({
      model = tier.model,
      instructions = #instructions > 0 and table.concat(instructions, "\n\n") or nil,
      input = inputs,
      stream = true,
      store = false,
    })
    headers = {
      "Authorization: Bearer " .. auth.token,
      "chatgpt-account-id: " .. auth.account_id,
      "OpenAI-Beta: responses=experimental",
      "originator: " .. (tier.originator or "quill-ai"),
      "Accept: text/event-stream",
    }
  else
    local key, err = M.read_api_key(tier)
    if err then
      cb(nil, err)
      return nil
    end
    -- Newer OpenAI models reject `max_tokens` (want `max_completion_tokens`)
    -- and any `temperature` other than the default, so both are per-tier.
    local payload = { model = tier.model, messages = messages }
    if tier.temperature ~= false then
      payload.temperature = tier.temperature or 0
    end
    payload[tier.max_tokens_field or "max_tokens"] = tier.max_tokens
    body = vim.json.encode(payload)
    headers = key and { "Authorization: Bearer " .. key } or {}
  end

  local cmd = {
    "curl",
    "-sS",
    "--fail-with-body",
    "-m",
    tostring(tier.timeout_s or 60),
    "-X",
    "POST",
    tier.url,
    "-H",
    "Content-Type: application/json",
  }
  for _, h in ipairs(headers) do
    vim.list_extend(cmd, { "-H", h })
  end
  vim.list_extend(cmd, { "-d", "@-" })

  return vim.system(cmd, { stdin = body, text = true }, function(res)
    vim.schedule(function()
      if res.signal ~= 0 then
        return cb(nil, "cancelled")
      end
      if res.code ~= 0 then
        local msg = vim.trim((res.stderr ~= "" and res.stderr) or "")
        local okb, errbody = pcall(vim.json.decode, res.stdout or "")
        if okb and type(errbody) == "table" and errbody.error then
          local e = errbody.error
          msg = type(e) == "table" and (e.message or vim.inspect(e)) or tostring(e)
        elseif res.stdout and res.stdout ~= "" then
          msg = msg .. " " .. vim.trim(res.stdout):sub(1, 300)
        end
        if codex and msg:find("401") then
          msg = msg .. " (Codex token rejected; run any `codex` command to refresh, then retry)"
        end
        return cb(nil, "request failed: " .. msg)
      end
      if codex then
        local text, perr, truncated = M.parse_responses_sse(res.stdout or "")
        if not text then
          return cb(nil, perr)
        end
        return cb({ content = text, truncated = truncated })
      end
      local ok, data = pcall(vim.json.decode, res.stdout)
      if not ok then
        return cb(nil, "bad JSON from provider: " .. res.stdout:sub(1, 200))
      end
      if data.error then
        return cb(nil, "provider error: " .. (data.error.message or vim.inspect(data.error)))
      end
      local choice = vim.tbl_get(data, "choices", 1)
      local content = choice and vim.tbl_get(choice, "message", "content")
      if type(content) ~= "string" or content == "" then
        return cb(nil, "empty reply from provider")
      end
      cb({ content = content, truncated = choice.finish_reason == "length" })
    end)
  end)
end

return M
