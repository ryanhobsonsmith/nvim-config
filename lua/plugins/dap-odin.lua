-- Odin debugging via codelldb.
--
-- This replaces the nvim-dap-odin plugin. That plugin located a package by
-- searching upward from Neovim's cwd for a `main :: proc`, which fails in a
-- multi-package repo (nothing is found from the repo root) and can't handle
-- test packages at all (they have no main). It also re-registered
-- dap.configurations.odin on a 100ms defer, clobbering anything added to it.
--
-- Instead we register a *config provider* (`:help dap-providers`). Providers
-- run fresh on every dap.continue(), so entries show up in the <leader>dc
-- picker alongside .vscode/launch.json, can inspect the current buffer to
-- target the right package, and nothing can clobber them.
--
-- Division of labour with the project's .vscode/launch.json: launch.json
-- covers prebuilt binaries (the hot-reload host, `just dev`), this provider
-- covers "build the package I'm looking at, then debug it".
if vim.fn.executable("odin") ~= 1 then
  return {}
end

local out_dir = vim.fn.stdpath("cache") .. "/odin-dap"

-- Build `dir` with debug info and return the exe path, or nil on failure.
-- `mode` is "exe" or "test"; test packages need -build-mode:test, which emits
-- the test runner as a normal executable instead of running it in a temp dir
-- the way `odin test` does.
local function build(dir, mode)
  vim.fn.mkdir(out_dir, "p")
  local name = vim.fn.fnamemodify(dir, ":t")
  local program = out_dir .. "/" .. name .. (mode == "test" and "_test" or "")
  local cmd = { "odin", "build", dir, "-debug", "-out:" .. program }
  if mode == "test" then
    vim.list_extend(cmd, {
      "-build-mode:test",
      -- Single-threaded so breakpoints hit on the main thread and stepping
      -- doesn't jump between test workers.
      "-define:ODIN_TEST_THREADS=1",
    })
  end

  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("Odin build failed:\n" .. (result.stderr or "") .. (result.stdout or ""), vim.log.levels.ERROR)
    return nil
  end
  return program
end

-- Build a dap config for `dir`. `program` is a function so the build runs when
-- the config is actually selected, not when the picker is populated.
local function odin_config(dir, mode)
  local name = vim.fn.fnamemodify(dir, ":t")
  return {
    name = mode == "test" and ("Odin: debug tests (" .. name .. ")") or ("Odin: debug package (" .. name .. ")"),
    type = "codelldb",
    request = "launch",
    program = function()
      return build(dir, mode)
    end,
    -- Repo root, not the package dir, so relative asset paths and
    -- tools/odin_lldb.py resolve the same way they do for a normal run.
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  }
end

return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = { ensure_installed = { "codelldb" } },
  },
  {
    "mfussenegger/nvim-dap",
    init = function()
      LazyVim.on_load("nvim-dap", function()
        local dap = require("dap")

        -- Offer build-and-debug entries for the package of the current buffer.
        --
        -- The "0." prefix is load-bearing: nvim-dap concatenates providers in
        -- sorted key order (`table.sort(provider_keys)` in dap.continue), so a
        -- key of "odin.package" would land these *below* "dap.global" and
        -- "dap.launch.json". Sorting ahead of them puts the buffer-derived
        -- entries at the top of the <leader>dc picker, matching where the
        -- overseer template provider puts them in <leader>rr.
        dap.providers.configs["0.odin.package"] = function(bufnr)
          if vim.bo[bufnr].filetype ~= "odin" then
            return {}
          end
          local file = vim.api.nvim_buf_get_name(bufnr)
          if file == "" then
            return {}
          end
          local dir = vim.fn.fnamemodify(file, ":h")
          -- Same package introspection the overseer template provider uses
          -- (lua/overseer/template/odin.lua), so <leader>dc and <leader>rr
          -- offer the same set of things for the buffer you're sitting in.
          local has_main, has_test = require("odin.package").inspect(dir)

          local configs = {}
          if has_test then
            table.insert(configs, odin_config(dir, "test"))
          end
          if has_main then
            table.insert(configs, odin_config(dir, "exe"))
          end
          return configs
        end

        -- Load the project's LLDB formatters for Odin types (spacesim vendors
        -- tools/odin_lldb.py) into every codelldb session, so strings, slices
        -- and maps render readably. Applies to launch.json configs too.
        dap.listeners.on_config["odin-lldb-formatters"] = function(cfg)
          if cfg.type == "codelldb" and not cfg.initCommands then
            local script = vim.fn.getcwd() .. "/tools/odin_lldb.py"
            if vim.fn.filereadable(script) == 1 then
              cfg = vim.tbl_extend("force", cfg, {
                initCommands = { "command script import " .. script },
              })
            end
          end
          return cfg
        end
      end)
    end,
    -- Shortcuts that skip the picker and go straight to the current package.
    -- stylua: ignore
    keys = {
      {
        "<leader>dT",
        function()
          local dir = vim.fn.expand("%:p:h")
          require("dap").run(odin_config(dir, "test"))
        end,
        desc = "Debug Odin Tests (current package)",
        ft = "odin",
      },
    },
  },
}
