-- AI-generated doc comments for the function under the cursor.
--
-- `:DocGen [lite|normal|full]` (or `<leader>cg` for a level picker) finds the
-- enclosing function via Tree-sitter, sends it plus file context to an
-- OpenAI-compatible chat endpoint, and inserts the returned comment block above
-- the declaration, replacing an existing doc comment if there is one. One
-- undo step restores the previous state.
--
-- Languages are described by entries in `M.languages`; only Odin is wired so
-- far. Adding a language means: which Tree-sitter node types are function
-- declarations, which node types count as doc comments, and per-level prompt
-- text describing that language's documentation conventions.
--
-- Backend is a plain `curl` to `provider.url`. Swapping Celeris for LM Studio
-- or Ollama is a change to `M.provider` only.

local M = {}

M.provider = {
  url = "https://inference.celeris.ai/celeris-1/v1/chat/completions",
  model = "celeris-1",
  -- Either `api_key_file` (read at call time) or `api_key_env`. Local servers
  -- can leave both nil.
  api_key_file = "~/.config/celeris/api-key",
  api_key_env = nil,
  timeout_s = 60,
  max_tokens = 1024,
}

-- Whole file goes in the prompt when it is at most this many lines; otherwise
-- `window` lines on either side of the function.
M.max_file_lines = 400
M.window = 60

M.levels = { "lite", "normal", "full" }

local ODIN_STYLE = [[
Odin doc comments are a `/* ... */ block placed directly above the procedure, above any
`@(...)` attribute lines. `/*` and `*/` sit alone on their own lines. Body lines are not
indented and there are no leading `*` markers. Sentences are short and written in third
person ("Clones a string...", "Returns true if..."). Use backticks for identifiers.

Sections, when present, appear in this order and are separated by a blank line:
1. A summary of one or two sentences.
2. Optional emphasized notes such as `*Allocates Using Provided Allocator*`.
3. `Inputs:` followed by `- name: description` bullets, one per parameter, in order.
   Parameters with defaults note it, e.g. `- allocator: (default: context.allocator)`.
4. `Returns:` followed by `- name: description` bullets. Use the result names when the
   results are named; otherwise describe each result in order without a name prefix.
5. `Example:` followed by a blank line and a tab-indented, self-contained example
   procedure. Import only real packages (e.g. `core:fmt`); code from the file being
   documented is in the same package, so call it unqualified without importing it.
6. `Output:` followed by a blank line and the tab-indented output of that example.
]]

M.languages = {
  odin = {
    decl_types = { procedure_declaration = true },
    doc_types = { block_comment = true, comment = true },
    style = ODIN_STYLE,
    -- Wrap a bare reply that forgot the comment delimiters.
    wrap = function(lines)
      local first = lines[1] or ""
      if first:match("^%s*/%*") or first:match("^%s*//") then
        return lines
      end
      local out = { "/*" }
      vim.list_extend(out, lines)
      out[#out + 1] = "*/"
      return out
    end,
    levels = {
      lite = [[
Write only the summary section: a single sentence describing what the procedure does.
No Inputs, Returns, Example, or Output sections.

Example of the expected shape:

/*
Turns a byte slice into a type.
*/
]],
      normal = [[
Write the summary, any warranted emphasized notes, and the Inputs and Returns sections.
No Example or Output sections. Omit `Inputs:` if there are no parameters and `Returns:`
if there are no results.

Example of the expected shape:

/*
Clones a string and appends a null-byte to make it a cstring

*Allocates Using Provided Allocator*

Inputs:
- s: The string to be cloned
- allocator: (default: context.allocator)
- loc: The caller location for debugging purposes (default: #caller_location)

Returns:
- res: A cloned cstring with an appended null-byte
- err: An optional allocator error if one occured, `nil` otherwise
*/
]],
      full = [[
Treat this as a public library API that must be thoroughly documented. Write every
section: summary, emphasized notes on allocation, ownership, panics, or thread safety
where relevant, Inputs, Returns, Example, and Output. Mention edge cases (empty input,
nil, zero length) in the summary or the relevant bullet. The example must be a complete
procedure that compiles against the shown code, and Output must be exactly what that
example prints. If the procedure prints nothing observable, still show a minimal example
and omit the Output section.

Example of the expected shape:

/*
Returns true when the string `substr` is contained inside the string `s`

Inputs:
- s: The input string
- substr: The substring to search for

Returns:
- res: `true` if `substr` is contained inside the string `s`, `false` otherwise

Example:

	import "core:fmt"
	import "core:strings"

	contains_example :: proc() {
		fmt.println(strings.contains("testing", "test"))
		fmt.println(strings.contains("testing", "ing"))
		fmt.println(strings.contains("testing", "text"))
	}

Output:

	true
	true
	false

*/
]],
    },
  },
}

---@class DocGenTarget
---@field decl_start integer 0-indexed first row of the declaration (incl. attributes)
---@field decl_end integer 0-indexed last row of the declaration (inclusive)
---@field doc_start integer|nil 0-indexed first row of an existing doc comment
---@field indent string leading whitespace of the declaration line

--- Walks up from `node` to the nearest declaration node for `lang`.
local function enclosing_decl(node, lang)
  while node do
    if lang.decl_types[node:type()] then
      return node
    end
    node = node:parent()
  end
end

--- Finds a doc comment immediately above `decl`: a block comment, or a run of
--- contiguous line comments, ending on the line directly above the declaration.
local function existing_doc_start(decl, lang)
  local want_row = decl:start() - 1
  local start_row
  local sib = decl:prev_sibling()
  while sib and lang.doc_types[sib:type()] do
    local s, e = sib:start(), sib:end_()
    if e ~= want_row then
      break
    end
    start_row = s
    if sib:type() == "block_comment" then
      break
    end
    want_row = s - 1
    sib = sib:prev_sibling()
  end
  return start_row
end

---@return DocGenTarget|nil, string|nil error
local function find_target(bufnr, lang, range)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil, "no Tree-sitter parser for this buffer"
  end
  parser:parse()

  local target
  if range then
    -- Visual mode: anchor on the first non-blank of the first selected line,
    -- fall back to the raw selection if it isn't inside a declaration.
    local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, false)[1] or ""
    local col = line:find("%S") or 1
    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { range[1], col - 1 } })
    local decl = node and enclosing_decl(node, lang)
    if decl then
      target = { decl_start = decl:start(), decl_end = decl:end_(), doc_start = existing_doc_start(decl, lang) }
    else
      target = { decl_start = range[1], decl_end = range[2] }
    end
  else
    local node = vim.treesitter.get_node({ bufnr = bufnr })
    local decl = node and enclosing_decl(node, lang)
    if not decl then
      return nil, "no function declaration under the cursor"
    end
    target = { decl_start = decl:start(), decl_end = decl:end_(), doc_start = existing_doc_start(decl, lang) }
  end

  local decl_line = vim.api.nvim_buf_get_lines(bufnr, target.decl_start, target.decl_start + 1, false)[1] or ""
  target.indent = decl_line:match("^%s*") or ""
  return target
end

local function read_api_key()
  local p = M.provider
  if p.api_key_env and vim.env[p.api_key_env] then
    return vim.env[p.api_key_env]
  end
  if p.api_key_file then
    local path = vim.fn.expand(p.api_key_file)
    local f = io.open(path, "r")
    if f then
      local key = vim.trim(f:read("*a") or "")
      f:close()
      if key ~= "" then
        return key
      end
    end
    return nil, "could not read API key from " .. path
  end
  return nil
end

local function build_messages(bufnr, lang, level, target)
  local ft = vim.bo[bufnr].filetype
  local total = vim.api.nvim_buf_line_count(bufnr)
  local ctx_start, ctx_end = 0, total
  if total > M.max_file_lines then
    ctx_start = math.max(0, target.decl_start - M.window)
    ctx_end = math.min(total, target.decl_end + 1 + M.window)
  end
  local context = table.concat(vim.api.nvim_buf_get_lines(bufnr, ctx_start, ctx_end, false), "\n")
  local fn = table.concat(vim.api.nvim_buf_get_lines(bufnr, target.decl_start, target.decl_end + 1, false), "\n")

  local old_doc
  if target.doc_start then
    old_doc = table.concat(vim.api.nvim_buf_get_lines(bufnr, target.doc_start, target.decl_start, false), "\n")
  end

  local system = table.concat({
    "You write documentation comments for " .. ft .. " source code.",
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

--- Strips reasoning tags, markdown fences, and surrounding blank lines.
local function clean_reply(text)
  text = text:gsub("<think>.-</think>", "")
  text = text:gsub("^%s*```%w*\n", ""):gsub("\n```%s*$", "")
  text = vim.trim(text)
  return vim.split(text, "\n", { plain = true })
end

local function request(messages, cb)
  local key, err = read_api_key()
  if err then
    return cb(nil, err)
  end
  local body = vim.json.encode({
    model = M.provider.model,
    messages = messages,
    temperature = 0,
    max_tokens = M.provider.max_tokens,
  })
  local cmd = {
    "curl",
    "-sS",
    "--fail-with-body",
    "-m",
    tostring(M.provider.timeout_s),
    "-X",
    "POST",
    M.provider.url,
    "-H",
    "Content-Type: application/json",
    "-d",
    "@-",
  }
  if key then
    table.insert(cmd, 9, "-H")
    table.insert(cmd, 10, "Authorization: Bearer " .. key)
  end
  vim.system(cmd, { stdin = body, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(nil, "request failed: " .. vim.trim((res.stderr ~= "" and res.stderr) or res.stdout or ""))
      end
      local ok, data = pcall(vim.json.decode, res.stdout)
      if not ok then
        return cb(nil, "bad JSON from provider: " .. res.stdout:sub(1, 200))
      end
      if data.error then
        return cb(nil, "provider error: " .. (data.error.message or vim.inspect(data.error)))
      end
      local content = vim.tbl_get(data, "choices", 1, "message", "content")
      if type(content) ~= "string" or content == "" then
        return cb(nil, "empty reply from provider")
      end
      cb(content)
    end)
  end)
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { id = "docgen", title = "DocGen" })
end

--- Generates a doc comment for the declaration under the cursor (or the given
--- 0-indexed inclusive line range) at `level` and inserts it.
---@param level string|nil one of M.levels (default "normal")
---@param range {[1]: integer, [2]: integer}|nil
function M.generate(level, range)
  level = level or "normal"
  if not vim.tbl_contains(M.levels, level) then
    return notify("unknown level '" .. level .. "'; use " .. table.concat(M.levels, "/"), vim.log.levels.ERROR)
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local lang = M.languages[vim.bo[bufnr].filetype]
  if not lang then
    return notify("no docgen support for filetype '" .. vim.bo[bufnr].filetype .. "'", vim.log.levels.WARN)
  end
  local target, err = find_target(bufnr, lang, range)
  if not target then
    return notify(err, vim.log.levels.WARN)
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  notify("generating " .. level .. " docs…")

  request(build_messages(bufnr, lang, level, target), function(reply, rerr)
    if not reply then
      return notify(rerr, vim.log.levels.ERROR)
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_changedtick(bufnr) ~= tick then
      return notify("buffer changed while generating; not inserting", vim.log.levels.WARN)
    end
    local lines = clean_reply(reply)
    if lang.wrap then
      lines = lang.wrap(lines)
    end
    for i, l in ipairs(lines) do
      lines[i] = l == "" and "" or (target.indent .. l)
    end
    local replace_from = target.doc_start or target.decl_start
    vim.api.nvim_buf_set_lines(bufnr, replace_from, target.decl_start, false, lines)
    notify((target.doc_start and "replaced" or "inserted") .. " " .. level .. " docs")
  end)
end

--- Prompts for a level with vim.ui.select, then generates.
function M.pick(range)
  vim.ui.select(M.levels, {
    prompt = "DocGen level",
    format_item = function(item)
      local desc = { lite = "one-line summary", normal = "summary + inputs/returns", full = "library API with example" }
      return item .. "  —  " .. desc[item]
    end,
  }, function(choice)
    if choice then
      M.generate(choice, range)
    end
  end)
end

--- Registers the :DocGen command and <leader>cg keymaps.
function M.setup()
  vim.api.nvim_create_user_command("DocGen", function(cmd)
    local range = cmd.range > 0 and { cmd.line1 - 1, cmd.line2 - 1 } or nil
    local level = cmd.fargs[1]
    if level then
      M.generate(level, range)
    else
      M.pick(range)
    end
  end, {
    nargs = "?",
    range = true,
    complete = function()
      return M.levels
    end,
    desc = "Generate a doc comment for the function under the cursor",
  })

  vim.keymap.set("n", "<leader>cg", function()
    M.pick()
  end, { desc = "Generate docs (AI)" })
  vim.keymap.set("x", "<leader>cg", function()
    local s, e = vim.fn.line("v"), vim.fn.line(".")
    if s > e then
      s, e = e, s
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    M.pick({ s - 1, e - 1 })
  end, { desc = "Generate docs (AI)" })
end

return M
