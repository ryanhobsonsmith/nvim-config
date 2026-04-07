return {
  {
    "ibhagwan/fzf-lua",
    -- Show a colored git-status letter (M/A/D/R/?/...) before filenames in all
    -- fzf-lua pickers, not just GitFiles/GitStatus. Off by default in fzf-lua
    -- for perf on huge repos; the cost is one `git status` call per picker open.
    opts = {
      defaults = {
        git_icons = true,
      },
    },
    keys = {
      {
        "<leader>fh",
        function()
          require("fzf-lua").files({ fd_opts = "--hidden --no-ignore --exclude node_modules --exclude .git" })
        end,
        desc = "Find Files (hidden + ignored)",
      },
    },
  },
}
