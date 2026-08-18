-- Wire the vendored Odin adapter (lua/neotest-odin/) into neotest, so Odin
-- tests answer to the same <leader>tt/tl/tf/ta/td keymaps as everything else.
--
-- No plugin dependency: ~/.config/nvim/lua is on the runtimepath, so neotest
-- resolves the adapter by `require("neotest-odin")`. See the adapter's header
-- for why it's vendored rather than pulled from upstream.
--
-- Gated on the odin toolchain the same way lua/plugins/odin.lua and
-- lua/plugins/dap-odin.lua are, so machines without Odin don't register an
-- adapter that can never produce results.
if vim.fn.executable("odin") ~= 1 then
  return {}
end

return {
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["neotest-odin"] = {},
      },
    },
  },
}
