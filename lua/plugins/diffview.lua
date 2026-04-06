-- Default folds to open in DiffView. Toggled at runtime via <leader>gz.
vim.g.diffview_unfold = true

local function toggle_folds()
  vim.g.diffview_unfold = not vim.g.diffview_unfold
  local level = vim.g.diffview_unfold and 99 or 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_get_option_value("diff", { win = win }) then
      vim.api.nvim_set_option_value("foldlevel", level, { win = win })
    end
  end
  vim.notify("DiffView folds: " .. (vim.g.diffview_unfold and "expanded" or "collapsed"))
end

local function open_or_focus(cmd)
  return function()
    local ok, lib = pcall(require, "diffview.lib")
    if ok then
      for _, view in ipairs(lib.views or {}) do
        if view.tabpage and vim.api.nvim_tabpage_is_valid(view.tabpage) then
          vim.api.nvim_set_current_tabpage(view.tabpage)
          return
        end
      end
    end
    vim.cmd(cmd)
  end
end

return {
  -- Disable LazyVim's default <leader>gD ("Git Diff (origin)" via snacks.picker)
  -- so our DiffviewOpen mapping below always wins.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gD", false },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gD", open_or_focus("DiffviewOpen"), desc = "Diffview Open" },
      { "<leader>gF", open_or_focus("DiffviewFileHistory %"), desc = "Diffview File History" },
      { "<leader>gB", open_or_focus("DiffviewFileHistory"), desc = "Diffview Branch History" },
      { "<leader>gQ", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gZ", toggle_folds, desc = "Diffview Toggle Folds" },
    },
    opts = {
      enhanced_diff_hl = true,
      hooks = {
        -- Open all folds by default (unchanged regions stay visible).
        -- foldlevel is window-local, so set it on win-enter, not buf-read.
        diff_buf_win_enter = function(_, winid)
          local level = vim.g.diffview_unfold and 99 or 0
          vim.api.nvim_set_option_value("foldlevel", level, { win = winid })
        end,
      },
    },
    init = function()
      -- Close Diffview before persistence.nvim saves the session, otherwise
      -- restoring leaves stale diff:// buffers without the file panel.
      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        group = vim.api.nvim_create_augroup("diffview_close_before_session_save", { clear = true }),
        callback = function()
          if package.loaded["diffview"] then
            pcall(vim.cmd, "DiffviewClose")
          end
        end,
      })
    end,
  },
}
