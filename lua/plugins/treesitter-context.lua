return {
  "nvim-treesitter/nvim-treesitter-context",
  opts = {
    max_lines = 8,
    multiline_threshold = 2,
    -- Per-window context. With the default (false), side-by-side diffs
    -- (codediff, :diffsplit) oscillate because scrollbind fires updates in
    -- both panes and the single shared context fights over which window
    -- owns it. Per-window also means each diff pane gets its own header.
    multiwindow = true,
    on_attach = function(buf)
      -- multiwindow + WinResized iterates every window, including non-code
      -- panels like the CodeDiff explorer. Attempting get_parser on those
      -- buffers causes event churn that leads to context oscillation.
      local bt = vim.bo[buf].buftype
      if bt == "nofile" or bt == "prompt" or bt == "terminal" then
        return false
      end
    end,
  },
}
