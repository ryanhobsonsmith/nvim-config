return {
  {
    "yetone/avante.nvim",
    opts = {
      provider = "lmstudio",
      providers = {
        lmstudio = {
          __inherited_from = "openai",
          endpoint = "http://127.0.0.1:1234/v1",
          model = "qwen3.5-35b-a3b@q4_k_m",
          api_key_name = "",
        },
        ["ollama-qwen"] = {
          __inherited_from = "ollama",
          endpoint = "http://127.0.0.1:11434",
          model = "qwen3.6:35b-a3b-bf16",
        },
        ["ollama-gemma4"] = {
          __inherited_from = "ollama",
          endpoint = "http://127.0.0.1:11434",
          model = "gemma4:e4b",
        },
      },
    },
  },
}
