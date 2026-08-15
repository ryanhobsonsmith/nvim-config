-- overseer.nvim: the non-debug counterpart to <leader>dc.
--
-- <leader>dc (nvim-dap's continue()) pops a picker of *debug* configurations
-- gathered from providers — dap globals, .vscode/launch.json, and the odin
-- provider in dap-odin.lua. <leader>rr is the same idea for plain runs:
-- overseer probes the project and offers whatever it finds.
--
-- Discovery is the whole reason for the plugin. yeet.nvim already re-runs a
-- command well, but it can't tell you what commands a project *has*; overseer
-- ships template providers for just, npm, make, cargo, mise, deno, Taskfile,
-- mix, rake and tox, so the picker fills itself in.
--
-- Note on launch.json: overseer reads .vscode/tasks.json, NOT launch.json.
-- launch.json is debug configuration and stays in the <leader>dc picker where
-- nvim-dap parses it. The two pickers are complementary, not overlapping —
-- with `dap = true` below, a launch.json `preLaunchTask` resolves to an
-- overseer task, which is the one place they meet.

-- Match the save-before-run idiom used by yeet.lua and neotest-vitest.lua:
-- run against what's on disk, not a stale save. `silent!` swallows E141 for
-- unnamed/readonly buffers, which would otherwise abort before the run.
local function save_all_then(fn)
  return function()
    vim.cmd("silent! wall")
    fn()
  end
end

return {
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerInfo" },
    opts = {
      -- Patch nvim-dap so launch.json preLaunchTask/postDebugTask resolve to
      -- overseer tasks. Guarded because nvim-dap only exists when the dap.core
      -- extra is imported (see lua/config/lazy.lua) — enabling this without it
      -- errors inside overseer's setup.
      dap = LazyVim.has("nvim-dap"),
      task_list = {
        -- Bottom, matching where dap-view puts its panels.
        direction = "bottom",
        min_height = 12,
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>r", "", desc = "+run" },
      {
        "<leader>rr",
        save_all_then(function() vim.cmd("OverseerRun") end),
        desc = "Run Task (picker)",
      },
      { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle Task List" },
      {
        "<leader>ra",
        function()
          local overseer = require("overseer")
          local tasks = overseer.list_tasks()
          if vim.tbl_isempty(tasks) then
            return vim.notify("No tasks found", vim.log.levels.WARN)
          end
          overseer.run_action(tasks[1])
        end,
        desc = "Task Action (most recent)",
      },
      {
        "<leader>rl",
        save_all_then(function()
          local overseer = require("overseer")
          local tasks = overseer.list_tasks({
            status = { overseer.STATUS.SUCCESS, overseer.STATUS.FAILURE, overseer.STATUS.CANCELED },
            sort = require("overseer.task_list").sort_finished_recently,
          })
          if vim.tbl_isempty(tasks) then
            return vim.notify("No finished tasks to restart", vim.log.levels.WARN)
          end
          overseer.run_action(tasks[1], "restart")
        end),
        desc = "Restart Last Task",
      },
      {
        -- The bridge asked for: use overseer purely as the discovery/picker
        -- layer, then hand the chosen command to yeet's current target (tmux
        -- pane or terminal buffer).
        --
        -- Deliberately NOT a custom overseer strategy. overseer v2 dropped the
        -- `terminal` and `toggleterm` strategies, and a fire-and-forget
        -- `tmux send-keys` can't report an exit code — overseer's status
        -- tracking and problem matchers would show "ran" with no pass/fail.
        -- autostart = false means overseer builds the task (resolving template
        -- params) but never spawns it, so yeet is the only thing that runs it.
        "<leader>ry",
        save_all_then(function()
          require("overseer").run_task({ autostart = false }, function(task)
            if not task then
              return
            end
            local cmd = type(task.cmd) == "table" and table.concat(task.cmd, " ") or task.cmd
            -- Templates carry their own cwd (e.g. the dir holding the
            -- justfile). yeet's target sits in whatever directory it was
            -- started in, so prefix a cd when they disagree.
            if task.cwd and task.cwd ~= vim.uv.cwd() then
              cmd = "cd " .. vim.fn.shellescape(task.cwd) .. " && " .. cmd
            end
            -- The task exists only to produce this string; dispose it so it
            -- doesn't linger in the task list as permanently PENDING.
            task:dispose()
            require("yeet").execute(cmd)
          end)
        end),
        desc = "Yeet Task (pick → tmux/terminal)",
      },
    },
  },
}
