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
  local key, err = M.read_api_key(tier)
  if err then
    cb(nil, err)
    return nil
  end
  local body = vim.json.encode({
    model = tier.model,
    messages = messages,
    temperature = tier.temperature or 0,
    max_tokens = tier.max_tokens,
  })
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
  if key then
    vim.list_extend(cmd, { "-H", "Authorization: Bearer " .. key })
  end
  vim.list_extend(cmd, { "-d", "@-" })

  return vim.system(cmd, { stdin = body, text = true }, function(res)
    vim.schedule(function()
      if res.signal ~= 0 then
        return cb(nil, "cancelled")
      end
      if res.code ~= 0 then
        return cb(nil, "request failed: " .. vim.trim((res.stderr ~= "" and res.stderr) or res.stdout or ""))
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
