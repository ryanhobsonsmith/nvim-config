return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      diagnostics = {
        virtual_text = false,
        virtual_lines = { current_line = true },
      },
    },
  },
}
