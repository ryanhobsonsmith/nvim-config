-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only run Prettier when the project has a Prettier config file. Combined with
-- Biome's `require_cwd = true`, this prevents both formatters from running in
-- the same buffer — each project uses whichever it has configured.
vim.g.lazyvim_prettier_needs_config = true

-- Use OSC 52 for clipboard so yank works through tmux to macOS system clipboard
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
  },
}
