local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Build spec with conditional extras based on available tooling.
-- This lets the same config work across machines with different dev environments.
-- Order matters: lazyvim.plugins -> lazyvim.plugins.extras -> user plugins
local spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  -- Always-on extras (no external tooling required)
  { import = "lazyvim.plugins.extras.coding.mini-surround" },
  { import = "lazyvim.plugins.extras.ui.treesitter-context" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.lang.yaml" },
}

if vim.fn.executable("go") == 1 then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.go" })
end
if vim.fn.executable("python3") == 1 then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.python" })
end
if vim.fn.executable("node") == 1 then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.typescript" })
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.typescript.biome" })
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.tailwind" })
  table.insert(spec, { import = "lazyvim.plugins.extras.ai.copilot" })
  table.insert(spec, { import = "lazyvim.plugins.extras.ai.avante" })
end
if vim.fn.executable("docker") == 1 then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.docker" })
end
if vim.fn.executable("psql") == 1 or vim.fn.executable("mysql") == 1 or vim.fn.executable("sqlite3") == 1 then
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.sql" })
end

-- User plugins must come last to override defaults
table.insert(spec, { import = "plugins" })

require("lazy").setup({
  spec = spec,
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
