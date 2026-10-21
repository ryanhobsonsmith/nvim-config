return {
  -- Disable treesitter highlighting for markdown
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = {
        disable = { "markdown", "markdown_inline" },
      },
    },
  },
}
