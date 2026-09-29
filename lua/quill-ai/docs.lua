-- Doc-comment generation for the function under the cursor.
--
-- Finds the enclosing declaration via Tree-sitter (see langs/init.lua for the
-- per-language spec), sends it plus file context to the docs tier, and
-- inserts the returned comment above the declaration (or inside it, for
-- Python docstrings), replacing an existing doc comment if there is one. One
-- undo step restores the previous state.

local client = require("quill-ai.client")
local config = require("quill-ai.config")
local langs = require("quill-ai.langs")
local util = require("quill-ai.util")

local M = {}

-------------------------------------------------------------------------------
-- Target detection
-------------------------------------------------------------------------------

---@class DocGenTarget
---@field decl_start integer 0-indexed first row of the declaration
---@field decl_end integer 0-indexed last row of the declaration (inclusive)
---@field insert_at integer 0-indexed row where the new comment starts
---@field replace_to integer 0-indexed exclusive end row of the existing doc (== insert_at if none)
---@field indent string leading whitespace to apply to each inserted line

local function accept(node, lang)
  if lang.decl_types[node:type()] then
    return lang.resolve and lang.resolve(node) or node
  end
end

--- Breadth-first search below `node` for an accepted declaration starting on
--- `row`. Covers a cursor on a wrapper keyword (`export`, `const`, `@dec`)
--- where the node at the cursor is the wrapper, not the function.
local function decl_starting_on_row(node, row, lang)
  local queue = { node }
  while #queue > 0 do
    local n = table.remove(queue, 1)
    for child in n:iter_children() do
      if child:named() and child:start() <= row and child:end_() >= row then
        if child:start() == row then
          local decl = accept(child, lang)
          if decl then
            return decl
          end
        end
        queue[#queue + 1] = child
      end
    end
  end
end

--- Finds the declaration for the cursor at `node`: the nearest accepted
--- ancestor, else a declaration starting on the cursor row beneath the
--- outermost non-declaration node on that row.
local function enclosing_decl(node, row, lang)
  local n = node
  while n do
    local decl = accept(n, lang)
    if decl then
      return decl
    end
    n = n:parent()
  end
  -- Walk up while the ancestor still starts on the cursor row, then search down.
  local top = node
  while top:parent() and top:parent():start() == row do
    top = top:parent()
  end
  return decl_starting_on_row(top:parent() or top, row, lang)
end

--- Placement "above": a contiguous run of comment nodes ending on the line
--- directly above the declaration is the existing doc.
local function target_above(bufnr, decl, lang)
  local decl_start = decl:start()
  local want_row = decl_start - 1
  local doc_start
  local sib = decl:prev_sibling()
  while sib and lang.doc_types[sib:type()] and sib:end_() == want_row do
    doc_start = sib:start()
    want_row = doc_start - 1
    sib = sib:prev_sibling()
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, decl_start, decl_start + 1, false)[1] or ""
  return {
    decl_start = decl_start,
    decl_end = decl:end_(),
    insert_at = doc_start or decl_start,
    replace_to = decl_start,
    indent = line:match("^%s*") or "",
  }
end

--- Placement "inside": the docstring is the first statement of the body.
local function target_inside(bufnr, decl)
  local body = decl:field("body")[1]
  if not body then
    return nil, "function has no body"
  end
  local body_row = body:start()
  if body_row == decl:start() then
    return nil, "single-line function body; expand it first"
  end
  local first = body:named_child(0)
  local doc_node
  if first and first:type() == "expression_statement" then
    local inner = first:named_child(0)
    if inner and inner:type() == "string" then
      doc_node = first
    end
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, body_row, body_row + 1, false)[1] or ""
  return {
    decl_start = decl:start(),
    decl_end = decl:end_(),
    insert_at = doc_node and doc_node:start() or body_row,
    replace_to = doc_node and (doc_node:end_() + 1) or body_row,
    indent = line:match("^%s*") or "",
  }
end

local function target_for(bufnr, decl, lang)
  if lang.placement == "inside" then
    return target_inside(bufnr, decl)
  end
  return target_above(bufnr, decl, lang)
end

---@return DocGenTarget|nil, string|nil error
local function find_target(bufnr, lang, range)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil, "no Tree-sitter parser for this buffer"
  end
  parser:parse()

  if range then
    -- Visual mode: anchor on the first non-blank of the first selected line,
    -- fall back to the raw selection if it isn't inside a declaration.
    local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1] or ""
    local col = line:find("%S") or 1
    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { range[1], col - 1 } })
    local decl = node and enclosing_decl(node, range[1], lang)
    if decl then
      return target_for(bufnr, decl, lang)
    end
    if lang.placement == "inside" then
      return nil, "selection is not a function"
    end
    return {
      decl_start = range[1],
      decl_end = range[2],
      insert_at = range[1],
      replace_to = range[1],
      indent = line:match("^%s*") or "",
    }
  end

  local node = vim.treesitter.get_node({ bufnr = bufnr })
  local decl = node and enclosing_decl(node, vim.api.nvim_win_get_cursor(0)[1] - 1, lang)
  if not decl then
    return nil, "no function declaration under the cursor"
  end
  return target_for(bufnr, decl, lang)
end

-------------------------------------------------------------------------------
-- Prompt
-------------------------------------------------------------------------------

local function build_messages(bufnr, lang, level, target)
  local opts = config.options.docs
  local total = vim.api.nvim_buf_line_count(bufnr)
  local ctx_start, ctx_end = 0, total
  if total > opts.max_file_lines then
    ctx_start = math.max(0, target.decl_start - opts.window)
    ctx_end = math.min(total, target.decl_end + 1 + opts.window)
  end
  local context = table.concat(vim.api.nvim_buf_get_lines(bufnr, ctx_start, ctx_end, false), "\n")
  local fn = table.concat(vim.api.nvim_buf_get_lines(bufnr, target.decl_start, target.decl_end + 1, false), "\n")

  local old_doc
  if target.replace_to > target.insert_at then
    old_doc = table.concat(vim.api.nvim_buf_get_lines(bufnr, target.insert_at, target.replace_to, false), "\n")
  end

  local system = table.concat({
    "You write documentation comments for " .. lang.name .. " source code.",
    "Reply with the comment block only: no code, no markdown fences, no explanation.",
    "Never restate the signature; describe behavior, arguments, results, and caveats.",
    "",
    lang.style,
    "",
    "Detail level: " .. level,
    lang.levels[level],
  }, "\n")

  local user = {
    "File context (" .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t") .. "):",
    "```",
    context,
    "```",
    "",
    "Document this declaration:",
    "```",
    fn,
    "```",
  }
  if old_doc then
    vim.list_extend(user, {
      "",
      "It currently has this doc comment. Rewrite it at the requested detail level, keeping",
      "any facts that are still accurate:",
      "```",
      old_doc,
      "```",
    })
  end

  return {
    { role = "system", content = system },
    { role = "user", content = table.concat(user, "\n") },
  }
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Generates a doc comment for the declaration under the cursor (or the given
--- 0-indexed inclusive line range) at `level` and inserts it.
---@param level string|nil one of config.options.docs.levels (default "normal")
---@param range {[1]: integer, [2]: integer}|nil
function M.generate(level, range)
  local opts = config.options.docs
  level = level or "normal"
  if not vim.tbl_contains(opts.levels, level) then
    return util.notify("unknown level '" .. level .. "'; use " .. table.concat(opts.levels, "/"), vim.log.levels.ERROR)
  end
  local tier, terr = config.tier(opts.tier)
  if not tier then
    return util.notify(terr, vim.log.levels.ERROR)
  end
  local quill = require("quill-ai")
  if quill.busy() then
    return util.notify("a request is already in flight; :QuillCancel first", vim.log.levels.WARN)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local lang = langs.get(ft)
  if not lang then
    return util.notify("no docs support for filetype '" .. ft .. "'", vim.log.levels.WARN)
  end
  local target, err = find_target(bufnr, lang, range)
  if not target then
    return util.notify(err, vim.log.levels.WARN)
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)

  local handle = client.request(tier, build_messages(bufnr, lang, level, target), function(reply, rerr)
    quill.track(nil)
    if not reply then
      if rerr == "cancelled" then
        return util.notify("cancelled", vim.log.levels.WARN)
      end
      return util.notify(rerr, vim.log.levels.ERROR)
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
      return util.notify("buffer changed while generating; not inserting", vim.log.levels.WARN)
    end
    local lines = util.clean_reply(reply.content)
    if lang.wrap then
      lines = lang.wrap(lines)
    end
    for i, l in ipairs(lines) do
      lines[i] = l == "" and "" or (target.indent .. l)
    end
    local replaced = target.replace_to > target.insert_at
    util.undo_break(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, target.insert_at, target.replace_to, false, lines)
    util.notify((replaced and "replaced" or "inserted") .. " " .. level .. " docs")
  end)
  quill.track(handle, { label = level .. " docs", bufnr = bufnr, region = { target.insert_at, target.decl_end } })
end

--- Prompts for a level with vim.ui.select, then generates.
function M.pick(range)
  local desc = { lite = "one-line summary", normal = "summary + inputs/returns", full = "library API with example" }
  vim.ui.select(config.options.docs.levels, {
    prompt = "Quill docs level",
    format_item = function(item)
      return desc[item] and (item .. "  —  " .. desc[item]) or item
    end,
  }, function(choice)
    if choice then
      M.generate(choice, range)
    end
  end)
end

return M
