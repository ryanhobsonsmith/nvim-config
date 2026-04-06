return {
  "HiPhish/rainbow-delimiters.nvim",
  config = function()
    vim.g.rainbow_delimiters = {
      query = {
        [""] = "rainbow-delimiters",
        tsx = "rainbow-parens", -- only brackets/braces, no JSX tags
        html = "rainbow-parens",
      },
    }
  end,
}
