-- C: Doxygen (Javadoc style).

local wrap = require("quill-ai.langs.wrap")

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

return {
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
  wrap = wrap.star_block,
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
