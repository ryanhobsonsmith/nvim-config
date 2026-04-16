return {
  {
    "yetone/avante.nvim",
    opts = {
      provider = "copilot",
      providers = {
        lmstudio = {
          __inherited_from = "openai",
          endpoint = "http://127.0.0.1:1234/v1",
          model = "qwen3.5-35b-a3b@q4_k_m",
          api_key_name = "",
        },
      },
    },
  },
}
