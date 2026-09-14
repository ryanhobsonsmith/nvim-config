-- Wrap helpers: add comment delimiters when the model returns a bare body.

local M = {}

local function starts_with_any(line, prefixes)
  for _, p in ipairs(prefixes) do
    if line:find(p, 1, true) == 1 then
      return true
    end
  end
  return false
end

--- `/** ... */` with ` * ` line prefixes (JSDoc, Doxygen).
function M.star_block(lines)
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
function M.plain_block(lines)
  if starts_with_any(vim.trim(lines[1] or ""), { "/*", "//" }) then
    return lines
  end
  local out = { "/*" }
  vim.list_extend(out, lines)
  out[#out + 1] = "*/"
  return out
end

--- `// ` on every line (Go).
function M.line_comments(lines)
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
function M.docstring(lines)
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

return M
