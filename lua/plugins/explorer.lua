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
          actions = {
            yank_relative_path = function(_, item)
              if item and item.file then
                local path = vim.fn.fnamemodify(item.file, ":.")
                vim.fn.setreg("+", path)
                vim.notify("Copied: " .. path)
              end
            end,
            yank_absolute_path = function(_, item)
              if item and item.file then
                vim.fn.setreg("+", item.file)
                vim.notify("Copied: " .. item.file)
              end
            end,
          },
          win = {
            list = {
              keys = {
                ["<a-h>"] = "toggle_hidden",
                ["<a-i>"] = "toggle_ignored",
                ["H"] = false,
                ["I"] = false,
                ["gyp"] = "yank_relative_path",
                ["gyP"] = "yank_absolute_path",
              },
            },
          },
        },
      },
    },
  },
}
