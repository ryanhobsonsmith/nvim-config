local M = {}

---@class QuillTier
---@field url string chat-completions endpoint, or the Codex responses endpoint when auth == "codex"
---@field model string
---@field auth "key"|"codex"|nil "codex" = reuse the Codex CLI's ChatGPT login (~/.codex/auth.json)
---@field auth_file string|nil override for the Codex auth.json path
---@field originator string|nil `originator` header sent to the Codex backend
---@field api_key_file string|nil read at call time (auth == "key")
---@field api_key_env string|nil environment variable holding the key (takes precedence)
---@field timeout_s integer
---@field max_tokens integer
---@field temperature number|false false omits the field (models that only accept the default)
---@field max_tokens_field string|nil "max_tokens" (default) or "max_completion_tokens"
---@field apply "direct"|"diff" how refactor results land in the buffer

M.defaults = {
  tiers = {
    fast = {
      url = "https://inference.celeris.ai/celeris-1/v1/chat/completions",
      model = "celeris-1",
      api_key_file = "~/.config/celeris/api-key",
      api_key_env = nil,
      timeout_s = 60,
      max_tokens = 4096,
      temperature = 0,
      apply = "direct",
    },
    -- ChatGPT plan through the Codex CLI login: no API key, Responses API,
    -- no token cap or temperature (the backend rejects both).
    normal = {
      auth = "codex",
      url = "https://chatgpt.com/backend-api/codex/responses",
      model = "gpt-6-luna",
      auth_file = "~/.codex/auth.json",
      timeout_s = 180,
      apply = "direct",
    },
  },
  -- Refactor command name per tier. Adding a tier = a `tiers` entry + a line here.
  commands = {
    fast = "QuillFast",
    normal = "Quill",
  },
  docs = {
    tier = "fast",
    max_file_lines = 400,
    window = 60,
    levels = { "lite", "normal", "full" },
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

---@return QuillTier|nil, string|nil
function M.tier(name)
  local t = M.options.tiers[name]
  if not t then
    return nil, "unknown tier '" .. tostring(name) .. "'"
  end
  return t
end

return M
