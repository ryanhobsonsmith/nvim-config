-- Route `:!cmd` stdout/stderr to a split so we can actually see it.
-- Without this, noice swallows shell output on nvim 0.11+ (folke/noice.nvim#1097):
-- the `msg_show` event with `kind = "shell_out"` has no default route, so `:!ls`
-- shows nothing and `:!ls -l` opens an empty popup. Routing to `view = "split"`
-- gives a scrollable, copyable buffer with the actual output.
return {
  "folke/noice.nvim",
  opts = function(_, opts)
    -- Auto-focus the shell-output split so `q` / `<Esc>` close it without
    -- having to first move the cursor over. Noice's split view already binds
    -- q and <Esc> to close; only `enter = true` is missing from the defaults.
    opts.views = opts.views or {}
    opts.views.split = vim.tbl_deep_extend("force", opts.views.split or {}, { enter = true })

    opts.routes = opts.routes or {}
    table.insert(opts.routes, {
      view = "split",
      filter = { event = "msg_show", kind = { "shell_out", "shell_err" } },
    })
    return opts
  end,
}
