-- neotest adapter for Odin.
--
-- Vendored (not depended on) from joseildofilho/neotest-odin. The Tree-sitter
-- query and the ODIN_TEST_NAMES/JSON_REPORT approach come from there — no point
-- reinventing them — but upstream is a two-star single-author repo with four
-- problems that matter here, all fixed below:
--
--   1. It `print()`s on every load and does a bare top-level `return` when the
--      parser is missing, so `require()` yields nil and neotest's adapter
--      registration throws instead of degrading. Parser detection now happens
--      lazily inside is_test_file.
--   2. It hardcoded `initCommands = { "command source ~/.lldbinit" }` on the dap
--      strategy. dap-odin.lua's `odin-lldb-formatters` listener only injects
--      tools/odin_lldb.py `if not cfg.initCommands`, so upstream would have
--      silently disabled the Odin LLDB formatters for debugged tests. We set no
--      initCommands and let that listener do its job.
--   3. Failures had no message: `short`/`errors` were left commented out. We
--      parse ODIN_TEST_GO_TO_ERROR output for inline diagnostics.
--   4. discover_positions returned "" as the id for every non-test position, so
--      every file shared one id. Only tests get a custom id now; everything else
--      falls through to neotest's path-based default.
--
-- The runner is configured entirely through compile-time `-define:` values
-- rather than CLI flags, because Odin's test runner is itself written in Odin.

local lib = require("neotest.lib")
local async = require("neotest.async")
local nio = require("nio")

---@type neotest.Adapter
local adapter = { name = "neotest-odin" }

adapter.root = lib.files.match_root_pattern(".git", "ols.json")

function adapter.filter_dir(name)
  return name ~= ".git" and name ~= "build" and name ~= "bin"
end

function adapter.is_test_file(file_path)
  if not vim.endswith(file_path, "_test.odin") then
    return false
  end
  -- Checked here rather than at module load so a missing parser degrades to
  -- "no tests found" instead of breaking adapter registration at startup.
  local ok = pcall(vim.treesitter.language.add, "odin")
  if not ok then
    vim.notify_once("neotest-odin: missing odin parser, run :TSInstall odin", vim.log.levels.WARN)
    return false
  end
  return true
end

-- Odin's `@(test)` attribute is what marks a proc as a test; the package
-- declaration supplies the namespace half of the `pkg.test_name` id that
-- ODIN_TEST_NAMES expects.
local query = [[
  (package_declaration (identifier) @namespace.name) @namespace.definition

  (procedure_declaration
    (attributes
      (attribute
        (identifier) @_attr (#eq? @_attr "test")))
    (identifier) @test.name
  ) @test.definition
]]

function adapter.discover_positions(file_path)
  local namespace = ""
  return lib.treesitter.parse_positions(file_path, query, {
    require_namespaces = false,
    nested_tests = false,
    position_id = function(position, parents)
      if position.type == "namespace" then
        namespace = position.name
      end
      -- Tests are keyed `package.test_name` so the id can be handed straight to
      -- -define:ODIN_TEST_NAMES and matched back against the JSON report.
      if position.type == "test" and namespace ~= "" then
        return namespace .. "." .. position.name
      end
      -- Files and directories keep a path-based id; returning a constant here
      -- (as upstream did) collides every file onto one node.
      local parts = { position.path }
      for _, parent in ipairs(parents) do
        table.insert(parts, parent)
      end
      table.insert(parts, position.name)
      return table.concat(parts, "::")
    end,
  })
end

-- Collect the `pkg.test` ids under the selected position, so running a file or
-- directory expands to an explicit name list rather than "everything".
local function collect_test_ids(tree)
  local ids = {}
  for _, node in tree:iter_nodes() do
    local value = node:data()
    if value.type == "test" then
      table.insert(ids, value.id)
    end
  end
  return ids
end

local function base_defines(test_names, results_path)
  return {
    -- Suppress the animated/ANSI progress UI; it corrupts captured output.
    "-define:ODIN_TEST_FANCY=false",
    "-define:ODIN_TEST_NAMES=" .. test_names,
    "-define:ODIN_TEST_JSON_REPORT=" .. results_path,
    -- Emits `/abs/path.odin(line:col):test_name() message` for each failure,
    -- which is what gives us inline diagnostics.
    "-define:ODIN_TEST_GO_TO_ERROR=true",
  }
end

---@async
---@param args neotest.RunArgs
---@return neotest.RunSpec
function adapter.build_spec(args)
  local results_path = async.fn.tempname()
  local position = args.tree:data()

  -- `odin test` takes a package directory; a file position must be widened to
  -- its containing package.
  local location = position.path
  if vim.fn.isdirectory(position.path) ~= 1 then
    location = vim.fn.fnamemodify(position.path, ":h")
  end

  local test_names = table.concat(collect_test_ids(args.tree), ",")

  if args.strategy == "dap" then
    -- -build-mode:test emits the test runner as a normal executable instead of
    -- running it in a temp dir, so codelldb can launch it. Same trick as the
    -- odin.package provider in lua/plugins/dap-odin.lua.
    local bin_path = async.fn.tempname()
    local build_command = {
      "odin",
      "build",
      location,
      "-debug",
      "-build-mode:test",
      "-out:" .. bin_path,
      -- Single-threaded so breakpoints hit on the main thread and stepping
      -- doesn't jump between test workers.
      "-define:ODIN_TEST_THREADS=1",
    }
    vim.list_extend(build_command, base_defines(test_names, results_path))

    local future = nio.control.future()
    vim.system(build_command, { text = true }, function(out)
      if out.code == 0 then
        future.set()
      else
        future.set_error((out.stderr or "") .. (out.stdout or ""))
      end
    end)
    local build_success, build_error_message = pcall(future.wait)

    return {
      cwd = location,
      context = {
        strategy = "dap",
        results_path = results_path,
        build_success = build_success,
        build_error_message = build_error_message,
      },
      strategy = {
        name = "Debug Odin Test",
        type = "codelldb",
        request = "launch",
        program = bin_path,
        cwd = "${workspaceFolder}",
        -- No initCommands on purpose: dap-odin.lua's on_config listener injects
        -- tools/odin_lldb.py only when the config doesn't already set them.
      },
    }
  end

  -- `odin test` writes the test executable to the cwd (named after the
  -- package) before running it, which litters the source tree. Point it at a
  -- temp path instead; the file is small and the OS reaps the temp dir.
  local command = { "odin", "test", location, "-out:" .. async.fn.tempname() }
  vim.list_extend(command, base_defines(test_names, results_path))

  return {
    command = command,
    cwd = location,
    context = { results_path = results_path },
  }
end

-- Parse ODIN_TEST_GO_TO_ERROR lines into per-test messages:
--   /abs/path/t_test.odin(12:2):failing_test() this should fail
local function parse_errors(output_path)
  local by_test = {}
  local ok, output = pcall(lib.files.read, output_path)
  if not ok then
    return by_test
  end
  for line in vim.gsplit(output, "\n", { plain = true }) do
    local lnum, name, message = line:match("%((%d+):%d+%):([%w_]+)%(%)%s*(.*)$")
    if lnum and name then
      by_test[name] = {
        message = vim.trim(message),
        -- neotest line numbers are 0-indexed; Odin reports 1-indexed.
        line = tonumber(lnum) - 1,
      }
    end
  end
  return by_test
end

---@async
function adapter.results(spec, result, tree)
  local results = {}

  -- A build failure means nothing ran: fail the selected node, skip the rest.
  if spec.context.strategy == "dap" and not spec.context.build_success then
    local out_path = async.fn.tempname()
    lib.files.write(out_path, spec.context.build_error_message or "build failed")
    for _, node in tree:iter_nodes() do
      results[node:data().id] = { status = "skipped" }
    end
    results[tree:data().id] = {
      status = "failed",
      short = spec.context.build_error_message,
      output = out_path,
    }
    return results
  end

  local ok, output = pcall(lib.files.read, spec.context.results_path)
  -- No report written means the package failed to compile.
  if not ok then
    for _, node in tree:iter_nodes() do
      results[node:data().id] = { status = "skipped" }
    end
    results[tree:data().id] = { status = "failed", output = result.output }
    return results
  end

  local decoded, report = pcall(vim.json.decode, output)
  if not decoded or type(report) ~= "table" or type(report.packages) ~= "table" then
    results[tree:data().id] = { status = "failed", output = result.output }
    return results
  end

  local errors = result.output and parse_errors(result.output) or {}

  for _, node in tree:iter_nodes() do
    local value = node:data()
    if value.type == "test" then
      -- Anything the runner didn't report on didn't run.
      results[value.id] = { status = "skipped" }

      local pkg, name = value.id:match("^([^.]+)%.(.+)$")
      for _, test in ipairs(report.packages[pkg] or {}) do
        if test.name == name then
          if test.success then
            results[value.id] = { status = "passed", output = result.output }
          else
            local err = errors[name]
            results[value.id] = {
              status = "failed",
              output = result.output,
              short = err and err.message or nil,
              errors = err and { { message = err.message, line = err.line } } or nil,
            }
          end
          break
        end
      end
    end
  end

  return results
end

return adapter
