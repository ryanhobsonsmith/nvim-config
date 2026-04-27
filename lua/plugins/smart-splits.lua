local function smartMove(dir)
  return function()
    vim.cmd("stopinsert")
    require("smart-splits")["move_cursor_" .. dir]()
  end
end

return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  keys = {
    { "<C-h>", smartMove("left"), mode = { "n", "i", "t" }, desc = "Move to left split/pane" },
    { "<C-j>", smartMove("down"), mode = { "n", "i", "t" }, desc = "Move to below split/pane" },
    { "<C-k>", smartMove("up"), mode = { "n", "i", "t" }, desc = "Move to above split/pane" },
    { "<C-l>", smartMove("right"), mode = { "n", "i", "t" }, desc = "Move to right split/pane" },
  },
}
