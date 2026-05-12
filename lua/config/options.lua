-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only run Prettier when the project has a Prettier config file. Combined with
-- Biome's `require_cwd = true`, this prevents both formatters from running in
-- the same buffer — each project uses whichever it has configured.
vim.g.lazyvim_prettier_needs_config = true

-- Shrink the window where a terminal ESC+<key> burst gets bundled into <M-key>.
-- Default 50ms is long enough that a fast Caps→Esc followed by `j` can be
-- misread as <A-j> (LazyVim's "move line down"). 10ms is well under human
-- keystroke timing locally. Real Alt+key still works in ghostty because it
-- uses CSI-u, not ESC-prefixing.
vim.opt.ttimeoutlen = 10

-- Branch on platform: pbcopy/pbpaste on macOS (bypasses the terminal escape
-- chain entirely — reliable in tmux popups and nested panes), OSC 52
-- everywhere else (the only path that can reach the local clipboard from a
-- Linux host or over SSH). See CLAUDE.md "Clipboard provider" for the full
-- rationale.
--
-- Previously branched on SSH_CONNECTION, but that env var doesn't propagate
-- into pre-existing tmux sessions on reattach, so nvim inside tmux saw the
-- local branch and tried pbcopy on Linux.
vim.g.clipboard = vim.fn.has("mac") == 1
    and {
      name = "pbcopy/pbpaste (macOS)",
      copy = {
        ["+"] = { "pbcopy" },
        ["*"] = { "pbcopy" },
      },
      paste = {
        ["+"] = { "pbpaste" },
        ["*"] = { "pbpaste" },
      },
    }
  or {
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
