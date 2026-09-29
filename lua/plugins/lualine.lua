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

      -- quill-ai in-flight status (spinner, label, elapsed); empty when idle.
      -- The plugin fires `User QuillStatus` on every tick, so refresh on that
      -- instead of relying on lualine's own timer.
      table.insert(opts.sections.lualine_x, {
        function()
          local okq, quill = pcall(require, "quill-ai")
          return okq and quill.status() or ""
        end,
        color = "Special",
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "QuillStatus",
        callback = function()
          require("lualine").refresh({ place = { "statusline" } })
        end,
      })
      return opts
    end,
  },
}
