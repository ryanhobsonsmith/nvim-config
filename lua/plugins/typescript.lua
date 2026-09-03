-- Expandable TypeScript hover (`K`, then `+` / `-` to expand / collapse type
-- aliases in place). See lua/config/ts_hover.lua for the tsgo implementation.
local expandable_hover_key = {
  "K",
  function()
    require("config.ts_hover").hover()
  end,
  desc = "TypeScript expandable hover",
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Active: tsgo (native TS7 server). Selected via `vim.g.lazyvim_ts_lsp`
        -- in lua/config/options.lua. Keymaps/settings must be keyed to the active
        -- server, so this block is keyed to `tsgo`, not `vtsls`.
        tsgo = {
          -- Opt in to tsgo's expandable hover: `textDocument/hover` then accepts
          -- `verbosityLevel` and answers with `canIncreaseVerbosity`.
          capabilities = {
            experimental = { hoverVerbosityLevel = true },
          },
          keys = { expandable_hover_key },
        },
        -- ---------------------------------------------------------------------
        -- REVERT PATH: to go back to vtsls, set `vim.g.lazyvim_ts_lsp = "vtsls"`
        -- in lua/config/options.lua. This block is inert while tsgo is active
        -- (LazyVim only enables the selected server). `K` still routes through
        -- config.ts_hover, which hands off to ts-expand-hover.nvim below when no
        -- tsgo client is attached. `maxTsServerMemory` is a Node-tsserver flag
        -- (ignored by the Go server), which is why it's not in the tsgo block.
        -- ---------------------------------------------------------------------
        vtsls = {
          keys = { expandable_hover_key },
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
    -- Expandable hover for vtsls/tsserver (uses vtsls's `typescript.tsserverRequest`
    -- command, which tsgo doesn't implement). Only loaded on the vtsls path.
    "nemanjamalesija/ts-expand-hover.nvim",
    enabled = function()
      return vim.g.lazyvim_ts_lsp == "vtsls"
    end,
    ft = { "typescript", "typescriptreact" },
    opts = {
      keymaps = { hover = false },
    },
  },
}
