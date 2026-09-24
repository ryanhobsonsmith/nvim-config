" Syntax for fileaudit decision files (*.decisions).
" Install: copy or symlink into ~/.config/nvim/syntax/, then add to init.lua:
"   vim.filetype.add({ extension = { decisions = "fileaudit-decisions" } })
if exists("b:current_syntax") | finish | endif

syntax match faComment   /^#.*/
syntax match faUndecided /^\s*?\ze\s/
syntax match faFlatten   /^\s*flatten\ze\s/
syntax match faKeep      /^\s*keep:[^ ]\+\ze\s/
syntax match faDrop      /^\s*drop\ze\s/
syntax match faStats     /\s\{2,}[0-9,]\+ files\s\+\S\+\s\+.\{-}\ze\(\s\{2,}|\|$\)/
syntax match faNote      /|.*$/ contains=faWhy
syntax match faWhy       /|\s*\zs\d\+ [a-z ]\+\(,\s*\d\+ [a-z ]\+\)*/ contained

highlight default link faComment   Comment
highlight default link faUndecided Todo
highlight default link faFlatten   Comment
highlight default link faKeep      String
highlight default link faDrop      Error
highlight default link faStats     NonText
highlight default link faNote      Comment
highlight default link faWhy       WarningMsg

let b:current_syntax = "fileaudit-decisions"
