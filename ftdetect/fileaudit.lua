-- fileaudit decision files (tools/fileaudit in the homelab repo write
-- <label>.decisions; syntax/fileaudit-decisions.vim highlights them).
vim.filetype.add({
  extension = {
    decisions = "fileaudit-decisions",
  },
})
