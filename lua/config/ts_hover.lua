-- Expandable TypeScript hover for the native `tsgo` server.
--
-- tsgo (typescript-go) implements TypeScript 5.9's "expandable hover" over
-- plain LSP: `textDocument/hover` accepts an extra `verbosityLevel` param and
-- the response carries `canIncreaseVerbosity` — provided the client advertised
-- `capabilities.experimental.hoverVerbosityLevel = true` (set in
-- lua/plugins/typescript.lua). Each level inlines one more layer of type
-- aliases, so `+` lets you peek inside a nested type without jumping to its
-- definition.
--
-- Usage: `K` opens the hover as usual. While it is visible, `+` expands one
-- level and `-` collapses one level (from the source buffer or from inside the
-- float). Moving the cursor closes it and restores the normal `+`/`-` motions.
--
-- Rendering goes through noice when its LSP hover override is active (the
-- LazyVim default) so the float matches regular hover; otherwise it falls back
-- to Neovim's built-in floating preview. Any buffer without a tsgo client just
-- gets `vim.lsp.buf.hover()`.

local M = {}

local api = vim.api

local state = {
  active = false,
  level = 0,
  can_expand = false,
  requesting = false,
  gen = 0,
  bufnr = nil, ---@type integer?
  client = nil, ---@type vim.lsp.Client?
  params = nil, ---@type table?
  augroup = nil, ---@type integer?
  float_win = nil, ---@type integer? -- native fallback only
}

local FOCUS_ID = "ts_hover_expand"

---@param bufnr integer
---@return vim.lsp.Client?
local function tsgo_client(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, name = "tsgo", method = "textDocument/hover" })[1]
end

local function noice_hover_enabled()
  local ok, cfg = pcall(require, "noice.config")
  return ok and cfg.is_running and cfg.is_running() and cfg.options.lsp.hover.enabled
end

local function footer()
  if not state.can_expand and state.level == 0 then
    return nil
  end
  local parts = {}
  if state.can_expand then
    parts[#parts + 1] = "+ expand"
  end
  if state.level > 0 then
    parts[#parts + 1] = "- collapse"
  end
  return ("%s · depth %d"):format(table.concat(parts, " · "), state.level)
end

--- Bind +/- in a buffer for the lifetime of the hover.
---@param bufnr integer
local function bind_keys(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.keymap.set("n", "+", function()
    M.expand()
  end, { buffer = bufnr, nowait = true, desc = "Expand type (hover)" })
  vim.keymap.set("n", "-", function()
    M.collapse()
  end, { buffer = bufnr, nowait = true, desc = "Collapse type (hover)" })
end

---@param bufnr integer
local function unbind_keys(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end
  pcall(vim.keymap.del, "n", "+", { buffer = bufnr })
  pcall(vim.keymap.del, "n", "-", { buffer = bufnr })
end

local function teardown()
  if not state.active then
    return
  end
  state.active = false
  state.can_expand = false
  if state.augroup then
    pcall(api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
  if state.bufnr then
    unbind_keys(state.bufnr)
  end
  state.float_win = nil
end

--- Tear down once the user leaves the hover: cursor moves in the source buffer,
--- insert mode, or the source buffer is left for anything other than the float.
local function watch_source()
  state.augroup = api.nvim_create_augroup("ts_hover_expand", { clear = true })
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "BufHidden" }, {
    group = state.augroup,
    buffer = state.bufnr,
    callback = function()
      -- Defer so noice/native close handlers run first and `+` inside the
      -- float (which never moves the source cursor) is unaffected.
      vim.defer_fn(teardown, 20)
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

---@param contents lsp.MarkupContent|lsp.MarkedString|lsp.MarkedString[]
local function render_noice(contents)
  local Docs = require("noice.lsp.docs")
  local Format = require("noice.lsp.format")
  local message = Docs.get("hover") -- clears any previous content
  Format.format(message, contents, { ft = vim.bo[state.bufnr].filetype })
  if message:is_empty() then
    vim.notify("No information available", vim.log.levels.INFO)
    return false
  end
  local foot = footer()
  if foot then
    local NoiceText = require("noice.text")
    message:newline()
    message:append(NoiceText(foot, "Comment"))
  end
  Docs.show(message)
  -- The float buffer is created on noice's next render tick; bind lazily so
  -- +/- also work after entering the float with a second `K`.
  -- (Go via wins(): noice's Message:bufs() has a self/colon bug.)
  vim.defer_fn(function()
    if not state.active then
      return
    end
    for _, w in ipairs(message:wins()) do
      bind_keys(api.nvim_win_get_buf(w))
    end
  end, 60)
  return true
end

---@param contents lsp.MarkupContent|lsp.MarkedString|lsp.MarkedString[]
local function render_native(contents)
  local lines = vim.lsp.util.convert_input_to_markdown_lines(contents)
  local foot = footer()
  if foot then
    vim.list_extend(lines, { "", foot })
  end
  if #lines == 0 then
    vim.notify("No information available", vim.log.levels.INFO)
    return false
  end

  -- Re-open rather than update in place so the float is re-sized for the new
  -- content. Keep focus where it was (source or float).
  local src_win = vim.fn.bufwinid(state.bufnr)
  local was_in_float = state.float_win ~= nil and api.nvim_get_current_win() == state.float_win
  if was_in_float and src_win ~= -1 then
    api.nvim_set_current_win(src_win)
  end
  if state.float_win and api.nvim_win_is_valid(state.float_win) then
    api.nvim_win_close(state.float_win, true)
  end
  local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, "markdown", {
    focus_id = FOCUS_ID,
    focus = false,
    close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre", "BufHidden" },
  })
  state.float_win = fwin
  bind_keys(fbuf)
  if was_in_float then
    api.nvim_set_current_win(fwin)
  end
  return true
end

---@param result lsp.Hover
local function render(result)
  state.can_expand = result.canIncreaseVerbosity == true
  local shown
  if noice_hover_enabled() then
    shown = render_noice(result.contents)
  else
    shown = render_native(result.contents)
  end
  if shown and not state.active then
    state.active = true
    bind_keys(state.bufnr)
    watch_source()
  end
end

-- ---------------------------------------------------------------------------
-- Requests
-- ---------------------------------------------------------------------------

---@param level integer
local function request(level)
  if state.requesting or not state.client or not state.params then
    return
  end
  state.requesting = true
  state.gen = state.gen + 1
  local gen = state.gen

  local params = vim.deepcopy(state.params)
  params.verbosityLevel = level

  local ok = state.client:request("textDocument/hover", params, function(err, result)
    state.requesting = false
    if gen ~= state.gen then
      return -- superseded
    end
    if err then
      vim.notify("tsgo hover: " .. (err.message or tostring(err)), vim.log.levels.WARN)
      return
    end
    if not result or not result.contents then
      if level == 0 then
        vim.notify("No information available", vim.log.levels.INFO)
      end
      return
    end
    state.level = level
    vim.schedule(function()
      render(result)
    end)
  end, state.bufnr)

  if not ok then
    state.requesting = false
  end
end

--- Open the hover at the cursor (verbosity 0). Falls back to the regular LSP
--- hover when no tsgo client is attached.
function M.hover()
  local bufnr = api.nvim_get_current_buf()
  local client = tsgo_client(bufnr)
  if not client then
    -- vtsls path: ts-expand-hover.nvim speaks vtsls's tsserverRequest command
    -- (and itself falls back to vim.lsp.buf.hover when vtsls isn't attached).
    local ok, ts_expand_hover = pcall(require, "ts_expand_hover")
    if ok and vim.g.lazyvim_ts_lsp == "vtsls" then
      return ts_expand_hover.hover()
    end
    return vim.lsp.buf.hover()
  end

  -- A second `K` while visible focuses the float, matching stock behaviour.
  if state.active and state.bufnr == bufnr then
    if noice_hover_enabled() then
      local message = require("noice.lsp.docs")._messages.hover
      if message and message:focus() then
        return
      end
    elseif state.float_win and api.nvim_win_is_valid(state.float_win) then
      api.nvim_set_current_win(state.float_win)
      return
    end
  end

  teardown()
  state.bufnr = bufnr
  state.client = client
  state.params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  state.level = 0
  state.can_expand = false
  request(0)
end

--- Re-request at `level`. When invoked from inside the noice float (after a
--- second `K`), first hop back to the source window: leaving the float fires
--- noice's autohide and our teardown, so wait for those to settle and then
--- re-open at the new level. (Re-rendering a focused nui popup in place breaks
--- noice.) Press `K` again to re-enter the updated float.
---@param level integer
local function rerequest(level)
  local src_win = vim.fn.bufwinid(state.bufnr)
  if vim.bo.filetype == "noice" and src_win ~= -1 and api.nvim_get_current_win() ~= src_win then
    api.nvim_set_current_win(src_win)
    vim.defer_fn(function()
      request(level)
    end, 60)
    return
  end
  request(level)
end

--- Expand the hovered type by one level. No-op when nothing more to expand.
function M.expand()
  if not state.active then
    return vim.cmd.normal({ "+", bang = true })
  end
  if not state.can_expand then
    return
  end
  rerequest(state.level + 1)
end

--- Collapse the hovered type by one level. No-op at depth 0.
function M.collapse()
  if not state.active then
    return vim.cmd.normal({ "-", bang = true })
  end
  if state.level == 0 then
    return
  end
  rerequest(state.level - 1)
end

return M
