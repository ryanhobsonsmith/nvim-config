return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      opts.sections.lualine_z = {
        function()
          return " " .. os.date("%I:%M %p")
        end,
      }
      opts.winbar = {
        lualine_c = {
          { "filename", path = 1, color = { fg = "#98c379", gui = "bold" } },
        },
      }
      opts.inactive_winbar = {
        lualine_c = {
          { "filename", path = 1, color = { fg = "#61afef" } },
        },
      }
    end,
  },
}
