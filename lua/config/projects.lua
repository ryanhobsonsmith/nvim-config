-- Centralized per-project preferences.
--
-- Rules are keyed by directory prefix and matched against the directory a
-- consumer is operating in (a picker's cwd, or Neovim's cwd). Keeping the
-- table here in the dotfiles — instead of dropping `.nvim.lua` / `.lazy.lua`
-- files into each repo — means no trust prompts and no stray files in work
-- repos; the tradeoff is that this file hardcodes machine-specific paths.
--
-- Consumers call `require("config.projects").get(key, path)`. Resolution:
-- the deepest rule in M.projects whose directory contains `path` AND defines
-- `key` wins; otherwise M.defaults[key].
--
-- Currently wired up:
--   hide_tests → default for the snacks picker test-file filter
--                (lua/plugins/snacks.lua); <a-t> still toggles per picker.
local M = {}

-- Applied when no project rule matches.
M.defaults = {
  hide_tests = false, -- show test files in pickers by default
}

-- Directory-prefix rules (`~` is expanded). A rule covers the directory
-- itself and everything beneath it; nested rules override outer ones for
-- the keys they define.
M.projects = {
  ["~/algebralabs"] = { hide_tests = true },
}

---@param key string preference name (e.g. "hide_tests")
---@param path? string directory to resolve for; defaults to the current cwd
---@return any # value from the deepest matching project rule, else M.defaults[key]
function M.get(key, path)
  path = vim.fs.normalize(path or vim.uv.cwd() or "")
  local value, depth = M.defaults[key], -1
  for dir, prefs in pairs(M.projects) do
    if prefs[key] ~= nil then
      dir = vim.fs.normalize(dir)
      -- Prefix match on a path-component boundary, so ~/algebralabs matches
      -- ~/algebralabs/foo but not ~/algebralabs-archive.
      if (path == dir or path:sub(1, #dir + 1) == dir .. "/") and #dir > depth then
        value, depth = prefs[key], #dir
      end
    end
  end
  return value
end

return M
