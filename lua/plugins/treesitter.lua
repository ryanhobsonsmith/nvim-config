return {
  -- LazyVim's base parser list includes `html` but not `css`. The html queries
  -- inject css into <style> blocks (and style="" attributes), so without the css
  -- parser those regions render as plain text. `scss` covers <style lang="scss">.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "css", "scss" } },
  },
}
