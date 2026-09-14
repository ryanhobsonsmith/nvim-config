-- Filetype -> language spec. Each spec lives in its own module and is
-- required on first use.
--
-- Spec fields:
--   name        human name for the prompt
--   decl_types  set of Tree-sitter node types that are function declarations
--   resolve     optional fn(node) -> node|nil; adjusts a matched node (e.g. climb
--               to a wrapping `export_statement`) or returns nil to reject it
--   doc_types   set of comment node types that count as an existing doc comment
--               (placement "above" only)
--   placement   "above" (default) or "inside" (docstring as first body statement)
--   style       prose describing the language's doc-comment conventions
--   levels      per-level instructions, each with an example of the shape
--   wrap        optional fn(lines) -> lines; adds delimiters if the model omitted them

local M = {}

local aliases = {
  typescriptreact = "typescript",
  javascriptreact = "javascript",
}

local modules = {
  odin = true,
  typescript = true,
  javascript = true,
  go = true,
  c = true,
  python = true,
}

local cache = {}

---@param ft string
---@return table|nil
function M.get(ft)
  local name = aliases[ft] or ft
  if not modules[name] then
    return nil
  end
  if not cache[name] then
    cache[name] = require("quill-ai.langs." .. name)
  end
  return cache[name]
end

--- Registers or replaces a spec at runtime (for user-defined languages).
function M.register(ft, spec)
  modules[ft] = true
  cache[ft] = spec
end

function M.supported()
  local out = vim.tbl_keys(modules)
  vim.list_extend(out, vim.tbl_keys(aliases))
  table.sort(out)
  return out
end

return M
