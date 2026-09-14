local M = {}

--- Notifies with a stable id so successive messages replace each other.
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { id = "quill-ai", title = "Quill" })
end

--- Strips reasoning tags, markdown fences, surrounding blank lines, and trailing whitespace.
---@param text string
---@return string[]
function M.clean_reply(text)
  text = text:gsub("<think>.-</think>", "")
  text = vim.trim(text)
  -- Outer fence: ``` or ```lang on the first line AND ``` (possibly followed
  -- by stray text) on the last. Only strip when both are present, so a reply
  -- that merely ends with a fenced block keeps that block intact.
  if text:match("^```[%w_%-%.]*\n") and text:match("\n```[^\n]*$") then
    text = text:gsub("^```[%w_%-%.]*\n", ""):gsub("\n```[^\n]*$", "")
    text = vim.trim(text)
  end
  local lines = vim.split(text, "\n", { plain = true })
  for i, l in ipairs(lines) do
    lines[i] = l:gsub("%s+$", "")
  end
  return lines
end

--- Closes the current undo block so the next buffer write is its own undo step
--- (`:help undo-blocks`). Without this a write issued from a callback can merge
--- with whatever change preceded it.
function M.undo_break(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("let &l:undolevels = &undolevels")
  end)
end

--- 0-indexed inclusive line range from a user command's range, or nil.
function M.range_from_cmd(cmd)
  if cmd.range > 0 then
    return { cmd.line1 - 1, cmd.line2 - 1 }
  end
  return nil
end

return M
