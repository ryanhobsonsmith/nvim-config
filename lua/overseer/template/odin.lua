-- Odin task provider for overseer — the <leader>rr counterpart to the Odin
-- entries dap-odin.lua contributes to the <leader>dc picker.
--
-- Odin has no manifest file, so none of overseer's builtin providers (just,
-- npm, make, cargo, …) can discover anything in an Odin package. Without this,
-- <leader>dc offered "debug tests (pkg)" while <leader>rr had nothing to show
-- for the same buffer. Both now derive their entries from lua/odin/package.lua,
-- so they stay in agreement about what a package supports.
--
-- Discovered by runtimepath: overseer globs `lua/overseer/template/**/*.lua`
-- over the whole rtp, and ~/.config/nvim is on it. No registration call and no
-- overriding overseer's `config` — the file existing here is the wiring.
--
-- overseer passes the *current buffer's* parent directory as `opts.dir` (it
-- falls back to cwd only for unnamed/special buffers), which is exactly the
-- Odin notion of a package, so no upward search is needed.
local constants = require("overseer.constants")
local TAG = constants.TAG

-- Odin diagnostics look like:
--   /abs/path/foo.odin(12:5) Error: undeclared identifier
-- %trror/%tarning capture the E/W type char, so failures land in the quickfix
-- list with the right severity (<leader>rr → task list → `o` opens output;
-- overseer's on_output_quickfix component consumes this).
local ERRORFORMAT = table.concat({
  [[%f(%l:%c) %trror: %m]],
  [[%f(%l:%c) %tarning: %m]],
  [[%f(%l:%c) %m]],
}, ",")

return {
  condition = {
    filetype = { "odin" },
  },
  generator = function(opts)
    if vim.fn.executable("odin") == 0 then
      return 'Command "odin" not found'
    end

    local dir = opts.dir
    local name = vim.fn.fnamemodify(dir, ":t")
    local has_main, has_test = require("odin.package").inspect(dir)

    -- Run from the repo root rather than the package dir so relative asset
    -- paths resolve the way they do under the debugger, which launches with
    -- cwd = ${workspaceFolder}. The package is addressed by absolute path.
    local root = vim.fn.getcwd()

    ---@param label string
    ---@param args string[]
    ---@param tags string[]
    local function task(label, args, tags)
      return {
        name = string.format("odin %s (%s)", label, name),
        tags = tags,
        builder = function()
          return {
            cmd = vim.list_extend({ "odin" }, args),
            cwd = root,
            default_component_params = { errorformat = ERRORFORMAT },
          }
        end,
      }
    end

    local ret = {}
    if has_test then
      -- Single-threaded to match the debug build, so interleaved output from
      -- parallel test workers doesn't scramble the log.
      table.insert(ret, task("test", { "test", dir, "-define:ODIN_TEST_THREADS=1" }, { TAG.TEST }))
    end
    if has_main then
      table.insert(ret, task("run", { "run", dir }, { TAG.RUN }))
      table.insert(ret, task("build", { "build", dir }, { TAG.BUILD }))
    end
    -- Type-check without codegen: useful for a package that is neither a main
    -- nor a test package (a library), which would otherwise offer nothing.
    table.insert(ret, task("check", { "check", dir }, {}))
    return ret
  end,
}
