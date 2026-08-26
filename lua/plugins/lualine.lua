return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- neo-review.nvim agent status icon, bottom right: ⏸N red = pending
      -- approvals, ● orange = working, ● green = idle, ○ dim = starting;
      -- hidden when the agent is stopped. Appended to lualine_x (not _z:
      -- the z-section's mode-colored background fights the diagnostic-linked
      -- icon colors). Guard checks the FUNCTION, not just the module: an
      -- installed neo-review predating the component must leave this inert.
      local ok, neo_review = pcall(require, "neo-review")
      if ok and type(neo_review.lualine) == "function" then
        table.insert(opts.sections.lualine_x, neo_review.lualine())
      end
      return opts
    end,
  },
}
