return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          keys = {
            {
              "K",
              function()
                require("ts_expand_hover").hover()
              end,
              desc = "TypeScript expandable hover",
            },
          },
          settings = {
            typescript = {
              tsserver = {
                maxTsServerMemory = 8192,
              },
            },
          },
        },
      },
    },
  },
  {
    "nemanjamalesija/ts-expand-hover.nvim",
    ft = { "typescript", "typescriptreact" },
    opts = {
      keymaps = { hover = false },
    },
  },
}
