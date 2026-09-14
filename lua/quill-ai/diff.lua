-- Side-by-side preview of a proposed edit. The scratch buffer holds the whole
-- file with the region swapped for the proposal; accept writes only the
-- region back into the original buffer.

local util = require("quill-ai.util")

local M = {}

---@class QuillDiffOpts
---@field bufnr integer original buffer
---@field region {[1]: integer, [2]: integer} 0-indexed inclusive rows being replaced
---@field lines string[] proposed replacement for the region
---@field tick integer changedtick of `bufnr` when the proposal was generated
---@field on_accept fun()|nil
---@field on_reject fun()|nil

---@param opts QuillDiffOpts
function M.open(opts)
  local bufnr, region, lines = opts.bufnr, opts.region, opts.lines
  local orig_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(orig_win) ~= bufnr then
    orig_win = vim.fn.bufwinid(bufnr)
    if orig_win == -1 then
      return util.notify("buffer is not visible; cannot preview", vim.log.levels.WARN)
    end
  end

  local proposed = vim.api.nvim_buf_get_lines(bufnr, 0, region[1], false)
  vim.list_extend(proposed, lines)
  vim.list_extend(proposed, vim.api.nvim_buf_get_lines(bufnr, region[2] + 1, -1, false))

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, proposed)
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false
  vim.bo[scratch].modifiable = false
  vim.bo[scratch].filetype = vim.bo[bufnr].filetype
  vim.api.nvim_buf_set_name(scratch, "quill://proposal/" .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t"))

  vim.api.nvim_set_current_win(orig_win)
  vim.cmd("diffthis")
  vim.cmd("vsplit")
  local scratch_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(scratch_win, scratch)
  vim.cmd("diffthis")
  vim.api.nvim_win_set_cursor(scratch_win, { region[1] + 1, 0 })

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(scratch_win) then
      vim.api.nvim_win_close(scratch_win, true)
    end
    if vim.api.nvim_win_is_valid(orig_win) then
      vim.api.nvim_win_call(orig_win, function()
        vim.cmd("diffoff")
      end)
    end
  end

  local function accept()
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_changedtick(bufnr) ~= opts.tick then
      close()
      return util.notify("buffer changed since the proposal was made; not applying", vim.log.levels.WARN)
    end
    util.undo_break(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, region[1], region[2] + 1, false, lines)
    close()
    util.notify("applied")
    if opts.on_accept then
      opts.on_accept()
    end
  end

  local function reject()
    close()
    util.notify("rejected")
    if opts.on_reject then
      opts.on_reject()
    end
  end

  local kopts = { buffer = scratch, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", accept, vim.tbl_extend("force", kopts, { desc = "Quill: accept proposal" }))
  vim.keymap.set("n", "ga", accept, vim.tbl_extend("force", kopts, { desc = "Quill: accept proposal" }))
  vim.keymap.set("n", "q", reject, vim.tbl_extend("force", kopts, { desc = "Quill: reject proposal" }))

  -- `:q` or `:bd` on the scratch buffer counts as a reject; make sure the
  -- original window leaves diff mode either way.
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = scratch,
    once = true,
    callback = function()
      if not closed then
        closed = true
        if vim.api.nvim_win_is_valid(orig_win) then
          vim.api.nvim_win_call(orig_win, function()
            vim.cmd("diffoff")
          end)
        end
      end
    end,
  })

  util.notify("preview: <CR>/ga accept, q reject")
end

return M
