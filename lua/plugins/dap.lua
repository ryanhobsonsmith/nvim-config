return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>do", false },
      { "<leader>dO", false },
      { "<leader>dt", false },
      {
        "<leader>do",
        function()
          local dap = require("dap")
          dap.step_over()
          while true do
            local ok, char = pcall(vim.fn.getcharstr)
            if not ok or char ~= "o" then
              if ok and char and char ~= "" then
                vim.api.nvim_feedkeys(char, "n", false)
              end
              return
            end
            dap.step_over()
          end
        end,
        desc = "Step Over (press o to repeat)",
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
