-- Go: // prose doc comments beginning with the name.

local wrap = require("quill-ai.langs.wrap")

return {
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
  wrap = wrap.line_comments,
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
