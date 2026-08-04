-- Odin debugging: nvim-dap-odin adds :OdinBuild / :OdinDebug on top of the
-- dap.core extra. :OdinDebug builds the nearest main package with -debug and
-- launches a codelldb session in one step; the usual nvim-dap keymaps
-- (<leader>db breakpoints, <leader>dc continue, dap-ui panes) all apply.
--
-- Prefer :OdinDebugHere (defined below): it builds the package containing the
-- CURRENT BUFFER and starts the session immediately. Upstream :OdinDebug has
-- two gotchas in a multi-package repo: it locates the main package by
-- searching upward from Neovim's cwd (so from a repo root it finds nothing),
-- and it only builds — the session then has to be launched separately with
-- <leader>dc.
--
-- The codelldb adapter is installed via mason below; the dap.core extra's
-- mason-nvim-dap automatic handlers register it with nvim-dap.
if vim.fn.executable("odin") ~= 1 then
  return {}
end

return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = { ensure_installed = { "codelldb" } },
  },
  {
    "NANDquark/nvim-dap-odin",
    ft = "odin",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- Build into nvim's cache dir instead of the plugin default, which drops
      -- an executable named `debug` into the package's source directory.
      require("nvim-dap-odin").setup({
        output_dir = vim.fn.stdpath("cache") .. "/nvim-dap-odin",
      })

      -- Build and debug the package containing the current buffer, in one step.
      vim.api.nvim_create_user_command("OdinDebugHere", function()
        local dir = vim.fn.expand("%:p:h")
        local root = vim.fn.getcwd()
        -- The plugin's build searches from cwd, so point cwd at the buffer's
        -- package for the duration of the build.
        vim.cmd.cd(vim.fn.fnameescape(dir))
        local ok, program = pcall(require("nvim-dap-odin").build, "debug", "debug")
        vim.cmd.cd(vim.fn.fnameescape(root))
        if not ok or not program then
          return
        end
        require("dap").run({
          name = "Odin: " .. vim.fn.fnamemodify(dir, ":t"),
          type = "codelldb",
          request = "launch",
          program = program,
          cwd = root,
        })
      end, { desc = "Build and debug the current buffer's Odin package" })

      -- If the project vendors LLDB formatters for Odin types (spacesim has
      -- tools/odin_lldb.py), load them into every session so strings, slices,
      -- and maps render readably. Done via the on_config listener — which
      -- transforms each config at session start — because nvim-dap-odin
      -- (re)registers dap.configurations.odin on a 100ms defer, clobbering
      -- anything patched onto the table directly.
      require("dap").listeners.on_config["odin-lldb-formatters"] = function(cfg)
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
    end,
  },
}
