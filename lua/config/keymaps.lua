-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
map({ "n", "v", "o" }, "B", "^", { desc = "First non-blank character" })
map({ "n", "v", "o" }, "E", "$", { desc = "End of line" })
map("n", "ZZ", "<cmd>wa<cr><cmd>qa<cr>", { desc = "Write all and quit all" })

map("n", "<C-d>", "<C-d>zz", { desc = "Half page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up and center" })

map("t", "<leader><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Macro recording on Q instead of q to avoid accidental triggers.
map("n", "Q", "q", { desc = "Record macro / stop recording" })
map("n", "q", "<Nop>", { desc = "Macro recording disabled (use Q)" })

-- Yank file paths under <leader>fy* instead of gy* because LazyVim binds
-- `gy` (Goto Type Definition) as an LSP buffer-local keymap. With both `gy`
-- and `gyp` matching, Neovim waits `timeoutlen` to disambiguate — type the
-- chord at "medium" speed and you get `gy` (jump to type def) followed by a
-- stray `p` paste.
map("n", "<leader>fyp", function()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank relative path" })

map("n", "<leader>fyP", function()
  local path = vim.api.nvim_buf_get_name(0)
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank absolute path" })

-- Diagnostic virtual_lines display modes
map("n", "<leader>uva", function()
  vim.diagnostic.config({ virtual_lines = true })
  vim.notify("Diagnostic virtual lines: all")
end, { desc = "Diagnostics: show all lines" })

map("n", "<leader>uvl", function()
  vim.diagnostic.config({ virtual_lines = { current_line = true } })
  vim.notify("Diagnostic virtual lines: current line")
end, { desc = "Diagnostics: show current line" })

map("n", "<leader>uvo", function()
  vim.diagnostic.config({ virtual_lines = false })
  vim.notify("Diagnostic virtual lines: off")
end, { desc = "Diagnostics: off" })

-- Override LazyVim defaults: <leader>uz → zoom (zen removed), <leader>uZ freed for future use.
-- Deferred until VeryLazy because Snacks is not yet loaded when this file runs.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    Snacks.toggle.zoom():map("<leader>uz")
    vim.keymap.del("n", "<leader>uZ") -- LazyVim maps zoom here by default; keep the key open
  end,
})
