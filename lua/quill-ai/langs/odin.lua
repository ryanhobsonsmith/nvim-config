-- Odin: core-library style /* */ blocks.

local wrap = require("quill-ai.langs.wrap")

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

return {
  name = "Odin",
  decl_types = { procedure_declaration = true },
  doc_types = { block_comment = true, comment = true },
  style = ODIN_STYLE,
  wrap = wrap.plain_block,
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
