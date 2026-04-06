return {
  {
    "tiagovla/tokyodark.nvim",
    opts = {
      -- custom options here
    },
    config = function(_, opts)
      require("tokyodark").setup(opts) -- calling setup is optional
      -- vim.cmd([[colorscheme tokyodark]])
    end,
  },
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000,
    opts = {
      highlights = {
        -- Diff colors
        DiffAdd = { bg = "#1e4620" },
        DiffDelete = { bg = "#542426" },
        DiffChange = { bg = "#3b3920" },
        DiffText = { bg = "#4e4b2a" },
        DiffviewDiffAdd = { bg = "#1e4620" },
        DiffviewDiffAddAsDelete = { bg = "#542426" },
        DiffviewDiffChange = { bg = "#3b3920" },
        DiffviewDiffText = { bg = "#4e4b2a" },
        DiffviewDiffDeleteDim = { fg = "#5c6370" },

        -- Color Overrides
        ["@type.builtin"] = { fg = "#56b6c2" },
        ["@variable.builtin.typescript"] = { fg = "#e06c75" },
        ["@variable.member"] = { fg = "#abb2bf" },
        ["@tag.tsx"] = { fg = "#e5c07b" }, -- JSX tags: yellow
        ["@tag.builtin.tsx"] = { fg = "#e5c07b" }, -- built-in JSX tags: yellow
        ["@lsp.mod.readonly"] = { fg = "#d19a66" }, -- readonly vars: orange (like constants)
        ["@lsp.typemod.variable.defaultLibrary"] = { fg = "#e06c75" }, -- globals (document, etc): red
      },
    },
    config = function(_, opts)
      require("onedarkpro").setup(opts)
    end,
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
