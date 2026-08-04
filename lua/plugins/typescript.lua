return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Active: tsgo (native TS7 server). Selected via `vim.g.lazyvim_ts_lsp`
        -- in lua/config/options.lua. Keymaps/settings must be keyed to the active
        -- server, so this block is keyed to `tsgo`, not `vtsls`.
        tsgo = {
          keys = {
            {
              "K",
              function()
                -- NOTE: ts-expand-hover.nvim was built against tsserver/vtsls;
                -- its behavior against the native tsgo server is untested. If it
                -- errors, comment this keymap out to fall back to plain LSP hover.
                require("ts_expand_hover").hover()
              end,
              desc = "TypeScript expandable hover",
            },
          },
        },
        -- ---------------------------------------------------------------------
        -- REVERT PATH: to go back to vtsls, set `vim.g.lazyvim_ts_lsp = "vtsls"`
        -- in lua/config/options.lua and swap the `tsgo` key above back to the
        -- block below. `maxTsServerMemory` is a Node-tsserver flag (ignored by the
        -- Go server), which is why it's not in the tsgo block above.
        -- ---------------------------------------------------------------------
        -- vtsls = {
        --   keys = {
        --     {
        --       "K",
        --       function()
        --         require("ts_expand_hover").hover()
        --       end,
        --       desc = "TypeScript expandable hover",
        --     },
        --   },
        --   settings = {
        --     typescript = {
        --       tsserver = {
        --         maxTsServerMemory = 8192,
        --       },
        --     },
        --   },
        -- },
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
