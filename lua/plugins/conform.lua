return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      bash = { "shfmt" },
      c = { "clang_format" },
      cpp = { "clang_format" },
    },
  },
}
