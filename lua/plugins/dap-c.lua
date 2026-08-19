-- C debugging via codelldb.
--
-- LazyVim's lang.clangd extra already registers the generic C/C++ dap configs
-- ("Launch file" prompts for a prebuilt binary, "Attach to process"). Those
-- cover project-built binaries (Make/Just). This file adds the single-file
-- counterpart: a *config provider* (`:help dap-providers`) that compiles the
-- buffer you're sitting in with debug info and debugs it, mirroring the pattern
-- in dap-odin.lua.
--
-- Providers run fresh on every dap.continue(), so the build-and-debug entry
-- shows up at the top of the <leader>dc picker alongside launch.json and the
-- extra's generic configs. Nothing clobbers the extra's configs; this is purely
-- additive.
if vim.fn.executable("cc") ~= 1 and vim.fn.executable("gcc") ~= 1 and vim.fn.executable("clang") ~= 1 then
  return {}
end

local out_dir = vim.fn.stdpath("cache") .. "/c-dap"

-- First available C compiler, preferring the system default `cc`.
local function compiler()
  for _, cc in ipairs({ "cc", "clang", "gcc" }) do
    if vim.fn.executable(cc) == 1 then
      return cc
    end
  end
end

-- Compile a single source file with debug info and return the exe path, or nil
-- on failure. `-Wall -Wextra` so the build surfaces the same warnings the run
-- tasks (lua/overseer/template/c.lua) do.
local function build(file)
  vim.fn.mkdir(out_dir, "p")
  local program = out_dir .. "/" .. vim.fn.fnamemodify(file, ":t:r")
  local cmd = { compiler(), "-g", "-Wall", "-Wextra", file, "-o", program }

  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("C build failed:\n" .. (result.stderr or "") .. (result.stdout or ""), vim.log.levels.ERROR)
    return nil
  end
  return program
end

-- Build a dap config for `file`. `program` is a function so the build runs when
-- the config is actually selected, not when the picker is populated.
local function c_config(file)
  return {
    name = "C: debug file (" .. vim.fn.fnamemodify(file, ":t") .. ")",
    type = "codelldb",
    request = "launch",
    program = function()
      return build(file)
    end,
    -- Repo root, not the file's dir, so relative asset paths resolve the same
    -- way they do for a normal run (matches the overseer template's cwd).
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  }
end

return {
  {
    -- Backstop: dap-odin.lua only ensures codelldb when Odin is installed, so a
    -- machine that does C but not Odin would miss it. lazy.nvim merges the two
    -- specs' ensure_installed lists.
    "jay-babu/mason-nvim-dap.nvim",
    opts = { ensure_installed = { "codelldb" } },
  },
  {
    "mfussenegger/nvim-dap",
    -- Register the provider via `opts`, not `init`. dap-odin.lua already claims
    -- nvim-dap's `init`, and lazy.nvim keeps only the last `init` when merging
    -- fragments (it's a scalar field). `opts` functions, by contrast, compose —
    -- lazy chains every fragment's opts function — so both providers survive.
    -- The function still runs even though LazyVim's nvim-dap `config` ignores
    -- opts: lazy always evaluates opts before calling config.
    opts = function(_, opts)
      local dap = require("dap")

      -- Offer a build-and-debug entry for the current C/C++ buffer. The "0."
      -- prefix sorts it ahead of "dap.launch.json"/"dap.global" (nvim-dap
      -- concatenates providers in sorted key order), putting it at the top of
      -- the <leader>dc picker — same placement as dap-odin.lua's provider.
      dap.providers.configs["0.c.file"] = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft ~= "c" and ft ~= "cpp" then
          return {}
        end
        local file = vim.api.nvim_buf_get_name(bufnr)
        if file == "" then
          return {}
        end
        return { c_config(file) }
      end

      return opts
    end,
    -- Shortcut that skips the picker and builds+debugs the current file.
    -- stylua: ignore
    keys = {
      {
        "<leader>dF",
        function()
          require("dap").run(c_config(vim.api.nvim_buf_get_name(0)))
        end,
        desc = "Debug C File (build current)",
        ft = { "c", "cpp" },
      },
    },
  },
}
