-- Single-file C task provider for overseer — the <leader>rr counterpart to the
-- build-and-debug entry dap-c.lua contributes to the <leader>dc picker.
--
-- overseer's builtin make/just providers already discover targets in projects
-- with a Makefile/justfile. This fills the gap for a lone .c file (an exercise,
-- a scratch program), which those providers can't see because there's no
-- manifest — without this, <leader>rr would be empty for such a buffer.
--
-- Discovered by runtimepath: overseer globs `lua/overseer/template/**/*.lua`
-- over the whole rtp, and ~/.config/nvim is on it. The file existing here is the
-- wiring; no registration call needed.
local constants = require("overseer.constants")
local TAG = constants.TAG

-- gcc/clang diagnostics look like:
--   /abs/path/foo.c:12:5: error: expected ';'
-- %trror/%tarning capture the E/W type char so failures land in the quickfix
-- list with the right severity (<leader>rr → task list → `o` opens output).
local ERRORFORMAT = table.concat({
  [[%f:%l:%c: %trror: %m]],
  [[%f:%l:%c: %tarning: %m]],
  [[%f:%l:%c: %m]],
}, ",")

-- First available C compiler, preferring the system default `cc`.
local function compiler()
  for _, cc in ipairs({ "cc", "clang", "gcc" }) do
    if vim.fn.executable(cc) == 1 then
      return cc
    end
  end
end

return {
  condition = {
    filetype = { "c" },
  },
  generator = function(opts)
    local cc = compiler()
    if not cc then
      return 'No C compiler ("cc"/"clang"/"gcc") found'
    end

    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
      return {}
    end
    local name = vim.fn.fnamemodify(file, ":t:r")
    local out_dir = vim.fn.stdpath("cache") .. "/c-dap"
    -- ld can't create the output dir itself, so ensure it exists before the
    -- compile task runs (dap-c.lua does the same for its build).
    vim.fn.mkdir(out_dir, "p")
    local exe = out_dir .. "/" .. name

    -- Run from the repo root rather than the file's dir so relative asset paths
    -- resolve the way they do under the debugger (dap-c.lua launches with
    -- cwd = ${workspaceFolder}).
    local root = vim.fn.getcwd()

    ---@param label string
    ---@param cmd string|string[]
    ---@param tags string[]
    local function task(label, cmd, tags)
      return {
        name = string.format("c %s (%s)", label, name),
        tags = tags,
        builder = function()
          return {
            cmd = cmd,
            cwd = root,
            default_component_params = { errorformat = ERRORFORMAT },
          }
        end,
      }
    end

    local compile = { cc, "-g", "-Wall", "-Wextra", file, "-o", exe }

    -- overseer runs a *string* cmd through the shell, so run = compile then, on
    -- success, execute the binary. A list cmd (build/check) runs without a shell.
    local run = string.format(
      "%s -g -Wall -Wextra %s -o %s && %s",
      cc,
      vim.fn.shellescape(file),
      vim.fn.shellescape(exe),
      vim.fn.shellescape(exe)
    )

    return {
      task("run", run, { TAG.RUN }),
      task("build", compile, { TAG.BUILD }),
      -- Parse without codegen — a fast syntax/type check.
      task("check", { cc, "-fsyntax-only", "-Wall", "-Wextra", file }, {}),
    }
  end,
}
