-- Replaces nvim-dap-ui (pulled in by the dap.core extra) with nvim-dap-view:
-- a single split with a winbar of switchable sections instead of dap-ui's
-- multi-pane sidebar + tray layout. Requires neovim 0.11+.
--
-- dap-ui's `<leader>du` / `<leader>de` keymaps live on its own spec, so
-- disabling it takes them with it — they are re-pointed at dap-view below.

return {
  -- Disable the dap.core extra's UI. `enabled = false` also drops the keymaps
  -- and the dap listeners the extra registered in its config function.
  { "rcarriga/nvim-dap-ui", enabled = false },

  -- dap-view registers its auto_toggle listeners (before.launch/before.attach)
  -- when it loads. Lazy-loading it on its own keymaps means those listeners
  -- don't exist yet when <leader>dc starts a session, so nothing opens until
  -- the first <leader>du. Making nvim-dap depend on it guarantees it is loaded
  -- by the time a session can start.
  { "mfussenegger/nvim-dap", dependencies = { "igorlfs/nvim-dap-view" } },

  {
    "igorlfs/nvim-dap-view",
    version = "^1.0.0", -- upstream ships semver tags; stay off breaking 2.x
    dependencies = { "mfussenegger/nvim-dap" },
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("dap-view").toggle() end, desc = "Dap View" },
      { "<leader>de", function() require("dap-view").hover() end, desc = "Eval (hover)", mode = { "n", "x" } },
      { "<leader>dw", function() require("dap-view").add_expr() end, desc = "Watch Expression", mode = { "n", "x" } },
    },
    opts = {
      winbar = {
        -- Trimmed from the default list: "exceptions" is rarely reached for.
        -- "console" is added so adapter output is reachable in this same
        -- window (press C) now that the terminal gets no window of its own.
        sections = { "watches", "scopes", "breakpoints", "threads", "repl", "console" },
        default_section = "scopes",
        show_keymap_hints = false,
      },
      windows = {
        size = 0.25,
        position = "below",
        terminal = {
          -- Never give the debuggee terminal a window: it otherwise claims a
          -- split on session start, and then a second nested split alongside
          -- the views window on toggle. `true` means "hide for all adapters";
          -- the buffer is still created and can be opened manually.
          hide = true,
        },
      },
      -- Opens the view when a session starts, but doesn't auto-close it when
      -- the session ends -- "true" did both and closing was unwanted (e.g.
      -- <leader>td on Odin tests would hide an already-open console). Manual
      -- close via <leader>du.
      auto_toggle = "open",
    },
    config = function(_, opts)
      -- LazyVim's default config for a plugin is just setup(opts), so it has
      -- to be called explicitly when overriding config.
      require("dap-view").setup(opts)

      -- The bottom split that appeared on session start was nvim-dap's, not
      -- dap-view's: when an adapter sends a `runInTerminal` reverse request,
      -- nvim-dap creates the debuggee terminal via
      -- `dap.defaults.fallback.terminal_win_cmd`, which defaults to the string
      -- "belowright new" — i.e. it opens a window. dap-view then adopts that
      -- buffer, which is why its own `windows.terminal.hide` had no effect.
      --
      -- terminal_win_cmd may instead be a function returning (bufnr, winnr?),
      -- and the winnr is optional (see create_terminal_buf in dap/session.lua).
      -- Returning a bare buffer gives the debuggee a terminal with no window;
      -- dap-view's "console" section renders it inside the views window.
      require("dap").defaults.fallback.terminal_win_cmd = function()
        return vim.api.nvim_create_buf(false, true)
      end
    end,
  },
}
