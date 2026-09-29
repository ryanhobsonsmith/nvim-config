-- quill-ai: fast, targeted AI edits from inside Neovim.
--
--   :QuillDocs [lite|normal|full]   doc comment for the function under the cursor
--   :QuillFast [instruction]        rewrite the selection (or whole file) per instruction (fast tier)
--   :Quill [instruction]            same, with the normal tier (ChatGPT plan via Codex login)
--   :QuillCancel                    kill the in-flight request
--
-- Model, endpoint, and key configuration lives in the `opts` passed to
-- `setup()` (see lua/plugins/quill-ai.lua). See config.lua for defaults.

local config = require("quill-ai.config")
local util = require("quill-ai.util")

local M = {}

local active = nil ---@type vim.SystemObj|nil

--- Records (or clears, with nil) the in-flight request handle.
function M.track(handle)
  active = handle
end

function M.busy()
  return active ~= nil
end

function M.cancel()
  if not active then
    return util.notify("nothing in flight")
  end
  active:kill(15)
  active = nil
end

local function register_commands()
  local docs = require("quill-ai.docs")
  local refactor = require("quill-ai.refactor")

  vim.api.nvim_create_user_command("QuillDocs", function(cmd)
    local range = util.range_from_cmd(cmd)
    local level = cmd.fargs[1]
    if level then
      docs.generate(level, range)
    else
      docs.pick(range)
    end
  end, {
    nargs = "?",
    range = true,
    complete = function()
      return config.options.docs.levels
    end,
    desc = "Quill: generate a doc comment for the function under the cursor",
  })

  for tier_name, cmd_name in pairs(config.options.commands) do
    vim.api.nvim_create_user_command(cmd_name, function(cmd)
      local range = util.range_from_cmd(cmd)
      local instruction = table.concat(cmd.fargs, " ")
      if instruction ~= "" then
        return refactor.run(tier_name, instruction, range)
      end
      vim.ui.input({ prompt = "Quill (" .. tier_name .. "): " }, function(input)
        if input and vim.trim(input) ~= "" then
          refactor.run(tier_name, input, range)
        end
      end)
    end, {
      nargs = "*",
      range = true,
      desc = ("Quill: rewrite the selection or file with the %s model"):format(tier_name),
    })
  end

  vim.api.nvim_create_user_command("QuillCancel", M.cancel, { desc = "Quill: cancel the in-flight request" })
end

function M.setup(opts)
  config.setup(opts)
  register_commands()
end

return M
