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

## TypeScript Expandable Hover

`K` in a TypeScript buffer runs `require("config.ts_hover").hover()` (wired via `keys` on the
`tsgo`/`vtsls` server specs in `lua/plugins/typescript.lua`). While the hover is visible, `+`
expands type aliases one level and `-` collapses; moving the cursor closes it and restores
the stock `+`/`-` motions.

- **tsgo path** (`lua/config/ts_hover.lua`): tsgo implements TS 5.9's expandable hover over
  plain LSP. It only does so when the client advertises
  `capabilities.experimental.hoverVerbosityLevel = true` (set on the `tsgo` server spec);
  then `textDocument/hover` accepts `verbosityLevel` and the reply carries
  `canIncreaseVerbosity`. Rendering goes through noice's hover message so it looks like
  regular hover. Two noice quirks are worked around: `Message:bufs()` is broken (self/colon
  bug), so float buffers are found via `wins()`; and re-rendering a *focused* nui popup
  breaks, so `+`/`-` pressed inside the float first hop back to the source window and
  re-request after noice's autohide settles.
- **vtsls path**: `ts-expand-hover.nvim` (uses vtsls's `typescript.tsserverRequest`
  command, which tsgo lacks). Only enabled when `vim.g.lazyvim_ts_lsp == "vtsls"`;
  `config.ts_hover` hands off to it when no tsgo client is attached.

Capabilities are negotiated at LSP startup, so changes here need a Neovim restart, not
just `:LspRestart` of a running config that predates them.

## Quill AI (`lua/quill-ai/`)

A small local plugin for fast, targeted AI edits. Commands only, no keymaps:

- `:QuillDocs [lite|normal|full]` — doc comment for the function under the cursor (or a
  visual range). No level opens a picker. `lite` = one-line summary, `normal` = summary
  plus parameters/returns, `full` = public-library API docs with examples.
- `:QuillFast [instruction]` — rewrite the visual selection (or the whole file when there
  is no range) per the instruction. No instruction opens `vim.ui.input`. Whole file is
  always sent as context; the model returns only the region's replacement.
- `:Quill [instruction]` — identical to `:QuillFast` but on the `normal` tier: OpenAI
  `gpt-6-luna` billed to the ChatGPT plan through the Codex CLI login (no API key).
- `:QuillCancel` — kill the in-flight request. One request at a time; a second one is
  refused until the first finishes or is cancelled.

**Configuration lives in `lua/plugins/quill-ai.lua` and nowhere else.** It is a lazy.nvim
`virtual = true` spec (the code is already on the rtp under `lua/quill-ai/`, lazy only runs
`setup(opts)`); when the plugin is extracted to its own repo, swap the name for the GitHub
slug and keep `opts`. `opts.tiers.<name>` = `{ url, model, api_key_file | api_key_env,
timeout_s, max_tokens, temperature, apply }` where `apply` is `"direct"` (replace in place,
one undo step) or `"diff"` (side-by-side preview: `<CR>`/`ga` accept, `q` reject).
`opts.commands.<tier> = "CommandName"` creates the refactor command for that tier. Tiers:
`fast` (Celeris, key read from `~/.config/celeris/api-key` at call time, ~0.3s) and
`normal` (`auth = "codex"`). For plain API-key tiers, current OpenAI models reject
`max_tokens` and non-default `temperature`, hence the per-tier
`max_tokens_field = "max_completion_tokens"` and `temperature = false` (omits the field).
Defaults are in `lua/quill-ai/config.lua`.

**Codex auth (`auth = "codex"`):** OpenAI allows ChatGPT subscriptions to be used from
third-party harnesses (Cline, OpenCode, pi, OpenClaw all do this). The credential is the
OAuth access token the Codex CLI stores in `~/.codex/auth.json` (`tokens.access_token`,
`tokens.account_id`), not an API key. Requests go to
`https://chatgpt.com/backend-api/codex/responses` as the Responses API with `stream=true`
and `store=false` (both mandatory), headers `chatgpt-account-id`, `OpenAI-Beta:
responses=experimental`, and `originator`; the system prompt goes in `instructions`, no
token cap or temperature is accepted, and only bare Codex model IDs work. The full SSE body
is collected by curl and parsed by `client.parse_responses_sse` (text from
`response.completed`'s output, falling back to concatenated `output_text.delta`s;
`response.incomplete` → `truncated`). The plugin deliberately **never refreshes** the token:
OpenAI rotates refresh tokens on use and its CI docs warn that two refreshers on one
`auth.json` invalidate each other's login. An expired token (checked from the JWT `exp`) or
a 401 produces a notice to run any `codex` command, which refreshes the bundle.

Modules: `init.lua` (setup, commands, in-flight tracking), `config.lua`, `client.lua`
(one-shot `curl` via `vim.system`; reports `finish_reason == "length"` as `truncated`;
kill → `"cancelled"`), `util.lua` (`notify`, `clean_reply`), `docs.lua`, `refactor.lua`,
`diff.lua`, `langs/` (one spec per language plus `wrap.lua` delimiter helpers and
`jsdoc.lua` shared by TS/JS). Not an agent CLI on purpose: opencode/celeris-cli startup,
MCP servers, and tool loops are the wrong shape for a one-shot completion.

**Docs detection:** Tree-sitter. Walks up from the cursor to a node in the language's
`decl_types`, through an optional `resolve` hook (TS climbs to `export_statement` and only
accepts arrow/function expressions bound to a name; C accepts a `declaration` only if it
holds a `function_declarator`; Python unwraps `decorated_definition`). If no ancestor
matches, it searches downward for a declaration starting on the cursor row, so the cursor
can sit on `export`, `const`, or a decorator. Placement `above`: an adjacent run of comment
nodes is the existing doc and gets replaced. Placement `inside` (Python): the first body
statement is checked for a docstring. The old doc is passed to the model as a hint.
Supported: `odin` (core-library `/* */` with Inputs/Returns/Example/Output),
`typescript`/`typescriptreact` (JSDoc, no brace types), `javascript`/`javascriptreact`
(JSDoc with `{type}`), `go` (`//` prose starting with the name), `c` (Doxygen), `python`
(Google-style PEP 257). Whole file is context when ≤ `docs.max_file_lines` (400), else a
`docs.window` of 60 lines around the function.

**Refactor prompt:** the file is sent with the region wrapped in `<<<REGION>>>` /
`<<<END REGION>>>` marker lines (alternate markers are chosen if the file contains those
strings) and the model is told to return only the region's new contents. `sanitize()`
strips fences, `<think>` blocks, and leading chatter, extracts between markers if the model
echoed them, and if a whole file came back for a partial region strips the untouched
prefix/suffix when they match exactly. When that fails, or the reply was truncated, the
result is shown as a diff preview instead of applied blind, whatever the tier's `apply`.
Insertion is skipped if the buffer's changedtick moved while the request was in flight.

**Reply cleanup for docs:** the language's `wrap` adds delimiters if the model omitted
them. The Python wrapper also truncates after the first closing `"""` and appends one if
missing, since small models sometimes tack sections on after the docstring or forget to
close it.

**Adding a language:** create `lua/quill-ai/langs/<ft>.lua` returning a spec (`name`,
`decl_types`, optional `resolve`, `doc_types` or `placement = "inside"`, `style`, per-level
prompts each with a real-world example of the shape, `wrap`), then add it to `modules` (and
any filetype alias) in `langs/init.lua`. **Adding a tier:** add `opts.tiers.<name>` and
`opts.commands.<name>` in `lua/plugins/quill-ai.lua`.

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

### Autosave writes bypass `BufWriteCmd` (autocmds don't nest)

The FocusLost/BufLeave autosave in `lua/config/autocmds.lua` calls `:write` from inside an
autocmd callback. Autocmds don't nest by default, so that write triggers no
`BufWriteCmd`/`BufWritePre`/`BufWritePost`: a buffer whose file is owned by a `BufWriteCmd`
handler (snacks image buffers, hexview, anything similar) gets Neovim's plain writer instead
and the file is overwritten with the buffer's display text. This truncated a png to 0 bytes
on 2026-09-11 (snacks's placeholder rendering flags image buffers `modified`). The autosave
guards on `filetype` for known cases; extend it when adding another virtual-file buffer
type, or switch the autocmd to `nested = true` (then format-on-save also runs on autosave).

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

## Images

`lua/plugins/image.lua` enables snacks.image (Kitty graphics protocol). Opening a
png/jpg/gif/webp/pdf/... renders it in the buffer; markdown/html/tsx and friends render
referenced images inline. SVGs deliberately stay out of `formats` so they open as editable
XML; `:ImageView` (`<leader>iv`) previews the current file as an image in a float, and
`:ImageSource` does the reverse for intercepted formats (reopen a png/pdf as text). SVG/PDF
rasterize through ImageMagick (`convert`, IM6 is fine; IM6's builtin SVG renderer ignores
CSS/filters, so complex SVGs may look off -- `librsvg2-bin` or ImageMagick 7 fixes that).

The stack is tmux + ssh + ghostty, and each layer needs something:

- **tmux**: graphics escapes are wrapped in DCS passthrough (`allow-passthrough` is on in
  `~/.tmux.conf`; snacks additionally sets it to `all` on its own pane) and images are placed
  with unicode placeholders so tmux treats them as text.
- **ssh**: snacks detects `SSH_CONNECTION` and sends image bytes inline (kitty `t=d`) instead
  of by filename. Same tmux-reattach caveat as the clipboard: a tmux session created before
  the ssh connection may not see `SSH_CONNECTION`; `SNACKS_SSH=true` forces it.
- **ghostty detection**: inside tmux snacks reads `#{client_termname}`, and `~/.ssh/config`
  forces `SetEnv TERM=xterm-256color`, so over ssh it sees `xterm-256color` and would report
  "terminal does not support the kitty graphics protocol". `image.lua` sets
  `SNACKS_GHOSTTY=true` unconditionally to override. Dropping the `SetEnv` (the
  `xterm-ghostty` terminfo is installed on this host) would make detection work on its own.

Known snacks bugs worked around in `image.lua` (upstream main as of 2026-09): a file-viewer
placement is `hide()`-den when its window goes away and never shown again, so switching back
to an image buffer rendered blank (patched: `hide` is a no-op for `filetype=image`). Don't
"fix" it by re-attaching: closing a placement mid-conversion leaves its spinner timer alive,
clearing the buffer's extmarks forever.

`:checkhealth snacks` shows what was detected. `SNACKS_<ENV>=true|false` overrides any
environment (`GHOSTTY`, `TMUX`, `SSH`, `KITTY`, ...).

## AI Tooling

Three AI assistants coexist with distinct keymap prefixes to avoid collisions:

- **Copilot** (`lua/plugins/copilot.lua`) — disabled at startup; `:Copilot enable` to turn on. Tab-completion agent, not chat.
- **Avante** (`lua/plugins/avante.lua`, `<leader>a` prefix) — Cursor-style inline edits and sidebar chat. Configured providers: `lmstudio` (OpenAI-compatible at `http://127.0.0.1:1234/v1`, default), `copilot`, and a couple of `ollama-*` variants. Switch with `:AvanteSwitchProvider`. Each provider has a hardcoded default model; override via `providers.<name>.model`. Note: Avante's `setup()` eagerly initializes the configured provider — picking `copilot` as default would throw on machines that haven't run `:Copilot auth` (no `~/.config/github-copilot/{hosts,apps}.json`) and abort the whole plugin's config, which is why the default is the always-reachable local one. **Build:** the extra's `build = "make"` compiles avante's Rust libraries from source and requires cargo (rustup via Homebrew; keg-only, PATH set in `.zshrc`). Don't switch to the prebuilt-binary path (`build.sh`): the published macOS artifacts are built on Nix CI and link `/nix/store/...` dylibs that don't exist on a normal Mac (`dlopen` fails; untracked upstream as of Aug 2026).
- **Claude Code** (`lua/plugins/claudecode.lua`, `<leader>C` prefix) — `coder/claudecode.nvim` (community plugin, implements Claude Code's IDE protocol; Anthropic has no first-party Neovim plugin).

### render-markdown for AI sidebars

`render-markdown.nvim` only renders filetypes in its `file_types` table (defaults to `{"markdown"}`). Add AI sidebar filetypes (e.g. `"Avante"`) to get headings, lists, and syntax-highlighted code blocks. Code block highlighting requires the target language's Tree-sitter parser installed (`:TSInstall <lang>`).
