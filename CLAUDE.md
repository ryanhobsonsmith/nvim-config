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
  - `cc` / `gcc` / `clang` → `lang.clangd` (C/C++)
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

## C Development

C support is gated on a compiler (`cc`/`gcc`/`clang`) in `lua/config/lazy.lua`, which
imports LazyVim's `lang.clangd` extra. That extra provides: **clangd** LSP
(`--background-index --clang-tidy --header-insertion=iwyu`, mason-installed), the `cpp`
Tree-sitter parser (`c` is in LazyVim's base), **codelldb** DAP with generic
`Launch file` / `Attach to process` configs, `<leader>ch` (switch source/header), and
clangd_extensions completion scoring.

On top of the extra, this config adds:

- **Formatting** (`lua/plugins/conform.lua`): `clang_format` for `c`/`cpp`, run on save.
  `clang-format` ships with the LLVM/clang package; on a gcc-only machine install it with
  `:MasonInstall clang-format`. Respects a project `.clang-format`, else LLVM style.
- **Build-and-debug provider** (`lua/plugins/dap-c.lua`): mirrors `dap-odin.lua`. A dap
  config provider (`0.c.file`) compiles the current single file with `-g` on demand and
  debugs it via codelldb, appearing at the top of `<leader>dc`; `<leader>dF` is the direct
  key. Also re-declares the codelldb mason ensure so a C-only machine (no Odin) still gets
  the adapter. The extra's `Launch file`/`Attach` configs are untouched — use those for
  binaries produced by a build system.
- **Single-file run tasks** (`lua/overseer/template/c.lua`): mirrors the Odin template.
  Offers `run`/`build`/`check` for a lone `.c` under `<leader>rr`, with a gcc/clang
  errorformat feeding the quickfix. Make/Just projects are already covered by overseer's
  builtin providers — no custom template needed for those.

**compile_commands.json:** for multi-file Make/Just projects, clangd needs a
`compile_commands.json` at the project root for correct cross-file diagnostics. Generate it
with `bear -- make`, have the build emit it (CMake: `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`),
or commit one. Single-file programs work without it.

## Pending Follow-ups

- **codediff.nvim folding** (`lua/plugins/diffview.lua`): We swapped diffview for
  codediff, but codediff has no diff-aware folding (collapsing unchanged regions).
  Track [esmuellert/codediff.nvim#344](https://github.com/esmuellert/codediff.nvim/pull/344).
  When merged, enable the new "compact mode" option in the codediff plugin spec.

## Per-Project Preferences

`lua/config/projects.lua` is a centralized table of per-project settings: rules keyed by
directory prefix (`~` expanded; a rule covers the directory and everything beneath it,
deepest match wins), with fallbacks in `M.defaults`. Consumers call
`require("config.projects").get(key, path)`. This deliberately avoids `exrc`/`.nvim.lua`
and `.lazy.lua` (no trust prompts, no stray files in work repos) — revisit those if
per-repo overrides in the repos themselves are ever wanted.

Currently wired: `hide_tests` — the default for the snacks picker test-file filter in
`lua/plugins/snacks.lua` (hidden under `~/algebralabs`, shown everywhere else; `<a-t>`
still toggles per picker). It's resolved via a snacks source `config` function on every
picker open (snacks runs each config layer's `config(opts)` during option resolution),
keyed on the picker's `cwd`, so it tracks `:cd` and root-dir vs cwd pickers correctly.

## Key Conventions

- Plugin specs follow LazyVim patterns: use `opts` tables/functions to merge with or override defaults. See `lua/plugins/example.lua` for reference patterns.
- LazyVim provides default options, keymaps, and autocmds. Customizations in `lua/config/` extend or override those defaults — check LazyVim source before duplicating behavior.
- Default autocommand groups from LazyVim are prefixed with `lazyvim_` and can be removed with `vim.api.nvim_del_augroup_by_name()`.

## Config Gotchas

### Diagnostic config: override at the LSP plugin level, not via `vim.diagnostic.config()`

LazyVim sets `vim.diagnostic.config` inside `nvim-lspconfig`'s `config` function, which runs *after* `VeryLazy`. Any `vim.diagnostic.config({...})` call in `keymaps.lua` or `autocmds.lua` gets clobbered once LSP loads. To change defaults like `virtual_text`, override `opts.diagnostics.*` in `lua/plugins/lsp.lua` — that's the source of truth. Runtime toggles (e.g. Snacks toggles that flip state on demand) still work fine since they fire after setup.

### `keymaps.lua` is eager-loaded *before* lazy.nvim in `init.lua`

`init.lua` does `require("config.keymaps")` *before* `require("config.lazy")`. This is intentional — multi-char maps like `gyp` need to be live from the first keystroke, and waiting for LazyVim's VeryLazy reload leaves a startup window where `p` pastes. Two consequences to keep in mind:

1. **`vim.g.mapleader` / `vim.g.maplocalleader` must be set in `init.lua` before the require.** LazyVim's `options.lua` normally sets them, but that runs later. Any `<leader>…` map registered before leaders are set binds to the default `\`, not space — the map silently ends up on the wrong key. (Symptom: `:verbose nmap <leader>foo` says "No mapping found"; pressing the key does nothing or falls through.) Leaders are set explicitly at the top of `init.lua` for exactly this reason — keep them there.

2. **Lua's `require` caches the module**, so LazyVim's later VeryLazy reload of `config.keymaps` is a silent no-op — the file only executes once. Don't rely on a second pass to "fix up" anything.

### `Snacks` globals aren't ready when `keymaps.lua` loads

Because of the eager load above, `Snacks.toggle` and other `Snacks.*` globals are nil when `lua/config/keymaps.lua` first executes. If a keymap needs `Snacks`, wrap the definition in a `User VeryLazy` autocmd so it runs after Snacks initializes.

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

### Clipboard provider

Configured in `lua/config/options.lua`, branched on `vim.fn.has("mac")`:

- **macOS**: `pbcopy` / `pbpaste` for both `+` and `*`.
- **Everywhere else (Linux local, any SSH)**: OSC 52 for both copy and paste via `vim.ui.clipboard.osc52`.

**Why platform and not SSH state:**

An earlier version branched on `vim.env.SSH_CONNECTION`. That variable doesn't survive tmux reattach — tmux preserves the env from when the server first started, so a tmux session created before the SSH connection (or reattached from a fresh SSH) hands nvim a context where `SSH_CONNECTION` is unset, the local branch wins, and `pbcopy` fails because it doesn't exist on Linux. Branching on platform sidesteps the propagation problem entirely: the question we actually want to answer is "do I have `pbcopy`," not "am I in an SSH session."

**Why branch instead of a single provider:**

LazyVim sets `clipboard=unnamedplus`, so every `y`/`d`/`p` goes through the `+` register — the provider runs on every cursor-adjacent edit, not just explicit `"+y`/`"+p`. That makes the provider's reliability a hot path.

A previous config was also asymmetric: OSC 52 copy + `pbpaste` paste. OSC 52 copy travels nvim → tmux → outer terminal → system clipboard via an escape sequence; `pbpaste` reads the macOS clipboard directly. When any link in the escape chain drops the sequence (notably tmux `display-popup`, which runs in a separate client context and relays OSC 52 less reliably than regular panes), copy silently no-ops while paste still reads the real clipboard. Result: `dd` then `p` pastes stale clipboard content instead of the just-yanked line.

**Why this split works:**

- On macOS, `pbcopy`/`pbpaste` bypass the terminal entirely — popups, nested tmux, ghostty quirks all become irrelevant. Both directions hit the same macOS pasteboard.
- On Linux or over SSH, `pbcopy` doesn't exist (or would touch the wrong clipboard on a remote host). OSC 52 is the only mechanism that can traverse the terminal/SSH pipe back to whichever terminal is rendering nvim. Using it for both directions keeps copy and paste symmetric — whatever the escape chain delivers for copy is what paste queries for.

**Caveats:**

- OSC 52 paste requires terminal OSC 52 *read* support. Ghostty supports it; tmux 3.4+ relays it. Older tmux may hang the paste query — if that becomes an issue, drop the `paste` branch on the non-mac side and rely on terminal paste (Cmd+V / Ctrl+Shift+V) for bringing outside text into nvim.
- Nested SSH hops need OSC 52 pass-through at each layer.

## Snippets

Custom VSCode-format snippets live in `snippets/` (registered via `snippets/package.json`,
auto-loaded by blink.cmp's default snippets source — no plugin config needed). Currently
`react.json` (typescriptreact/javascriptreact) and `odin.json`. Tab / Shift-Tab jump
between placeholders. `<A-s>` (insert mode) opens a snippets-only completion menu.

Ranking (`lua/plugins/blink.lua`): snippets keep blink's default (below LSP) ranking,
except a snippet whose prefix *exactly* equals the typed keyword gets a large boost so
e.g. typing `proc` puts the `proc` snippet above the `proc` keyword. Avoid a blanket
`score_offset` on the snippets provider — it buries LSP member completions.

Odin: ols also ships 8 builtin snippets via LSP (`proc`, `main`, `st`, `if`, `forr`,
`fori`, `ff`, `fl`), but they only appear in identifier position and disappear once the
keyword is fully typed. They are filtered out client-side (LSP `transform_items` drops
`kind == Snippet` items in Odin buffers) and replaced by equivalents in `odin.json`. ols's
procedure auto-paren completions are `kind == Function` and unaffected.

## AI Tooling

Three AI assistants coexist with distinct keymap prefixes to avoid collisions:

- **Copilot** (`lua/plugins/copilot.lua`) — disabled at startup; `:Copilot enable` to turn on. Tab-completion agent, not chat.
- **Avante** (`lua/plugins/avante.lua`, `<leader>a` prefix) — Cursor-style inline edits and sidebar chat. Configured providers: `lmstudio` (OpenAI-compatible at `http://127.0.0.1:1234/v1`, default), `copilot`, and a couple of `ollama-*` variants. Switch with `:AvanteSwitchProvider`. Each provider has a hardcoded default model; override via `providers.<name>.model`. Note: Avante's `setup()` eagerly initializes the configured provider — picking `copilot` as default would throw on machines that haven't run `:Copilot auth` (no `~/.config/github-copilot/{hosts,apps}.json`) and abort the whole plugin's config, which is why the default is the always-reachable local one. **Build:** the extra's `build = "make"` compiles avante's Rust libraries from source and requires cargo (rustup via Homebrew; keg-only, PATH set in `.zshrc`). Don't switch to the prebuilt-binary path (`build.sh`): the published macOS artifacts are built on Nix CI and link `/nix/store/...` dylibs that don't exist on a normal Mac (`dlopen` fails; untracked upstream as of Aug 2026).
- **Claude Code** (`lua/plugins/claudecode.lua`, `<leader>C` prefix) — `coder/claudecode.nvim` (community plugin, implements Claude Code's IDE protocol; Anthropic has no first-party Neovim plugin).

### render-markdown for AI sidebars

`render-markdown.nvim` only renders filetypes in its `file_types` table (defaults to `{"markdown"}`). Add AI sidebar filetypes (e.g. `"Avante"`) to get headings, lists, and syntax-highlighted code blocks. Code block highlighting requires the target language's Tree-sitter parser installed (`:TSInstall <lang>`).
