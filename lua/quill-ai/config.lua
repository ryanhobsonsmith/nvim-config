local M = {}

---@class QuillTier
---@field url string OpenAI-compatible chat completions endpoint
---@field model string
---@field api_key_file string|nil read at call time
---@field api_key_env string|nil environment variable holding the key (takes precedence)
---@field timeout_s integer
---@field max_tokens integer
---@field temperature number
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
  },
  -- Refactor command name per tier. Adding a tier = a `tiers` entry + a line here.
  commands = {
    fast = "QuillFast",
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
