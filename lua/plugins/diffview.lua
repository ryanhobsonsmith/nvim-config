return {
  -- Disable LazyVim's default <leader>gD ("Git Diff (origin)" via snacks.picker)
  -- so our CodeDiff mapping below always wins.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gD", false },
    },
  },
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<leader>gD", "<cmd>CodeDiff<cr>", desc = "CodeDiff: Working Tree" },
      { "<leader>gH", "<cmd>CodeDiff history<cr>", desc = "CodeDiff: File History" },
      { "<leader>gQ", "<cmd>tabclose<cr>", desc = "CodeDiff: Close" },
    },
    opts = {
      diff = {
        layout = "side-by-side",
        original_position = "left",
        jump_to_first_change = true,
      },
      explorer = {
        position = "left",
        width = 40,
        view_mode = "tree",
      },
      history = {
        position = "left",
        width = 40,
      },
      keymaps = {
        view = {
          next_file = "<Tab>",
          prev_file = "<S-Tab>",
        },
      },
    },
  },
}
