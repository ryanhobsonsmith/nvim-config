-- Shell script LSP: bash-language-server (document symbols, go-to-definition
-- for functions/vars, hover for builtins, completion). It shells out to
-- shellcheck for diagnostics when the binary is present, so install that too.
-- Formatting is already handled by shfmt via conform (see conform.lua).
--
-- Covers ft=sh and ft=bash. That includes .shellrc / chezmoi dot_shellrc
-- (forced to sh in chezmoi.lua). Deliberately NOT attached to ft=zsh:
-- bashls parses everything as bash, so zsh-specific syntax in .zshrc would
-- produce false diagnostics.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shellcheck" } },
  },
}
