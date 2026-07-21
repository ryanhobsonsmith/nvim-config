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
}
