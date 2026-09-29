-- In-flight indicator: an animated notification with elapsed time, a dimmed
-- highlight plus label on the lines being rewritten, and a `status()` string
-- for statuslines. Started and stopped by init.track(), so every completion,
-- error, and cancel path tears it down the same way.
--
-- No notifier or statusline dependency: the notification goes through
-- vim.notify with a fixed id (Snacks/noice replace in place), and each tick
-- fires `User QuillStatus` so a statusline can refresh itself.

local M = {}

local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local NS = vim.api.nvim_create_namespace("quill-ai-indicator")

vim.api.nvim_set_hl(0, "QuillPending", { default = true, link = "DiffChange" })
vim.api.nvim_set_hl(0, "QuillPendingLabel", { default = true, link = "Comment" })

---@class QuillIndicatorState
---@field label string
---@field started integer hrtime at start
---@field frame integer
---@field timer uv.uv_timer_t
---@field bufnr integer|nil
---@field row integer
---@field marks integer[]

local state = nil ---@type QuillIndicatorState|nil

local function elapsed_s()
  return math.floor((vim.uv.hrtime() - state.started) / 1e9)
end

local function text()
  return ("%s %s · %ds"):format(FRAMES[state.frame], state.label, elapsed_s())
end

local function clear_marks()
  if state and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_clear_namespace(state.bufnr, NS, 0, -1)
  end
end

local function tick()
  if not state then
    return
  end
  state.frame = state.frame % #FRAMES + 1
  vim.notify(text() .. "  (:QuillCancel to abort)", vim.log.levels.INFO, {
    id = "quill-ai",
    title = "Quill",
    timeout = false,
  })
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) and state.marks[1] then
    pcall(vim.api.nvim_buf_set_extmark, state.bufnr, NS, state.row, 0, {
      id = state.marks[1],
      virt_text = { { " " .. text(), "QuillPendingLabel" } },
      virt_text_pos = "eol",
    })
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "QuillStatus", modeline = false })
end

---@param opts {label: string, bufnr: integer|nil, region: {[1]: integer, [2]: integer}|nil}
function M.start(opts)
  M.stop()
  state = {
    label = opts.label,
    started = vim.uv.hrtime(),
    frame = 1,
    bufnr = opts.bufnr,
    row = opts.region and opts.region[1] or 0,
    marks = {},
    timer = vim.uv.new_timer(),
  }
  if opts.bufnr and opts.region and vim.api.nvim_buf_is_valid(opts.bufnr) then
    local last = vim.api.nvim_buf_line_count(opts.bufnr) - 1
    local s, e = math.min(opts.region[1], last), math.min(opts.region[2], last)
    state.row = s
    -- Label mark first (updated each tick), then one line highlight per row.
    state.marks[1] = vim.api.nvim_buf_set_extmark(opts.bufnr, NS, s, 0, {
      virt_text = { { " " .. text(), "QuillPendingLabel" } },
      virt_text_pos = "eol",
    })
    for row = s, e do
      vim.api.nvim_buf_set_extmark(opts.bufnr, NS, row, 0, { line_hl_group = "QuillPending" })
    end
  end
  tick()
  state.timer:start(100, 100, vim.schedule_wrap(tick))
end

function M.stop()
  if not state then
    return
  end
  state.timer:stop()
  state.timer:close()
  clear_marks()
  state = nil
  vim.api.nvim_exec_autocmds("User", { pattern = "QuillStatus", modeline = false })
end

--- Short status string while a request is active, else "". For statuslines.
function M.status()
  if not state then
    return ""
  end
  return text()
end

return M
