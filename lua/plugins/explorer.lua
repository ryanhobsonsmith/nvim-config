return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      hidden = true,
      ignored = false,
      win = {
        input = {
          keys = {
            ["<a-h>"] = { "toggle_hidden", mode = { "i", "n" } },
          },
        },
      },
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          win = {
            list = {
              keys = {
                ["<a-h>"] = "toggle_hidden",
                ["<a-i>"] = "toggle_ignored",
                ["H"] = false,
                ["I"] = false,
              },
            },
          },
        },
      },
    },
  },
}
