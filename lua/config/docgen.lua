-- AI-generated doc comments for the function under the cursor.
--
-- `:DocGen [lite|normal|full]` (or `<leader>cg` for a level picker) finds the
-- enclosing function via Tree-sitter, sends it plus file context to an
-- OpenAI-compatible chat endpoint, and inserts the returned comment block above
-- the declaration (or inside it, for Python docstrings), replacing an existing
-- doc comment if there is one. One undo step restores the previous state.
--
-- Languages are described by entries in `M.languages`, keyed by filetype:
--   decl_types  set of Tree-sitter node types that are function declarations
--   resolve     optional fn(node) -> node|nil; adjusts a matched node (e.g. climb
--               to a wrapping `export_statement`) or returns nil to reject it
--   doc_types   set of comment node types that count as an existing doc comment
--               (placement "above" only)
--   placement   "above" (default) or "inside" (docstring as first body statement)
--   name        human name for the prompt
--   style       prose describing the language's doc-comment conventions
--   levels      per-level instructions, each with an example of the shape
--   wrap        optional fn(lines) -> lines; adds delimiters if the model omitted them
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

-------------------------------------------------------------------------------
-- Wrap helpers (used when the model returns a bare body without delimiters)
-------------------------------------------------------------------------------

local function starts_with_any(line, prefixes)
  for _, p in ipairs(prefixes) do
    if line:find(p, 1, true) == 1 then
      return true
    end
  end
  return false
end

--- `/** ... */` with ` * ` line prefixes (JSDoc, Doxygen).
local function wrap_star_block(lines)
  if starts_with_any(vim.trim(lines[1] or ""), { "/*", "//" }) then
    return lines
  end
  if #lines == 1 then
    return { "/** " .. lines[1] .. " */" }
  end
  local out = { "/**" }
  for _, l in ipairs(lines) do
    out[#out + 1] = l == "" and " *" or (" * " .. l)
  end
  out[#out + 1] = " */"
  return out
end

--- Bare `/* ... */` with unindented body lines (Odin core style).
local function wrap_plain_block(lines)
  if starts_with_any(vim.trim(lines[1] or ""), { "/*", "//" }) then
    return lines
  end
  local out = { "/*" }
  vim.list_extend(out, lines)
  out[#out + 1] = "*/"
  return out
end

--- `// ` on every line (Go).
local function wrap_line_comments(lines)
  if starts_with_any(vim.trim(lines[1] or ""), { "//" }) then
    return lines
  end
  local out = {}
  for _, l in ipairs(lines) do
    out[#out + 1] = l == "" and "//" or ("// " .. l)
  end
  return out
end

--- Triple-quoted docstring (Python). Adds quotes when missing, and cuts
--- anything after the first closing quote (models sometimes tack sections on
--- past the end, or forget to close).
local function wrap_docstring(lines)
  local first = vim.trim(lines[1] or "")
  local q = first:match('^r?(""")') or first:match("^r?(''')")
  if not q then
    if #lines == 1 then
      return { '"""' .. lines[1] .. '"""' }
    end
    local out = { '"""' .. lines[1] }
    for i = 2, #lines do
      out[#out + 1] = lines[i]
    end
    out[#out + 1] = '"""'
    return out
  end
  local out = {}
  for i, l in ipairs(lines) do
    local from = i == 1 and (l:find(q, 1, true) + 3) or 1
    local close = l:find(q, from, true)
    out[i] = l
    if close then
      out[i] = l:sub(1, close + 2)
      return out
    end
  end
  out[#out + 1] = q
  return out
end

-------------------------------------------------------------------------------
-- Resolve helpers
-------------------------------------------------------------------------------

--- If `node`'s parent is one of `types`, return the parent.
local function climb_if_parent(node, types)
  local p = node:parent()
  if p and types[p:type()] then
    return p
  end
  return node
end

--- TS/JS: anonymous functions count only when bound to a name (variable,
--- class field, object key, assignment); callbacks are rejected so the walk
--- continues to the enclosing named function. Exported declarations resolve to
--- the `export_statement` so the comment lands above `export`.
local function ts_resolve(node)
  local t = node:type()
  if t == "arrow_function" or t == "function_expression" then
    local p = node:parent()
    local pt = p and p:type()
    if pt == "variable_declarator" then
      node = p:parent()
    elseif pt == "public_field_definition" or pt == "pair" then
      node = p
    elseif pt == "assignment_expression" then
      node = climb_if_parent(p, { expression_statement = true })
    else
      return nil
    end
  end
  return climb_if_parent(node, { export_statement = true })
end

--- C: a plain `declaration` is a target only when it declares a function.
local function c_resolve(node)
  if node:type() == "declaration" then
    for child in node:iter_children() do
      if child:type() == "function_declarator" then
        return node
      end
    end
    return nil
  end
  return node
end

-------------------------------------------------------------------------------
-- Language specs
-------------------------------------------------------------------------------

local ODIN_STYLE = [[
Odin doc comments are a `/* ... */` block placed directly above the procedure, above any
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

local odin = {
  name = "Odin",
  decl_types = { procedure_declaration = true },
  doc_types = { block_comment = true, comment = true },
  style = ODIN_STYLE,
  wrap = wrap_plain_block,
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
}

local JSDOC_STYLE = [[
Use a JSDoc block: `/**` on its own line, every body line prefixed with ` * `, and ` */`
on its own line. A one-sentence summary comes first, in third person ("Returns...",
"Creates..."). Tag sections follow after a blank ` *` line, in this order: `@param`,
`@returns`, `@throws`, `@example`, `@remarks`/`@see`. Use `@param name - description`
with a hyphen. Omit `@returns` for `void`/`undefined` results and for constructors. Use
`@template` for generic type parameters when they matter. Never restate the signature in
prose. Wrap code identifiers in backticks.
]]

local function jsdoc_lang(name, typed)
  local p = typed and "{number} " or ""
  local r = typed and "{number} " or ""
  local type_rule = typed
      and "Include types in braces (`@param {string} name`, `@returns {boolean}`) since there are no annotations."
    or "Do NOT include types in braces; TypeScript annotations already carry them."
  local tags = " * @param "
    .. p
    .. "value - The number to clamp.\n"
    .. " * @param "
    .. p
    .. "min - Lower bound.\n"
    .. " * @param "
    .. p
    .. "max - Upper bound.\n"
    .. " * @returns "
    .. r
    .. "The clamped value.\n"
  return {
    name = name,
    decl_types = {
      function_declaration = true,
      generator_function_declaration = true,
      method_definition = true,
      method_signature = true,
      abstract_method_signature = true,
      function_signature = true,
      arrow_function = true,
      function_expression = true,
    },
    resolve = ts_resolve,
    doc_types = { comment = true },
    style = JSDOC_STYLE .. type_rule,
    wrap = wrap_star_block,
    levels = {
      lite = [[
Write a single-line JSDoc containing only the summary sentence. No tags.

Example of the expected shape:

/** Clamps a number to the inclusive range [min, max]. */
]],
      normal = "Write the summary plus `@param` and `@returns` tags. No `@example`.\n\n"
        .. "Example of the expected shape:\n\n"
        .. "/**\n * Clamps a number to the inclusive range [min, max].\n *\n"
        .. tags
        .. " */\n",
      full = "Treat this as a public library API that must be thoroughly documented. Write the\n"
        .. "summary, a second sentence or short paragraph on behavior and edge cases, `@param` and\n"
        .. "`@returns` tags, `@throws` for every error the code can raise, and an `@example` block\n"
        .. "with a realistic usage that compiles against the shown code. Add `@remarks` for caveats\n"
        .. "(async behavior, mutation, performance, side effects) when relevant.\n\n"
        .. "Example of the expected shape:\n\n"
        .. "/**\n * Clamps a number to the inclusive range [min, max].\n *\n"
        .. " * If `min` is greater than `max` the bounds are swapped. `NaN` is returned unchanged.\n *\n"
        .. tags
        .. " *\n * @example\n * ```ts\n * clamp(15, 0, 10); // 10\n * clamp(-5, 0, 10); // 0\n * ```\n */\n",
    },
  }
end

local go = {
  name = "Go",
  decl_types = { function_declaration = true, method_declaration = true },
  doc_types = { comment = true },
  style = [[
Go doc comments are consecutive `//` line comments directly above the declaration, with a
single space after `//`. The first sentence begins with the function's name and is a
complete sentence in third person: "Contains reports whether substr is within s." There
are no `@param`-style tags; parameters and results are described in prose, referring to
them by name. Paragraphs are separated by a lone `//` line. Code identifiers are not
quoted. Keep lines under 80 characters.
]],
  wrap = wrap_line_comments,
  levels = {
    lite = [[
Write exactly one sentence beginning with the function's name.

Example of the expected shape:

// Contains reports whether substr is within s.
]],
    normal = [[
Write one short paragraph: the summary sentence, then sentences describing the meaning
of each parameter and each result, including any error conditions and nil/zero-value
behavior.

Example of the expected shape:

// Cut slices s around the first instance of sep, returning the text before
// and after sep. The found result reports whether sep appears in s. If sep
// does not appear in s, Cut returns s, "", false.
]],
    full = [[
Treat this as a public library API. Write the summary paragraph, then further paragraphs
covering parameter semantics, result and error semantics, edge cases, concurrency safety,
ownership of returned values, and performance notes where relevant. Finish with a short
indented code example (a tab after `//`) showing typical usage against the shown code.
Add a "Deprecated:" paragraph only if the code says so.

Example of the expected shape:

// Cut slices s around the first instance of sep, returning the text before
// and after sep. The found result reports whether sep appears in s.
//
// If sep does not appear in s, Cut returns s, "", false. Cut never allocates;
// both results alias the memory of s. An empty sep matches at the start of s.
//
// Cut is safe for concurrent use.
//
//	before, after, found := strings.Cut("key=value", "=")
//	fmt.Println(before, after, found) // key value true
]],
  },
}

local c = {
  name = "C",
  decl_types = { function_definition = true, declaration = true },
  resolve = c_resolve,
  doc_types = { comment = true },
  style = [[
Use a Doxygen block in Javadoc style: `/**` on its own line, every body line prefixed with
` * `, and ` */` on its own line. Start with `@brief` and a one-sentence summary. Then an
optional detail paragraph, then `@param name description` for each parameter in order
(use `@param[out]` / `@param[in,out]` for pointers written through), `@return`
describing the result and any error values, `@retval` for specific sentinel values, and
`@note`/`@warning`/`@pre` for caveats such as ownership, buffer sizes, NULL handling,
thread safety, and who must free memory. Omit `@return` for `void`.
]],
  wrap = wrap_star_block,
  levels = {
    lite = [[
Write a single-line block containing only the summary sentence. No tags.

Example of the expected shape:

/** Adds two integers. */
]],
    normal = [[
Write `@brief`, `@param` for each parameter, and `@return`. No examples.

Example of the expected shape:

/**
 * @brief Copies at most n bytes of src into dst.
 *
 * @param dst Destination buffer of at least n bytes.
 * @param src NUL-terminated source string.
 * @param n   Maximum number of bytes to write, including the terminator.
 * @return Number of bytes written, excluding the terminator.
 */
]],
    full = [[
Treat this as a public library API. Write `@brief`, a detail paragraph on behavior and edge
cases, `@param` for each parameter with `[in]`/`[out]` direction where it matters,
`@return` and `@retval` for sentinel values, `@pre`/`@post` where relevant, `@note` or
`@warning` for ownership, NULL handling, buffer sizes, and thread safety, and a
`@code ... @endcode` example that compiles against the shown code.

Example of the expected shape:

/**
 * @brief Copies at most n bytes of src into dst.
 *
 * Always NUL-terminates dst when n is greater than zero, truncating src if it
 * does not fit. Unlike strncpy, the remainder of dst is not zero-padded.
 *
 * @param[out] dst Destination buffer of at least n bytes. Must not be NULL.
 * @param[in]  src NUL-terminated source string. Must not be NULL.
 * @param      n   Size of dst in bytes, including room for the terminator.
 * @return Number of bytes written, excluding the terminator.
 * @retval 0 if n is zero; dst is left untouched.
 * @pre dst and src do not overlap.
 * @note Not thread-safe with respect to concurrent writes to dst.
 *
 * @code
 * char buf[8];
 * size_t n = copy_str(buf, "hello, world", sizeof buf); // n == 7, buf == "hello, "
 * @endcode
 */
]],
  },
}

local python = {
  name = "Python",
  decl_types = { function_definition = true, decorated_definition = true },
  resolve = function(node)
    if node:type() == "decorated_definition" then
      local def = node:field("definition")[1]
      return def and def:type() == "function_definition" and def or nil
    end
    return node
  end,
  placement = "inside",
  style = [[
Write a PEP 257 docstring in Google style. Triple double quotes. A one-line docstring
fits on a single line with the quotes: `"""Return the sum of a and b."""`. A multi-line
docstring puts the summary on the opening-quote line, then a blank line, then the body,
with the closing quotes on their own line. The summary is an imperative sentence ending
with a period ("Return...", "Compute..."). Sections are `Args:`, `Returns:` (or
`Yields:`), `Raises:`, and `Examples:`, each with entries indented by four spaces as
`name (type): description` under Args (omit `(type)` when annotations exist) and
`type: description` under Returns. Do not document `self` or `cls`. The docstring is
indented to match the function body; emit it without leading indentation and it will be
indented for you.
]],
  wrap = wrap_docstring,
  levels = {
    lite = [[
Write a one-line docstring: the summary sentence only, on a single line with the quotes.
Nothing after the closing quotes.

Example of the expected shape:

"""Return the Euclidean distance between two points."""
]],
    normal = [[
Write the summary, then `Args:` and `Returns:` (and `Raises:` if the code raises). No
`Examples:`.

Example of the expected shape:

"""Fetch rows from a Bigtable.

Args:
    table_handle: An open Bigtable instance.
    keys: A sequence of strings representing the key of each row to fetch.
    require_all_keys: If True, only rows with values set for all keys are returned.

Returns:
    A dict mapping keys to the corresponding row data fetched. Rows that were
    missing are omitted.

Raises:
    IOError: An error occurred accessing the Bigtable.
"""
]],
    full = [[
Treat this as a public library API. Write the summary, a paragraph on behavior and edge
cases, `Args:` with defaults noted, `Returns:` or `Yields:`, `Raises:` for every exception
the code can raise, notes on side effects or thread safety, and an `Examples:` section
with doctest-style `>>>` lines whose output is exactly what the shown code would print.

Example of the expected shape:

"""Fetch rows from a Bigtable.

Retrieves rows pertaining to the given keys from the Table instance
represented by table_handle. Missing keys are silently skipped unless
require_all_keys is True.

Args:
    table_handle: An open Bigtable instance.
    keys: A sequence of strings representing the key of each row to fetch.
    require_all_keys: If True, only rows with values set for all keys are
        returned. Defaults to False.

Returns:
    A dict mapping keys to the corresponding row data fetched. Each row is
    represented as a tuple of strings.

Raises:
    IOError: An error occurred accessing the Bigtable.
    KeyError: require_all_keys is True and a key is missing.

Examples:
    >>> rows = fetch_rows(handle, ["Serak", "Zim"])
    >>> sorted(rows)
    ['Serak', 'Zim']
"""
]],
  },
}

M.languages = {
  odin = odin,
  typescript = jsdoc_lang("TypeScript", false),
  javascript = jsdoc_lang("JavaScript", true),
  go = go,
  c = c,
  python = python,
}
M.languages.typescriptreact = M.languages.typescript
M.languages.javascriptreact = M.languages.javascript

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
-- Request
-------------------------------------------------------------------------------

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
  local total = vim.api.nvim_buf_line_count(bufnr)
  local ctx_start, ctx_end = 0, total
  if total > M.max_file_lines then
    ctx_start = math.max(0, target.decl_start - M.window)
    ctx_end = math.min(total, target.decl_end + 1 + M.window)
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

--- Strips reasoning tags, markdown fences, surrounding blank lines, and trailing whitespace.
local function clean_reply(text)
  text = text:gsub("<think>.-</think>", "")
  text = text:gsub("^%s*```%w*\n", ""):gsub("\n```%s*$", "")
  text = vim.trim(text)
  local lines = vim.split(text, "\n", { plain = true })
  for i, l in ipairs(lines) do
    lines[i] = l:gsub("%s+$", "")
  end
  return lines
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

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

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
    local replaced = target.replace_to > target.insert_at
    vim.api.nvim_buf_set_lines(bufnr, target.insert_at, target.replace_to, false, lines)
    notify((replaced and "replaced" or "inserted") .. " " .. level .. " docs")
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
