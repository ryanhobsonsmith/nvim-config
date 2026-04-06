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

Configured in `lazyvim.json`: copilot, docker, go, json, markdown, python, sql, tailwind, typescript, yaml.

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

## Key Conventions

- Plugin specs follow LazyVim patterns: use `opts` tables/functions to merge with or override defaults. See `lua/plugins/example.lua` for reference patterns.
- LazyVim provides default options, keymaps, and autocmds. Customizations in `lua/config/` extend or override those defaults — check LazyVim source before duplicating behavior.
- Default autocommand groups from LazyVim are prefixed with `lazyvim_` and can be removed with `vim.api.nvim_del_augroup_by_name()`.
