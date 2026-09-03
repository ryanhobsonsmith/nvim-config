-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Load syntax/nasm.vim (NASM-specific directives/macros) instead of the stock
-- generic syntax/asm.vim for .asm files. filetype/detect.lua's asm() feeds
-- this value straight into `filetype` itself, so ft becomes "nasm", not
-- "asm" — that's read at detection time, so setting it here (before any file
-- opens) applies deterministically, unlike trying to override 'syntax' via a
-- FileType autocmd later (races against runtime/syntax/syntax.vim's own
-- FileType* listener that resyncs syntax to filetype — lost every time).
-- There's no ftplugin/nasm.vim, so after/ftplugin/nasm.lua restores what
-- ftplugin/asm.vim would otherwise have set (commentstring, matchit), and
-- lua/plugins/asm.lua's asm_lsp filetypes include "nasm" to match.
vim.g.asmsyntax = "nasm"

-- Only run Prettier when the project has a Prettier config file. Combined with
-- Biome's `require_cwd = true`, this prevents both formatters from running in
-- the same buffer — each project uses whichever it has configured.
vim.g.lazyvim_prettier_needs_config = true

-- TypeScript LSP server. Default is "vtsls" (Node tsserver wrapper). "tsgo" uses
-- the native Go-based server from @typescript/native-preview (TS7 beta channel) —
-- much faster parsing/type-checking, but the editor integration is still in
-- transition (see nvim-lspconfig#4467) and some refactors/plugins may be missing.
-- Revert by switching this back to "vtsls" (still installed) and restarting.
vim.g.lazyvim_ts_lsp = "tsgo"

-- Scope root detection (e.g. <leader>sg "Grep Root Dir", <leader>ff) to the
-- current package, not the whole monorepo. LazyVim's default spec
-- ({ "lsp", { ".git", "lua" }, "cwd" }) resolves to the monorepo top because the
-- TS LSP roots there and `.git` only exists at the top — so Root Dir == cwd and
-- <leader>sg/<leader>sG behave identically. Putting package markers first makes
-- the nearest package.json/tsconfig.json win (vim.fs.find stops at the closest
-- ancestor), so <leader>sg = current package while <leader>sG = whole repo (cwd).
-- Inspect what wins with `:LazyRoot`.
vim.g.root_spec = { { "package.json", "tsconfig.json" }, "lsp", { ".git", "lua" }, "cwd" }

-- Shrink the window where a terminal ESC+<key> burst gets bundled into <M-key>.
-- Default 50ms is long enough that a fast Caps→Esc followed by `j` can be
-- misread as <A-j> (LazyVim's "move line down"). 10ms is well under human
-- keystroke timing locally. Real Alt+key still works in ghostty because it
-- uses CSI-u, not ESC-prefixing.
vim.opt.ttimeoutlen = 10

-- Inside tmux, disable synchronized output (DEC 2026). With termsync on, nvim
-- trusts sync frames for atomicity and never hides the cursor during redraws —
-- but tmux splits one nvim frame into several sync-wrapped flushes and re-shows
-- the cursor between them, so the white block cursor visibly "scans" the screen
-- on large redraws. With termsync off, nvim hides the cursor around each redraw
-- instead, which tmux relays. Outside tmux, sync frames reach the terminal
-- intact, so the default stays on there.
if vim.env.TMUX then
  vim.o.termsync = false
end

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
