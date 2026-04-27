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
  },
}
