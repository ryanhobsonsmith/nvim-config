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
      -- LazyVim's <leader>da wraps config.args in a function that prompts, and
      -- stores that wrapper in the opts nvim-dap keeps for run_last(), so
      -- <leader>dl re-prompted every time. nvim-dap keeps the config and opts
      -- tables by reference, so this version prompts once, writes the parsed
      -- args back into the config, and drops the hook — run_last() then reuses
      -- the args silently. Press <leader>da again to change them; the prompt
      -- pre-fills with the previous value.
      {
        "<leader>da",
        function()
          local opts = {}
          opts.before = function(config)
            local prev = type(config.args) == "function" and (config.args() or {}) or config.args or {}
            local default = type(prev) == "table" and table.concat(prev, " ") or prev
            local input = vim.fn.expand(vim.fn.input("Run with args: ", default))
            config.args = require("dap.utils").splitstr(input)
            opts.before = nil
            return config
          end
          require("dap").continue(opts)
        end,
        desc = "Run with Args (remembered by Run Last)",
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
