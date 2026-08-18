-- Shared Odin package introspection.
--
-- Both the dap config provider (lua/plugins/dap-odin.lua, feeding <leader>dc)
-- and the overseer template provider (lua/overseer/template/odin.lua, feeding
-- <leader>tr) need the same question answered about the directory holding the
-- current buffer: does this package have an entry point, and does it have
-- tests? Odin has no manifest file — no Cargo.toml, no package.json — so the
-- only way to know is to read the .odin files. Keeping that in one module is
-- what makes the two pickers agree on what a package can do.
local M = {}

---What kind of package is this directory: does it have an entry point, tests?
---@param dir string Absolute path to a directory of .odin files
---@return boolean has_main, boolean has_test
function M.inspect(dir)
  local has_main, has_test = false, false
  for _, file in ipairs(vim.fn.glob(dir .. "/*.odin", false, true)) do
    if file:match("_test%.odin$") then
      has_test = true
    end
    for _, line in ipairs(vim.fn.readfile(file)) do
      if line:match("main%s*::%s*proc") then
        has_main = true
      elseif line:match("^%s*@%(test%)") or line:match("@%(test%)") then
        has_test = true
      end
    end
  end
  return has_main, has_test
end

return M
