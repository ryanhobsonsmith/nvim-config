# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

This is the user's personal Neovim configuration. All work here is about modifying, improving, or troubleshooting the Neovim setup. Treat every request as a Neovim config change unless explicitly stated otherwise.

When the user asks how to do something in Neovim, they mean in **their specific LazyVim setup** — not vanilla Neovim. Always read the relevant parts of this config first (plugins, keymaps, options, extras) to understand what's already configured, then consult context7/web for current LazyVim and plugin docs. Never give generic Neovim answers that ignore the user's actual setup.

**IMPORTANT:** Before making ANY changes or answering questions, always look up current documentation using context7 MCP or web search. Training data may be outdated — Neovim APIs, LazyVim defaults, and plugin specs change frequently across versions. Never rely solely on memory for plugin options, API signatures, or default behaviors.

## Overview

This is a Neovim configuration built on [LazyVim](https://lazyvim.github.io/) (v8), a Neovim setup powered by [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager. It is a fresh starter template with minimal customization so far.

## Architecture

- `init.lua` — Entry point, loads `config.lazy`
- `lua/config/lazy.lua` — Bootstraps lazy.nvim and configures plugin loading. Imports `lazyvim.plugins` (the LazyVim distribution) and then `plugins/` (user overrides)
- `lua/config/options.lua` — Custom Neovim options (loaded before lazy.nvim startup)
- `lua/config/keymaps.lua` — Custom keymaps (loaded on VeryLazy event)
- `lua/config/autocmds.lua` — Custom autocommands (loaded on VeryLazy event)
- `lua/plugins/` — User plugin specs. Every `.lua` file here is auto-loaded by lazy.nvim. Add/override/disable LazyVim plugins here.

## Enabled LazyVim Extras

Extras are configured **programmatically in `lua/config/lazy.lua`**, NOT in `lazyvim.json` (that file is stale and unused — `:LazyExtras` will not reflect reality). The spec is built conditionally so the same config works across machines with different tooling installed:

- **Always-on** (no external tooling required): `coding.mini-surround`, `ui.treesitter-context`, `lang.json`, `lang.markdown`, `lang.yaml`
- **Conditional on `vim.fn.executable()` checks**:
  - `go` → `lang.go`
  - `python3` → `lang.python`
  - `node` → `lang.typescript`, `lang.tailwind`, `ai.copilot`, `ai.avante`
  - `docker` → `lang.docker`
  - `psql` / `mysql` / `sqlite3` → `lang.sql`

When adding a new extra, add it to the appropriate block in `lua/config/lazy.lua`. Gate it with `vim.fn.executable(...)` if it depends on external tooling. Do not edit `lazyvim.json`.

## Formatting

Lua files are formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua). Config in `stylua.toml`: 2-space indent, 120 column width.

```sh
stylua lua/
```

## Before Making Changes

Always check the latest Neovim and LazyVim documentation before making changes — APIs, defaults, and plugin specs change across versions. Use the context7 MCP tool to fetch up-to-date docs:
- **LazyVim**: library ID `/websites/lazyvim`
- **Neovim**: library ID `/websites/neovim_io_doc`
- **nvim-lspconfig**: library ID `/neovim/nvim-lspconfig`

## Live-Testing Changes via Tmux

When the user identifies a tmux pane running Neovim, you can send commands directly using the tmux MCP tools (e.g., `mcp__tmux__execute-command` with `rawMode=true`). This is useful for:
- Testing highlight color changes live with `:lua vim.api.nvim_set_hl(0, "Group", { fg = "#hex" })` without clearing cache/restarting
- Running `:Inspect` or other Neovim commands

The user's Neovim is typically in the `nvim` tmux session. Ask which pane if unclear.

## Colorscheme Notes

- Using **onedarkpro.nvim** with the `onedark` colorscheme
- onedarkpro **caches compiled highlights** — changes to opts require clearing the cache (`nvclear` alias) and restarting Neovim
- For fast iteration, use `vim.api.nvim_set_hl()` via tmux to test colors live, then bake final values into the config
- Custom highlights (Tree-sitter and LSP semantic tokens) go in the `opts.highlights` table
- Use `:Inspect!` on a token to see which highlight group is winning (highest priority wins)

## Pending Follow-ups

- **codediff.nvim folding** (`lua/plugins/diffview.lua`): We swapped diffview for
  codediff, but codediff has no diff-aware folding (collapsing unchanged regions).
  Track [esmuellert/codediff.nvim#344](https://github.com/esmuellert/codediff.nvim/pull/344).
  When merged, enable the new "compact mode" option in the codediff plugin spec.

## Key Conventions

- Plugin specs follow LazyVim patterns: use `opts` tables/functions to merge with or override defaults. See `lua/plugins/example.lua` for reference patterns.
- LazyVim provides default options, keymaps, and autocmds. Customizations in `lua/config/` extend or override those defaults — check LazyVim source before duplicating behavior.
- Default autocommand groups from LazyVim are prefixed with `lazyvim_` and can be removed with `vim.api.nvim_del_augroup_by_name()`.

## Config Gotchas

### Diagnostic config: override at the LSP plugin level, not via `vim.diagnostic.config()`

LazyVim sets `vim.diagnostic.config` inside `nvim-lspconfig`'s `config` function, which runs *after* `VeryLazy`. Any `vim.diagnostic.config({...})` call in `keymaps.lua` or `autocmds.lua` gets clobbered once LSP loads. To change defaults like `virtual_text`, override `opts.diagnostics.*` in `lua/plugins/lsp.lua` — that's the source of truth. Runtime toggles (e.g. Snacks toggles that flip state on demand) still work fine since they fire after setup.

### `Snacks` globals aren't ready when `keymaps.lua` loads

`Snacks.toggle` and other `Snacks.*` globals are nil when `lua/config/keymaps.lua` first executes. If a keymap needs `Snacks`, wrap the definition in a `User VeryLazy` autocmd so it runs after Snacks initializes. See the `<leader>uv` toggle in `keymaps.lua` for the pattern.

### Disabling lazy-loaded plugins on startup

For plugins that lazy-load on events (e.g. `copilot.lua` loads on `BufReadPost`), a `User LazyVimStarted` autocmd that calls the plugin's disable command is unreliable — if you open Neovim without a file (dashboard), the plugin isn't loaded yet and its user commands don't exist. Use a `config` hook that calls setup and then the disable API directly:

```lua
config = function(_, opts)
  require("copilot").setup(opts)
  require("copilot.command").disable()
end,
```

When overriding `config`, remember LazyVim's default config for most plugins is just `require(main).setup(opts)` — so you need to call setup yourself.

### `opts = function()` must return the opts table

Returning nothing from an `opts` function wipes out merged defaults from other specs (e.g. LazyVim extras). Always `return opts` (after mutation) when using the function form.

## AI Tooling

Three AI assistants coexist with distinct keymap prefixes to avoid collisions:

- **Copilot** (`lua/plugins/copilot.lua`) — disabled at startup; `:Copilot enable` to turn on. Tab-completion agent, not chat.
- **Avante** (`lua/plugins/avante.lua`, `<leader>a` prefix) — Cursor-style inline edits and sidebar chat. Configured providers: `copilot` (default) and `lmstudio` (OpenAI-compatible at `http://127.0.0.1:1234/v1`). Switch with `:AvanteSwitchProvider`. Each provider has a hardcoded default model; override via `providers.<name>.model`. Note: Copilot's "Auto" model is VS Code/JetBrains-only — not exposed to third-party clients.
- **Claude Code** (`lua/plugins/claudecode.lua`, `<leader>C` prefix) — `coder/claudecode.nvim` (community plugin, implements Claude Code's IDE protocol; Anthropic has no first-party Neovim plugin).

### render-markdown for AI sidebars

`render-markdown.nvim` only renders filetypes in its `file_types` table (defaults to `{"markdown"}`). Add AI sidebar filetypes (e.g. `"Avante"`) to get headings, lists, and syntax-highlighted code blocks. Code block highlighting requires the target language's Tree-sitter parser installed (`:TSInstall <lang>`).
