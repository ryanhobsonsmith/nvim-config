return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>do", false },
      { "<leader>dO", false },
      { "<leader>dt", false },
      -- dap.ui.widgets.hover is superseded by dap-view's watch/hover
      -- (see dap-view.lua, which reclaims <leader>dw).
      { "<leader>dw", false },
      -- LazyVim binds do=step_out / dO=step_over; swapped here so the common
      -- one is the easier keystroke.
      --
      -- Deliberately a plain step_over: an earlier version looped on
      -- vim.fn.getcharstr() to let `o` repeat the step, but that blocks
      -- Neovim's main loop — which is where nvim-dap handles the adapter's
      -- response and moves the cursor — so every step appeared to hang until
      -- the next keypress. Repeat by holding the mapping instead.
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>dq",
        function()
          require("dap").terminate()
        end,
        desc = "Terminate",
      },
    },
  },
}
