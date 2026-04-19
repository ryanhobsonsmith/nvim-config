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
  },
}
