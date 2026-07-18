-- Odin language support: ols LSP + Tree-sitter parser. There is no LazyVim
-- extra for Odin, so this is a manual server spec. ols comes from brew
-- (`brew install ols`), hence mason = false.
if vim.fn.executable("ols") ~= 1 then
  return {}
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ols = { mason = false },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "odin" } },
  },
}
