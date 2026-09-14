-- quill-ai: model, endpoint, and API-key configuration lives HERE and nowhere
-- else. The plugin code is in lua/quill-ai/ (already on the runtimepath), so
-- lazy.nvim only needs to run setup — hence `virtual = true`. When the plugin
-- is extracted to its own repo, replace `"quill-ai", virtual = true` with the
-- GitHub slug and leave `opts` as-is.
--
-- Tiers: each is an OpenAI-compatible chat endpoint plus an `apply` mode
-- ("direct" replaces text in place, "diff" opens a side-by-side preview). Each
-- tier gets a refactor command from the `commands` table. See
-- lua/quill-ai/config.lua for every default.
return {
  {
    "quill-ai",
    virtual = true,
    main = "quill-ai",
    event = "VeryLazy",
    opts = {
      tiers = {
        fast = {
          url = "https://inference.celeris.ai/celeris-1/v1/chat/completions",
          model = "celeris-1",
          api_key_file = "~/.config/celeris/api-key",
          apply = "direct",
        },
      },
      commands = {
        fast = "QuillFast",
      },
    },
  },
}
