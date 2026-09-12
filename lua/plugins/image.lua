-- Inline image viewer (snacks.image, Kitty graphics protocol).
--
-- Opening a png/jpg/pdf/... renders the image in the buffer; markdown/html/tsx
-- etc. render referenced images inline below the reference (`doc.inline`).
-- SVGs open as XML; `:ImageView` / <leader>iv previews one in a float.
--
-- How this survives tmux + ssh + ghostty (see CLAUDE.md "Images"):
--   * tmux: snacks wraps every graphics escape in a DCS passthrough
--     (`ESC P tmux; ... ESC \`) and uses *unicode placeholders* (U=1), so tmux
--     just sees text cells and scrolls/moves the image like any other text.
--     Requires `allow-passthrough` (already on in ~/.tmux.conf; snacks also
--     sets it to `all` on its own pane).
--   * ssh: snacks detects SSH_CONNECTION/SSH_CLIENT and switches from
--     transfer-by-filename (t=f, needs a shared filesystem) to sending the
--     image bytes inline as base64 chunks (t=d), which works over any pipe.
--   * ghostty: fully supports the protocol incl. placeholders. BUT inside tmux
--     snacks identifies the outer terminal via `#{client_termname}`, and
--     ~/.ssh/config forces `SetEnv TERM=xterm-256color`, so over ssh the name
--     is `xterm-256color` and detection fails ("terminal does not support the
--     kitty graphics protocol"). SNACKS_GHOSTTY is snacks's documented
--     override for exactly this; the base terminal is always ghostty, so it's
--     set unconditionally. Remove it (or set it to "false") if you ever run
--     this config under a terminal without kitty-graphics support.
vim.env.SNACKS_GHOSTTY = "true"

return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    image = {
      enabled = true,
      -- `formats` is left at snacks's default, which does NOT include `svg`:
      -- SVGs open as editable XML, and `:ImageView` (below) previews any file
      -- ImageMagick can rasterize -- svg included -- in a float on demand.
      -- Surface ImageMagick / mermaid conversion failures instead of showing
      -- a blank placeholder.
      convert = { notify = true },
    },
  },
  keys = {
    { "<leader>iv", "<cmd>ImageView<cr>", desc = "Preview file as image" },
  },
  init = function()
    -- Workaround for a snacks bug (present upstream as of 882c996, 2026-05):
    -- when an image buffer loses its last window (`:e other`), `update()`
    -- calls `placement:hide()`, and nothing ever calls `show()` again on the
    -- file-viewer path. Re-showing the buffer re-renders the placeholder grid
    -- with `hidden` still set, i.e. blank. Symptom: an image opens once, then
    -- switching back to it shows nothing until `:bd` + `:e`.
    --
    -- Fix: make `hide()` a no-op for file-viewer placements (buffer filetype
    -- "image"). Hiding is pointless there anyway -- the buffer has no window,
    -- so there is nothing to conceal -- and the next `update()` on re-show
    -- sees a changed window state and renders normally. Inline document
    -- images (markdown etc.) keep the real `hide()`; they rely on it for the
    -- cursor-line conceal toggle. `hide` is looked up via the metatable at
    -- call time, so patching the module method once is enough; it's done on
    -- the first `FileType image` so the module is guaranteed loaded and no
    -- snacks module is required before `Snacks.setup()` has run.
    --
    -- Don't "fix" this by re-attaching (`Snacks.image.buf.attach`) instead:
    -- closing a placement whose conversion spinner is still running leaves
    -- its progress timer alive forever, and it clears the buffer's extmark
    -- namespace every 80ms -- every later render in that buffer gets wiped.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("image_reshow", { clear = true }),
      pattern = "image",
      once = true,
      callback = function()
        local P = require("snacks.image.placement")
        local hide = P.hide
        P.hide = function(self, ...)
          if vim.api.nvim_buf_is_valid(self.buf) and vim.bo[self.buf].filetype == "image" then
            return
          end
          return hide(self, ...)
        end
      end,
    })

    -- `:ImageView`: preview the current buffer's file as an image in a
    -- centered float (q / <esc> closes). Used for svg, which opens as XML by
    -- default, but works for anything snacks can convert. Mirrors snacks's
    -- own markdown hover (`snacks.image.doc.hover`): open a scratch window
    -- hidden, create the placement on its buffer, and let the first
    -- `on_update_pre` size the window to the fitted image before showing it.
    -- Bypasses `Snacks.image.buf.attach`, whose `supports_file` check would
    -- reject svg now that it's not in `formats`. Nothing here can write the
    -- source file: the float's buffer is a scratch buffer.
    vim.api.nvim_create_user_command("ImageView", function()
      local file = vim.api.nvim_buf_get_name(0)
      if file == "" or vim.fn.filereadable(file) == 0 then
        return vim.notify("No readable file in current buffer", vim.log.levels.WARN)
      end
      if not Snacks.image.supports_terminal() then
        return vim.notify("Terminal does not support the kitty graphics protocol", vim.log.levels.WARN)
      end
      local win = Snacks.win({
        show = false,
        enter = true,
        focusable = true,
        relative = "editor",
        position = "float",
        border = "rounded",
        backdrop = 60,
        title = " " .. vim.fn.fnamemodify(file, ":t") .. " ",
        title_pos = "center",
        wo = { winblend = 0 },
        keys = { q = "close", ["<esc>"] = "close" },
      })
      win:open_buf()
      local img ---@type snacks.image.Placement
      local shown = false
      img = Snacks.image.placement.new(win.buf, file, {
        inline = false,
        -- leave room for the border and a margin
        max_width = vim.o.columns - 6,
        max_height = vim.o.lines - 6,
        on_update_pre = function()
          if not shown then
            shown = true
            local loc = img:state().loc
            win.opts.width = loc.width
            win.opts.height = loc.height
            win:show()
          end
        end,
      })
      win:on("WinClosed", function()
        img:close()
      end, { win = true })
    end, { desc = "Preview current file as an image (float)" })

    -- `:ImageSource`: the inverse, for formats snacks *does* intercept (png,
    -- jpg, pdf, ...). Reopens the file as plain text for editing. `noautocmd`
    -- bypasses the BufReadCmd; the buffer-local BufWriteCmd does a real write,
    -- because snacks's global BufWriteCmd for image formats only clears
    -- `modified` without touching the file.
    vim.api.nvim_create_user_command("ImageSource", function()
      local file = vim.api.nvim_buf_get_name(0)
      if file == "" then
        return vim.notify("No file in current buffer", vim.log.levels.WARN)
      end
      vim.cmd("noautocmd edit " .. vim.fn.fnameescape(file))
      -- `:edit` reloads into the same buffer, which snacks left nomodifiable.
      vim.bo.modifiable = true
      vim.cmd("filetype detect")
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = 0,
        callback = function()
          vim.cmd("noautocmd write")
        end,
      })
    end, { desc = "Open image file as text (e.g. SVG source)" })
  end,
}
