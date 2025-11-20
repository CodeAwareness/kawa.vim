" code-awareness.vim - Code Awareness plugin entry point
" Maintainer: Code Awareness
" License: MIT

if exists('g:loaded_code_awareness')
  finish
endif
let g:loaded_code_awareness = 1

" Check version requirements
if has('nvim')
  " Neovim 0.5.0+ required
  if !has('nvim-0.5.0')
    echohl WarningMsg
    echom 'code-awareness requires Neovim >= 0.5.0'
    echohl None
    finish
  endif
else
  " Vim 8.2+ required
  if v:version < 802
    echohl WarningMsg
    echom 'code-awareness requires Vim >= 8.2'
    echohl None
    finish
  endif

  " Python3 required for Vim
  if !has('python3')
    echohl WarningMsg
    echom 'code-awareness requires Python3 support in Vim'
    echohl None
    finish
  endif
endif

" Define user commands
if has('nvim')
  command! -nargs=* CodeAwareness lua require('code-awareness.commands').execute(<f-args>)
else
  " Vim needs special handling for passing args to Lua
  command! -nargs=* CodeAwareness call s:ExecuteCommand(<f-args>)

  function! s:ExecuteCommand(...) abort
    let l:args = a:000
    if len(l:args) == 0
      lua require('code-awareness.commands').execute()
    elseif len(l:args) == 1
      execute 'lua require("code-awareness.commands").execute("' . l:args[0] . '")'
    else
      " Pass multiple args as array
      let l:args_str = '["' . join(l:args, '","') . '"]'
      execute 'lua require("code-awareness.commands").execute_array(' . l:args_str . ')'
    endif
  endfunction
endif

" Auto-start on VimEnter if configured
augroup CodeAwarenessInit
  autocmd!
  autocmd VimEnter * lua require('code-awareness').on_vim_enter()
augroup END
