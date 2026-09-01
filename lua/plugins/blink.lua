return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        -- Show only snippet completions (Alt-s in insert mode)
        ["<A-s>"] = {
          function(cmp)
            return cmp.show({ providers = { "snippets" } })
          end,
        },
      },
      sources = {
        providers = {
          lsp = {
            -- Drop ols's builtin snippets (kind = Snippet) in Odin buffers: they
            -- vanish once the keyword is fully typed (parser context changes),
            -- so we ship our own in snippets/odin.json instead. Procedure
            -- completions (kind = Function) with auto-parens are unaffected.
            transform_items = function(ctx, items)
              if vim.bo[ctx.bufnr].filetype ~= "odin" then
                return items
              end
              local Snippet = vim.lsp.protocol.CompletionItemKind.Snippet
              return vim.tbl_filter(function(item)
                return item.kind ~= Snippet
              end, items)
            end,
          },
          snippets = {
            -- Lift a snippet to the top only when the typed keyword exactly
            -- equals its prefix (e.g. typing `proc` beats the `proc` keyword).
            -- Partial matches keep blink's default ranking, so LSP members and
            -- symbols still win during normal typing.
            transform_items = function(ctx, items)
              local keyword = ctx.get_keyword()
              if keyword == "" then
                return items
              end
              for _, item in ipairs(items) do
                if item.label == keyword then
                  item.score_offset = (item.score_offset or 0) + 10
                end
              end
              return items
            end,
          },
        },
      },
    },
  },
}
