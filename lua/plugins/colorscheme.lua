return {
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000,
    opts = {
      highlights = {
        DiffAdd = { bg = "#1e4620" },
        DiffDelete = { bg = "#542426" },
        DiffChange = { bg = "#3b3920" },
        DiffText = { bg = "#4e4b2a" },
        DiffviewDiffAdd = { bg = "#1e4620" },
        DiffviewDiffAddAsDelete = { bg = "#542426" },
        DiffviewDiffChange = { bg = "#3b3920" },
        DiffviewDiffText = { bg = "#4e4b2a" },
        DiffviewDiffDeleteDim = { fg = "#5c6370" },
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
}
