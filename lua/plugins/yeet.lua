-- yeet.nvim: send a command to a tmux pane or terminal buffer and re-run it
-- with a single chord, instead of retyping it or hunting through shell history.

-- Write every modified buffer before yeeting, so the command always runs
-- against what's on disk rather than a stale save. `silent!` swallows E141
-- ("no file name") for scratch/unnamed buffers and any readonly failures,
-- which would otherwise abort before the command is ever sent.
--
-- Autocmds are deliberately left on so BufWritePre formatting (conform) still
-- runs. Note this pairs oddly with `toggle_post_write()` (<leader>yo): with
-- post-write enabled, `wall` fires the yeet and then execute() fires it again.
local function save_all_then(fn)
  return function()
    vim.cmd("silent! wall")
    fn()
  end
end

return {
  {
    "samharju/yeet.nvim",
    -- dressing.nvim (suggested upstream) is commented out on purpose: it
    -- hijacks `vim.ui.select` with its own `builtin` backend, a plain j/k +
    -- <CR> list with no filtering. LazyVim already points `vim.ui.select` at
    -- the Snacks picker, so leaving dressing out makes yeet's target
    -- selection a fuzzy picker like everything else in this config.
    -- dependencies = {
    --   "stevearc/dressing.nvim", -- optional, provides sane UX
    -- },
    version = "*", -- use the latest release, remove for master
    cmd = "Yeet",
    opts = {},
    keys = {
      -- which-key group label so <leader>y shows "+yeet" instead of a bare key.
      { "<leader>y", "", desc = "+yeet" },
      {
        "<leader>yc",
        function()
          require("yeet").list_cmd()
        end,
        desc = "Command Cache",
      },
      {
        -- Double tap \ to yeet at something.
        "\\\\",
        save_all_then(function()
          require("yeet").execute()
        end),
        desc = "Yeet (Save All + Run)",
      },
      {
        -- Run command without clearing terminal, interrupt previous command.
        "<leader>\\",
        function()
          require("yeet").execute(nil, { clear_before_yeet = false, interrupt_before_yeet = true })
        end,
        desc = "Yeet (Interrupt, No Clear)",
      },
      {
        -- Yeet visual selection. Useful sending code to a repl or running multiple shell commands.
        -- Using yeet_and_run = true and clear_before_yeet = false heavily suggested, if not
        -- already set in setup.
        "\\\\",
        function()
          require("yeet").execute_selection({ yeet_and_run = true, clear_before_yeet = false })
        end,
        mode = { "v" },
        desc = "Yeet Selection",
      },
      {
        "<leader>yt",
        function()
          require("yeet").select_target()
        end,
        desc = "Select Target",
      },
      {
        "<leader>yo",
        function()
          require("yeet").toggle_post_write()
        end,
        desc = "Toggle Yeet on Write",
      },
      {
        -- Parse last command output with current vim.o.errorformat and send them to quickfix.
        "<leader>ye",
        function()
          require("yeet").setqflist({ open = true })
        end,
        desc = "Output to Quickfix",
      },
    },
  },
}
