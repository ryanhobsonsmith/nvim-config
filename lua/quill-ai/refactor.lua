-- Free-form edits: a selection (or the whole file) is the editable region,
-- the whole file is context, the model returns the region's replacement.

local client = require("quill-ai.client")
local config = require("quill-ai.config")
local util = require("quill-ai.util")

local M = {}

local MARKERS = {
  { "<<<REGION>>>", "<<<END REGION>>>" },
  { "<<<QUILL REGION>>>", "<<<END QUILL REGION>>>" },
}

--- Picks marker strings that do not already occur in the file.
local function pick_markers(file_lines)
  for _, pair in ipairs(MARKERS) do
    local clash = false
    for _, l in ipairs(file_lines) do
      if l:find(pair[1], 1, true) or l:find(pair[2], 1, true) then
        clash = true
        break
      end
    end
    if not clash then
      return pair
    end
  end
  return { "<<<QUILL " .. os.time() .. ">>>", "<<<END QUILL " .. os.time() .. ">>>" }
end

---@class QuillRefactorCtx
---@field bufnr integer
---@field region {[1]: integer, [2]: integer} 0-indexed inclusive
---@field file_lines string[]
---@field markers {[1]: string, [2]: string}
---@field whole_file boolean

---@param ctx QuillRefactorCtx
---@param instruction string
function M.build_messages(ctx, instruction)
  local s, e = ctx.region[1], ctx.region[2]
  local m = ctx.markers
  local shown = {}
  for i, l in ipairs(ctx.file_lines) do
    if i - 1 == s then
      shown[#shown + 1] = m[1]
    end
    shown[#shown + 1] = l
    if i - 1 == e then
      shown[#shown + 1] = m[2]
    end
  end

  local ft = vim.bo[ctx.bufnr].filetype
  local system = table.concat({
    "You edit source code. You receive a whole file in which one region is marked between",
    "the lines `" .. m[1] .. "` and `" .. m[2] .. "`, followed by an instruction.",
    "Rewrite ONLY the region according to the instruction.",
    "Reply with the new contents of the region and nothing else: no marker lines, no code",
    "from outside the region, no markdown fences, no explanation, no leading comment about",
    "what you changed. Preserve the file's indentation style and the indentation of the",
    "region's first line. Everything outside the region is kept by the editor verbatim and",
    "must not be repeated. If the instruction asks to add code, include it in the region's",
    "new contents along with whatever of the original region should remain. Do not think",
    "out loud, narrate, or correct yourself in the reply; output the final code once.",
    ctx.whole_file and "The region is the entire file; reply with the complete new file." or "",
  }, "\n")

  local user = table.concat({
    "File: "
      .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ctx.bufnr), ":t")
      .. (ft ~= "" and (" (" .. ft .. ")") or ""),
    "```",
    table.concat(shown, "\n"),
    "```",
    "",
    "Instruction: " .. instruction,
  }, "\n")

  return {
    { role = "system", content = system },
    { role = "user", content = user },
  }
end

local function looks_like_prose(line)
  local l = vim.trim(line)
  if l == "" then
    return false
  end
  return (l:match("^[Hh]ere") or l:match("^Sure") or l:match("^Below")) and l:match("[:.]$") ~= nil
end

--- Turns a raw reply into region lines. `suspicious` is set when the reply
--- looks like a whole-file rewrite for a partial region and could not be
--- reduced to the region reliably.
---@param reply string
---@param ctx QuillRefactorCtx
---@return string[] lines, boolean suspicious
function M.sanitize(reply, ctx)
  local lines = util.clean_reply(reply)
  local m = ctx.markers

  -- Self-corrections: code, then "Wait, let me fix that", then a fenced
  -- final version (sometimes more than once). The last complete fenced block
  -- is the model's final answer.
  local last_open, last_close
  local open
  for i, l in ipairs(lines) do
    if l:match("^%s*```") then
      if open then
        last_open, last_close, open = open, i, nil
      else
        open = i
      end
    end
  end
  if last_open then
    local inner = {}
    for i = last_open + 1, last_close - 1 do
      inner[#inner + 1] = lines[i]
    end
    lines = inner
  end

  -- Markers echoed: keep what is between them.
  local ms, me
  for i, l in ipairs(lines) do
    if not ms and l:find(m[1], 1, true) then
      ms = i
    elseif ms and l:find(m[2], 1, true) then
      me = i
      break
    end
  end
  if ms then
    local inner = {}
    for i = ms + 1, (me or #lines + 1) - 1 do
      inner[#inner + 1] = lines[i]
    end
    lines = inner
  end

  -- Leading chatter, then a fence the model opened after it.
  if looks_like_prose(lines[1] or "") then
    table.remove(lines, 1)
    while lines[1] and vim.trim(lines[1]) == "" do
      table.remove(lines, 1)
    end
    if lines[1] and lines[1]:match("^```") then
      table.remove(lines, 1)
      if lines[#lines] and lines[#lines]:match("^```") then
        table.remove(lines)
      end
    end
  end

  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end

  local suspicious = false
  if not ctx.whole_file and not ms then
    -- Whole file returned without markers? A reply that reproduces the
    -- untouched prefix (or, for a region at the top, the untouched suffix)
    -- gets that part stripped. A reply that starts like the file but whose
    -- prefix differs is a rewrite we cannot place safely. A reply that starts
    -- differently is just a (possibly larger) region: adding code makes
    -- replies longer than the file all the time.
    local total = #ctx.file_lines
    local s, e = ctx.region[1], ctx.region[2]
    local prefix_n, suffix_n = s, total - e - 1
    local function matches(from_reply, from_file, n)
      for i = 0, n - 1 do
        if lines[from_reply + i] ~= ctx.file_lines[from_file + i] then
          return false
        end
      end
      return true
    end
    if prefix_n > 0 and lines[1] == ctx.file_lines[1] then
      if #lines > prefix_n and matches(1, 1, prefix_n) then
        local inner = {}
        for i = prefix_n + 1, #lines do
          inner[#inner + 1] = lines[i]
        end
        lines = inner
        if suffix_n > 0 and #lines > suffix_n and matches(#lines - suffix_n + 1, total - suffix_n + 1, suffix_n) then
          for _ = 1, suffix_n do
            table.remove(lines)
          end
        end
      else
        suspicious = true
      end
    elseif prefix_n == 0 and suffix_n > 0 and #lines > suffix_n then
      if matches(#lines - suffix_n + 1, total - suffix_n + 1, suffix_n) then
        for _ = 1, suffix_n do
          table.remove(lines)
        end
      end
    end
  end

  return lines, suspicious
end

--- Writes `lines` over the region, or opens a preview, per `mode`.
function M.apply(ctx, lines, mode, tick)
  local bufnr = ctx.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return util.notify("buffer is gone; not applying", vim.log.levels.WARN)
  end
  if mode == "diff" then
    return require("quill-ai.diff").open({ bufnr = bufnr, region = ctx.region, lines = lines, tick = tick })
  end
  if vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
    return util.notify("buffer changed while generating; not applying", vim.log.levels.WARN)
  end
  local win = vim.fn.bufwinid(bufnr)
  local cursor = win ~= -1 and vim.api.nvim_win_get_cursor(win) or nil
  util.undo_break(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, ctx.region[1], ctx.region[2] + 1, false, lines)
  if cursor then
    cursor[1] = math.min(cursor[1], vim.api.nvim_buf_line_count(bufnr))
    pcall(vim.api.nvim_win_set_cursor, win, cursor)
  end
  util.notify(("applied %s (%d lines)"):format(ctx.whole_file and "whole file" or "region", #lines))
end

--- Runs an instruction against the current buffer.
---@param tier_name string
---@param instruction string
---@param range {[1]: integer, [2]: integer}|nil 0-indexed inclusive; nil = whole file
function M.run(tier_name, instruction, range)
  instruction = vim.trim(instruction or "")
  if instruction == "" then
    return util.notify("empty instruction", vim.log.levels.WARN)
  end
  local tier, err = config.tier(tier_name)
  if not tier then
    return util.notify(err, vim.log.levels.ERROR)
  end
  local quill = require("quill-ai")
  if quill.busy() then
    return util.notify("a request is already in flight; :QuillCancel first", vim.log.levels.WARN)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local last = math.max(#file_lines - 1, 0)
  local region = range and { math.max(range[1], 0), math.min(range[2], last) } or { 0, last }
  ---@type QuillRefactorCtx
  local ctx = {
    bufnr = bufnr,
    region = region,
    file_lines = file_lines,
    markers = pick_markers(file_lines),
    whole_file = region[1] == 0 and region[2] == last,
  }
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)

  local handle = client.request(tier, M.build_messages(ctx, instruction), function(reply, rerr)
    quill.track(nil)
    if not reply then
      if rerr == "cancelled" then
        return util.notify("cancelled", vim.log.levels.WARN)
      end
      return util.notify(rerr, vim.log.levels.ERROR)
    end
    local lines, suspicious = M.sanitize(reply.content, ctx)
    if #lines == 0 then
      return util.notify("model returned nothing usable", vim.log.levels.WARN)
    end
    local mode = tier.apply or "direct"
    if reply.truncated then
      util.notify("reply hit max_tokens; showing preview instead of applying", vim.log.levels.WARN)
      mode = "diff"
    elseif suspicious then
      -- The model most likely rewrote the whole file; preview it as such
      -- rather than splicing a whole file into a few lines.
      util.notify("reply looks like a whole-file rewrite; showing preview instead", vim.log.levels.WARN)
      ctx.region = { 0, #ctx.file_lines - 1 }
      ctx.whole_file = true
      mode = "diff"
    end
    M.apply(ctx, lines, mode, tick)
  end)
  quill.track(handle, { label = tier_name .. ": " .. instruction:sub(1, 40), bufnr = bufnr, region = region })
end

return M
