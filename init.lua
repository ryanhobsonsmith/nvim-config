-- If nvim was launched with a directory argument (e.g. `nvim ~/projects/foo`),
-- cd into it *before* anything else runs so plugins, LSP, pickers, and lualine
-- all see the intended project root as cwd from the start.
do
  local arg = vim.fn.argv(0)
  if type(arg) == "string" and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
    vim.cmd.cd(vim.fn.fnamemodify(arg, ":p"))
  end
end

-- Leaders must be set before any `<leader>…` mapping is registered — otherwise
-- `<leader>` resolves to the default `\` at registration time and the map
-- ends up bound to the wrong key. LazyVim's options.lua sets these too, but
-- that runs after config.lazy below.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Load keymaps eagerly (before lazy.nvim) so they're active from the first
-- keystroke. LazyVim normally loads user keymaps on VeryLazy, but that leaves
-- a startup window where multi-char mappings like `gyp` fall through to vim
-- defaults (e.g. `p` pasting). Note that `require` caches this module, so the
-- VeryLazy re-load is actually a no-op — this eager call is the only one.
require("config.keymaps")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
