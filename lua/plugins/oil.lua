return {
  "stevearc/oil.nvim",
  lazy = false,
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    default_file_explorer = false,
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    view_options = {
      show_hidden = true,
    },
    lsp_file_methods = {
      enabled = true,
      autosave_changes = "unmodified",
    },
    float = {
      padding = 2,
      max_width = 0.8,
      max_height = 0.8,
      border = "rounded",
    },
    keymaps = {
      ["q"] = { "actions.close", mode = "n" },
    },
  },
  keys = {
    -- {
    --   "-",
    --   function()
    --     require("oil").open()
    --   end,
    --   desc = "Oil: open parent directory",
    -- },
    {
      "<leader>o",
      function()
        require("oil").toggle_float()
      end,
      desc = "Oil: toggle floating",
    },
  },
}
