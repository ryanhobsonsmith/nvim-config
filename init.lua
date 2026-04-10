-- Load keymaps eagerly (before lazy.nvim) so they're active from the first
-- keystroke. LazyVim normally loads user keymaps on VeryLazy, but that leaves
-- a startup window where multi-char mappings like `gyp` fall through to vim
-- defaults (e.g. `p` pasting). LazyVim will re-load this file later on
-- VeryLazy; re-setting the same keymaps is a no-op.
require("config.keymaps")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
