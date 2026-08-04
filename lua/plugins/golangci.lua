-- golangci-lint runs as an LSP server (golangci-lint-langserver) instead of
-- through nvim-lint. nvim-lint spawns linters from Neovim's cwd, so in a repo
-- whose go.mod lives in a subdirectory every Go file drowns in bogus typecheck
-- diagnostics ("could not import ...", "undefined: ..."); the LSP route roots
-- itself at the nearest go.work/go.mod per buffer. See
-- https://github.com/LazyVim/LazyVim/discussions/6676
return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    -- Must be a function: `linters_by_ft = { go = {} }` cannot clear the
    -- lang.go extra's entry, since lazy.nvim's opts merge treats an empty
    -- table as nothing-to-override.
    opts = function(_, opts)
      if opts.linters_by_ft then
        opts.linters_by_ft.go = nil
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        golangci_lint_ls = {},
      },
    },
  },
}
