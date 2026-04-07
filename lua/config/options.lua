-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only run Prettier when the project has a Prettier config file. Combined with
-- Biome's `require_cwd = true`, this prevents both formatters from running in
-- the same buffer — each project uses whichever it has configured.
vim.g.lazyvim_prettier_needs_config = true

-- Yank via OSC 52 (works through tmux + over SSH), paste via pbpaste locally.
-- OSC 52 paste hangs waiting for a terminal response that ghostty/tmux don't
-- reliably provide, so we use pbpaste for paste instead.
vim.g.clipboard = {
  name = "OSC 52 + pbpaste",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = { "pbpaste" },
    ["*"] = { "pbpaste" },
  },
}
