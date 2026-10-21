return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      diagnostics = {
        virtual_text = false,
        virtual_lines = { current_line = true },
      },
      servers = {
        -- vscode-html-language-server (mason: html-lsp). nvim-lspconfig's default
        -- init_options enable embeddedLanguages css/javascript, so <style> and
        -- <script> blocks get same-file definition/references/symbols/hover and
        -- completion. Snippet capability comes from blink.cmp via LazyVim.
        html = {},
        ["*"] = {
          -- Free up insert-mode <c-k> for blink.cmp's completion-menu
          -- navigation (see lua/plugins/blink.lua). LazyVim binds this to
          -- signature_help by default; that keymap gets re-registered as a
          -- buffer-local override whenever an LSP client with signatureHelp
          -- support attaches (including copilot.lua's pseudo-LSP on
          -- `:Copilot enable`), clobbering blink's mapping. gK in normal
          -- mode still shows signature help.
          keys = {
            { "<c-k>", false, mode = "i" },
          },
        },
      },
    },
  },
  -- mason's clangd package has no Linux arm64 build, so there the lang.clangd
  -- extra's install fails ("The current platform is unsupported") on every
  -- file open. Use the system clangd instead (`apt install clangd`). Only
  -- touches clangd when the extra (gated on a compiler) already added it.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if opts.servers.clangd and jit.os == "Linux" and jit.arch == "arm64" then
        opts.servers.clangd.mason = false
      end
      return opts
    end,
  },
}
