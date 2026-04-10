-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
map({ "n", "v", "o" }, "B", "^", { desc = "First non-blank character" })
map({ "n", "v", "o" }, "E", "$", { desc = "End of line" })
map("n", "ZZ", "<cmd>wa<cr><cmd>qa<cr>", { desc = "Write all and quit all" })

map("n", "gyp", function()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank relative path" })

map("n", "gyP", function()
  local path = vim.api.nvim_buf_get_name(0)
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank absolute path" })
