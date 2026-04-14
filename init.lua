-- If nvim was launched with a directory argument (e.g. `nvim ~/projects/foo`),
-- cd into it *before* anything else runs so plugins, LSP, pickers, and lualine
-- all see the intended project root as cwd from the start.
do
  local arg = vim.fn.argv(0)
  if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
    vim.cmd.cd(vim.fn.fnamemodify(arg, ":p"))
  end
end

-- Load keymaps eagerly (before lazy.nvim) so they're active from the first
-- keystroke. LazyVim normally loads user keymaps on VeryLazy, but that leaves
-- a startup window where multi-char mappings like `gyp` fall through to vim
-- defaults (e.g. `p` pasting). LazyVim will re-load this file later on
-- VeryLazy; re-setting the same keymaps is a no-op.
require("config.keymaps")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
