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
      { "<leader>tt", save_and_run(function() require("neotest").run.run() end), desc = "Run Nearest (Neotest)" },
      { "<leader>tl", save_and_run(function() require("neotest").run.run_last() end), desc = "Run Last (Neotest)" },
      { "<leader>tf", save_and_run(function() require("neotest").run.run(vim.fn.expand("%")) end), desc = "Run File (Neotest)" },
      { "<leader>ta", save_and_run(function() require("neotest").run.run(vim.uv.cwd()) end), desc = "Run All Test Files (Neotest)" },
      { "<leader>td", save_and_run(function() require("neotest").run.run({ strategy = "dap" }) end), desc = "Debug Nearest (Neotest)" },
      -- The test.core extra contributes its own neotest keys; same-lhs entries
      -- above override it, but its unique keys must be disabled where they
      -- collide with our layout: tr/to belong to overseer, tT duplicates ta.
      { "<leader>tr", false },
      { "<leader>to", false },
      { "<leader>tT", false },
    },
  },
}
