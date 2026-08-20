-- Filetype detection for chezmoi source files (~/.local/share/chezmoi).
--
-- chezmoi.vim re-runs filetype detection using the *target* filename:
-- dot_shellrc -> .shellrc, executable_asb -> asb (shebang detection),
-- private_/encrypted_ prefixes stripped, and *.tmpl gets the underlying
-- filetype plus chezmoi template syntax on top.
return {
  {
    "alker0/chezmoi.vim",
    -- Must load at startup: it hooks BufNewFile/BufRead autocmds; lazy-loading
    -- would miss the first file opened from the CLI.
    lazy = false,
    init = function()
      -- Detect correctly in buffers created by `chezmoi edit` too.
      vim.g["chezmoi#use_tmp_buffer"] = true
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = function()
      -- `.shellrc` is a custom name vim doesn't know (unlike .zshrc/.bashrc),
      -- so even after chezmoi.vim maps dot_shellrc -> .shellrc it needs an
      -- explicit rule. It's sourced by both zsh and bash; treat as sh (the
      -- POSIX-ish common denominator, matching how it's written).
      vim.filetype.add({
        filename = {
          [".shellrc"] = "sh",
          ["dot_shellrc"] = "sh",
        },
      })
    end,
  },
}
