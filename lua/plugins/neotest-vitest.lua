-- Save all modified buffers before running tests. Without this, it's easy to
-- run a test against the on-disk version of a file you've been editing and get
-- a confusing failure that doesn't match what's on screen.
local function save_and_run(fn)
  return function()
    vim.cmd("silent! wall")
    fn()
  end
end

return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "marilari88/neotest-vitest" },
    opts = {
      adapters = {
        ["neotest-vitest"] = {
          filter_dir = function(name)
            return name ~= "node_modules" and name ~= "dist" and name ~= ".next"
          end,
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>tt", save_and_run(function() require("neotest").run.run(vim.fn.expand("%")) end), desc = "Run File (Neotest)" },
      { "<leader>tT", save_and_run(function() require("neotest").run.run(vim.uv.cwd()) end), desc = "Run All Test Files (Neotest)" },
      { "<leader>tr", save_and_run(function() require("neotest").run.run() end), desc = "Run Nearest (Neotest)" },
      { "<leader>tl", save_and_run(function() require("neotest").run.run_last() end), desc = "Run Last (Neotest)" },
      { "<leader>td", save_and_run(function() require("neotest").run.run({ strategy = "dap" }) end), desc = "Debug Nearest (Neotest)" },
    },
  },
}
