return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        -- Show only snippet completions (Alt-s in insert mode)
        ["<A-s>"] = {
          function(cmp)
            return cmp.show({ providers = { "snippets" } })
          end,
        },
      },
    },
  },
}
