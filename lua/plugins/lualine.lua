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
    end,
  },
}
