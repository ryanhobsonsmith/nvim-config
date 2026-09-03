-- Restores the settings ftplugin/asm.vim would normally provide. Neovim ships
-- no ftplugin/nasm.vim of its own, and g:asmsyntax (options.lua) makes .asm
-- files resolve to filetype "nasm" rather than "asm", so the stock ftplugin
-- never loads. Mirrors ftplugin/asm.vim (see `:e $VIMRUNTIME/ftplugin/asm.vim`).
if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = true

-- vim.opt_local.comments would treat the string as flag-list input and
-- mangle it; 'comments' wants the raw comma-separated string verbatim.
vim.bo.include = [[^\s*%\s*include]]
vim.bo.comments = ":;,s1:/*,mb:*,ex:*/,://,:#"
vim.bo.commentstring = "; %s"

vim.b.undo_ftplugin = "setl commentstring< comments< include<"

if not vim.b.match_words then
  vim.b.match_skip = [[s:comment\|string\|character\|special]]
  vim.b.match_words = [[^\s*%\s*if\%(\|num\|idn\|nidn\)\>:^\s*%\s*elif\>:^\s*%\s*else\>:^\s*%\s*endif\>,]]
    .. [[^\s*%\s*macro\>:^\s*%\s*endmacro\>,^\s*%\s*rep\>:^\s*%\s*endrep\>]]
  vim.b.match_ignorecase = true
  vim.b.undo_ftplugin = vim.b.undo_ftplugin .. " | unlet! b:match_ignorecase b:match_words b:match_skip"
end
