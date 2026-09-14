-- Python: Google-style PEP 257 docstrings, placed inside the body.

local wrap = require("quill-ai.langs.wrap")

return {
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
  wrap = wrap.docstring,
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
