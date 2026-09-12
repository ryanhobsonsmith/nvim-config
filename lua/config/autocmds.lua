-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- Re-create lazyvim_wrap_spell: keep wrap but disable spell for markdown
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_wrap_spell", { clear = true }),
  pattern = { "markdown", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

-- Also check for external file changes on CursorHold (when cursor is idle)
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("checktime_cursorhold", { clear = true }),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Autosave on focus loss / buffer leave
--
-- IMPORTANT: this `:write` runs *inside* an autocmd callback, and autocmds
-- don't nest by default (`:h autocmd-nested`), so it fires NO BufWriteCmd /
-- BufWritePre / BufWritePost. Any buffer whose file is "virtual" and owned by
-- a BufWriteCmd handler gets Neovim's plain writer instead, which dumps the
-- buffer's *display* text over the real file. Confirmed 2026-09-11: snacks
-- image buffers (filetype "image", a png opened in nvim) are flagged
-- 'modified' by snacks's own placeholder rendering, so leaving one truncated
-- the png to 0 bytes. Same class of bug as the hexview.nvim incident below.
-- Hence the filetype guards. If another BufWriteCmd-backed buffer type shows
-- up, add it here -- or switch this autocmd to `nested = true`, which makes
-- the write behave exactly like `:w` (BufWriteCmd honored, but conform's
-- format-on-save and LSP didSave then also run on every autosave).
--
-- Excludes hexview.nvim buffers (filetype "hexview") and anything with
-- 'binary' set: hexview's own render (redraw_line -> nvim_buf_set_lines)
-- flips 'modified' just from *displaying* a hex view, with zero real edits.
-- Without this guard, merely alt-tabbing away while looking at a binary's
-- hex view silently `:write`s it -- and per the above, NOT via hexview's
-- BufWriteCmd -- one step in what corrupted a real build artifact once
-- already (see lua/plugins/asm.lua for the fuller writeup and the actual
-- fix, which stops these files from ever loading as text to begin with).
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  group = vim.api.nvim_create_augroup("autosave_on_focus_lost", { clear = true }),
  callback = function()
    if
      vim.bo.modified
      and not vim.bo.readonly
      and not vim.bo.binary
      and vim.bo.filetype ~= "hexview"
      and vim.bo.filetype ~= "image"
      and vim.bo.buftype == ""
      and vim.fn.expand("%") ~= ""
    then
      vim.cmd("silent! write")
    end
  end,
})

-- Disable diagnostics for markdown files
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = function()
    vim.diagnostic.enable(false, { bufnr = 0 })
  end,
})

-- Make macro recording visually obvious: switch to a red block cursor while recording.
-- Neovim's default `guicursor` doesn't reference the `Cursor` highlight group,
-- so we swap `guicursor` itself to point at a dedicated group.
vim.api.nvim_set_hl(0, "MacroRecordingCursor", { bg = "#ff1744", fg = "#ffffff" })
local macro_cursor_group = vim.api.nvim_create_augroup("macro_recording_cursor", { clear = true })
local saved_guicursor
vim.api.nvim_create_autocmd("RecordingEnter", {
  group = macro_cursor_group,
  callback = function()
    saved_guicursor = vim.o.guicursor
    vim.o.guicursor =
      "n-v-c-sm:block-MacroRecordingCursor,i-ci-ve:ver25-MacroRecordingCursor,r-cr-o:hor20-MacroRecordingCursor"
  end,
})
vim.api.nvim_create_autocmd("RecordingLeave", {
  group = macro_cursor_group,
  callback = function()
    if saved_guicursor then
      vim.o.guicursor = saved_guicursor
    end
  end,
})
