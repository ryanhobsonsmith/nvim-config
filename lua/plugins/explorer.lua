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
          focus = "list",
          hidden = true,
          ignored = false,
          actions = {
            yank_relative_path = function(_, item)
              if not (item and item.file and item.file ~= "") then
                return
              end
              -- fnamemodify(p, ":.") returns "" when p == getcwd() exactly,
              -- so yanking the explorer root would otherwise copy nothing.
              -- Fall back to "." in that case.
              local path = vim.fn.fnamemodify(item.file, ":.")
              if path == "" then
                path = "."
              end
              vim.fn.setreg("+", path)
              vim.notify("Copied: " .. path)
            end,
            yank_absolute_path = function(_, item)
              if not (item and item.file and item.file ~= "") then
                return
              end
              vim.fn.setreg("+", item.file)
              vim.notify("Copied: " .. item.file)
            end,
            oil_open_here = function(picker, item)
              picker:close()
              if item and item.file then
                require("oil").toggle_float(item.file)
              end
            end,
            oil_open_root = function(picker)
              picker:close()
              require("oil").toggle_float(vim.fn.getcwd())
            end,
          },
          win = {
            list = {
              keys = {
                ["<a-h>"] = "toggle_hidden",
                ["<a-i>"] = "toggle_ignored",
                ["H"] = false,
                ["I"] = false,
                -- Both gy* and <leader>fy* yank the highlighted item. The
                -- leader variants exist so the same keys work inside the
                -- explorer as outside it — the global <leader>fy* in
                -- keymaps.lua reads from the current buffer, which is empty
                -- when focused on the picker buffer.
                ["gyp"] = "yank_relative_path",
                ["gyP"] = "yank_absolute_path",
                ["<leader>fyp"] = "yank_relative_path",
                ["<leader>fyP"] = "yank_absolute_path",
                ["<leader>o"] = "oil_open_here",
                ["<leader>O"] = "oil_open_root",
              },
            },
          },
        },
      },
    },
  },
}
