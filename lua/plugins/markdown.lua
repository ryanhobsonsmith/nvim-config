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

  -- Disable render-markdown by default (toggle with :RenderMarkdown toggle)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      enabled = false,
    },
  },
}
