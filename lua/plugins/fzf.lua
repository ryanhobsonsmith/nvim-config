return {
  {
    "ibhagwan/fzf-lua",
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
