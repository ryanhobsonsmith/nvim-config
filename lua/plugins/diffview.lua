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
    init = function()
      -- When CodeDiff switches to single-pane mode (untracked/added/deleted
      -- files), the kept window still has scrollbind=true from the previous
      -- split view. Scrollbind + treesitter-context's multiwindow WinResized
      -- handler creates a feedback loop that makes the context header
      -- oscillate. Clear scrollbind once the single-pane transition settles.
      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeDiffFileSelect",
        callback = function(args)
          vim.schedule(function()
            vim.schedule(function()
              local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
              if not ok then
                return
              end
              local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
              local session = lifecycle.get_session(tabpage)
              if session and session.single_pane then
                local win = session.original_win or session.modified_win
                if win and vim.api.nvim_win_is_valid(win) then
                  vim.wo[win].scrollbind = false
                end
              end
            end)
          end)
        end,
      })
    end,
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
