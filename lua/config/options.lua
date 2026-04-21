-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only run Prettier when the project has a Prettier config file. Combined with
-- Biome's `require_cwd = true`, this prevents both formatters from running in
-- the same buffer — each project uses whichever it has configured.
vim.g.lazyvim_prettier_needs_config = true

-- Branch on SSH_CONNECTION: pbcopy/pbpaste locally (bypasses the terminal
-- escape chain entirely — reliable in tmux popups and nested panes), OSC 52
-- over SSH (the only path that can reach the local clipboard from a remote
-- host). See CLAUDE.md "Clipboard provider" for the full rationale.
vim.g.clipboard = vim.env.SSH_CONNECTION
    and {
      name = "OSC 52 (remote)",
      copy = {
        ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
        ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
      },
      paste = {
        ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
        ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
      },
    }
  or {
    name = "pbcopy/pbpaste (local)",
    copy = {
      ["+"] = { "pbcopy" },
      ["*"] = { "pbcopy" },
    },
    paste = {
      ["+"] = { "pbpaste" },
      ["*"] = { "pbpaste" },
    },
  }
