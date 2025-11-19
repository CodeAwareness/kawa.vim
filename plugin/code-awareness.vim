" code-awareness.vim - Code Awareness plugin entry point
" Maintainer: Code Awareness
" License: MIT

if exists('g:loaded_code_awareness')
  finish
endif
let g:loaded_code_awareness = 1

" Check Neovim version
if !has('nvim-0.5.0')
  echohl WarningMsg
  echom 'code-awareness.nvim requires Neovim >= 0.5.0'
  echohl None
  finish
endif

" Define user commands
command! -nargs=* CodeAwareness lua require('code-awareness.commands').execute(<f-args>)

" Auto-start on VimEnter if configured
augroup CodeAwarenessInit
  autocmd!
  autocmd VimEnter * lua require('code-awareness').on_vim_enter()
augroup END
