-- Shared pieces for the TypeScript and JavaScript specs.

local wrap = require("quill-ai.langs.wrap")

local M = {}

--- If `node`'s parent is one of `types`, return the parent.
local function climb_if_parent(node, types)
  local p = node:parent()
  if p and types[p:type()] then
    return p
  end
  return node
end

--- Anonymous functions count only when bound to a name (variable, class
--- field, object key, assignment); callbacks are rejected so the walk
--- continues to the enclosing named function. Exported declarations resolve
--- to the `export_statement` so the comment lands above `export`.
function M.resolve(node)
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

M.style = [[
Use a JSDoc block: `/**` on its own line, every body line prefixed with ` * `, and ` */`
on its own line. A one-sentence summary comes first, in third person ("Returns...",
"Creates..."). Tag sections follow after a blank ` *` line, in this order: `@param`,
`@returns`, `@throws`, `@example`, `@remarks`/`@see`. Use `@param name - description`
with a hyphen. Omit `@returns` for `void`/`undefined` results and for constructors. Use
`@template` for generic type parameters when they matter. Never restate the signature in
prose. Wrap code identifiers in backticks.
]]

--- Builds a spec. `typed` = JavaScript (types in braces); false = TypeScript.
function M.spec(name, typed)
  local p = typed and "{number} " or ""
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
    .. p
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
    resolve = M.resolve,
    doc_types = { comment = true },
    style = M.style .. type_rule,
    wrap = wrap.star_block,
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

return M
