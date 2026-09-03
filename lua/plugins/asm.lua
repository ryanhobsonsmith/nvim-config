-- Assembly tooling.
--
-- asm-lsp (bergercookie/asm-lsp) gives hover docs on instructions/registers/
-- directives for NASM/GAS. Mason knows how to build it via cargo and maps it
-- to nvim-lspconfig's `asm_lsp` server, whose default filetypes = { "asm",
-- "vmasm" } miss "nasm" — the filetype .asm files actually resolve to, since
-- g:asmsyntax (options.lua) redirects them there for NASM-flavored syntax
-- highlighting. Add "nasm" so the server still attaches.
-- Gated on nasm like odin.lua gates on ols: no point installing a Rust build
-- for a toolchain that isn't here.
local specs = {}

if vim.fn.executable("nasm") == 1 then
  table.insert(specs, {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        asm_lsp = {
          filetypes = { "asm", "vmasm", "nasm" },
        },
      },
    },
  })
end

-- hexview.nvim: pure-Lua hex/ASCII editor for binaries, auto-activates on
-- binary files or files containing null bytes. No external tooling needed.
table.insert(specs, {
  "DamianVCechov/hexview.nvim",
  config = function()
    require("hexview").setup()
  end,
})

-- hexview.nvim never touches 'signcolumn'/'foldcolumn', so with LazyVim's
-- default `signcolumn = "yes"` (a permanent 1-column gutter, so text doesn't
-- jump when diagnostics/git-signs appear) buffer *text* sits one column
-- right of where it'd otherwise be. The header row is rendered via
-- `winbar`, a separate UI strip spanning the full window width that the
-- gutter doesn't push over — so the "Offset"/column-number header ends up
-- one column left of the hex/ASCII content beneath it. `BufWinEnter` (not
-- just `FileType`) so re-displaying the same hexview buffer in a new split
-- gets the window-local fix too, since FileType only fires once per buffer.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "hexview" then
      vim.wo.signcolumn = "no"
      vim.wo.foldcolumn = "0"
    end
  end,
})

-- `nasm foo.asm` with no `-f` flag defaults to `-f bin`: a headerless flat
-- binary named `foo`, no extension, sitting next to `foo.asm`. Unlike
-- ELF/Mach-O output, it has no NUL byte for hexview.nvim's own BufReadPost
-- auto-detect to catch (see lua/hexview/init.lua's binary/`%z` check), so
-- opening it any normal way (explorer, picker, `:e`) loads it as text.
-- That's not just cosmetically wrong: entering hex mode afterwards on an
-- already-text-loaded buffer, or even just viewing it, flips 'modified' with
-- zero real edits (hexview's own render calls nvim_buf_set_lines), and this
-- config's autosave_on_focus_lost (autocmds.lua) will silently write that
-- back over the real binary on the next window switch — confirmed
-- reproducible, corrupted a real build artifact once already.
--
-- Setting 'binary' at BufReadPre — before Neovim reads a single byte, not
-- after like hexview's own hook — sidesteps all of that: the file is never
-- interpreted as text in the first place, hexview's BufReadPost check
-- (`vim.bo[buf].binary`) sees it already set and activates the hex view
-- automatically. No `-b`/`++bin`/`:Hex` to remember for these files.
--
-- Registered here (module top level, not inside a plugin's `config`/`opts`)
-- so it runs at lazy.nvim spec-resolution time, before VeryLazy — see
-- options.lua's g:asmsyntax comment for why that ordering matters for
-- anything gating on a FileType/BufReadPre race.
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(ev)
    local name = vim.fn.fnamemodify(ev.match, ":t")
    if name == "" or name:find("%.") then
      return
    end
    if vim.fn.filereadable(ev.match .. ".asm") == 1 then
      vim.bo[ev.buf].binary = true
    end
  end,
})

return specs
