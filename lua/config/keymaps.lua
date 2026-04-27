-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
map({ "n", "v", "o" }, "B", "^", { desc = "First non-blank character" })
map({ "n", "v", "o" }, "E", "$", { desc = "End of line" })
map("n", "ZZ", "<cmd>wa<cr><cmd>qa<cr>", { desc = "Write all and quit all" })

map("n", "<C-d>", "<C-d>zz", { desc = "Half page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up and center" })

-- Macro recording on Q instead of q to avoid accidental triggers.
map("n", "Q", "q", { desc = "Record macro / stop recording" })
map("n", "q", "<Nop>", { desc = "Macro recording disabled (use Q)" })

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

-- Cycle diagnostic virtual_lines: off → current line only → all
local diag_states = {
  { virtual_lines = false },
  { virtual_lines = { current_line = true } },
  { virtual_lines = true },
}
local diag_labels = { "off", "current line", "all" }
local diag_idx = 2
map("n", "<leader>uv", function()
  diag_idx = diag_idx % #diag_states + 1
  vim.diagnostic.config(diag_states[diag_idx])
  vim.notify("Diagnostic virtual lines: " .. diag_labels[diag_idx])
end, { desc = "Cycle diagnostic virtual lines" })

-- Swap LazyVim defaults: <leader>uz → zoom, <leader>uZ → zen.
-- Deferred until VeryLazy because Snacks is not yet loaded when this file runs.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    Snacks.toggle.zoom():map("<leader>uz")
    Snacks.toggle.zen():map("<leader>uZ")
  end,
})
