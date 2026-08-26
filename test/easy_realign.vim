set nocompatible
set nomore
execute 'set runtimepath^=' . fnameescape($EASY_ALIGN_ROOT)
execute 'set runtimepath^=' . fnameescape($EASY_REALIGN_ROOT)
runtime plugin/easy_align.vim
runtime plugin/easy_realign.vim
syntax on

function! s:reset(lines, cursor_line) abort
  enew!
  setlocal modifiable
  call setline(1, a:lines)
  if line('$') > len(a:lines)
    execute (len(a:lines) + 1) . ',$delete _'
  endif
  setlocal filetype=sh syntax=sh
  call cursor(a:cursor_line, 1)
  let v:errmsg = ''
endfunction

function! s:assert_error(command, pattern) abort
  let v:errmsg = ''
  silent! execute a:command
  call assert_match(a:pattern, v:errmsg)
endfunction

function! s:alias_fixture() abort
  return [
        \ '# :>>:EasyAlign */\s\+\|=[''"]/alrl*l0r0ig[]',
        \ "alias l='eza --color=always -lhr --no-user -smod --no-permissions'",
        \ "alias ll='eza --color=always -lhr --no-user -smod'",
        \ "alias la='eza --color=always -lhr --no-user -smod -A'",
        \ "alias lls='eza --color=always -lhr --no-user -ssize -A'",
        \ '# :<<:EasyAlign',
        \ ]
endfunction

let s:alias_expected = [
      \ '# :>>:EasyAlign */\s\+\|=[''"]/alrl*l0r0ig[]',
      \ "alias   l='eza --color=always -lhr --no-user -smod  --no-permissions'",
      \ "alias  ll='eza --color=always -lhr --no-user -smod'",
      \ "alias  la='eza --color=always -lhr --no-user -smod  -A'",
      \ "alias lls='eza --color=always -lhr --no-user -ssize -A'",
      \ '# :<<:EasyAlign',
      \ ]

" Public commands and bindable targets.
call assert_equal(2, exists(':EasyRealign'))
call assert_equal(2, exists(':EasyRealignAll'))
call assert_notequal('', maparg('<Plug>(EasyRealign)', 'n'))
call assert_notequal('', maparg('<Plug>(EasyRealignAll)', 'n'))

" The current-region command accepts the start, body, and close lines.
for s:cursor_line in [1, 3, 6]
  call s:reset(s:alias_fixture(), s:cursor_line)
  silent EasyRealign
  call assert_equal(s:alias_expected, getline(1, '$'))
endfor

" All fixed line-comment leaders are recognized and preserved.
for s:leader in ['#', '"', '//', '--', ';', '%']
  let s:input = [
        \ s:leader . ' :>>:EasyAlign =',
        \ 'a=1',
        \ 'bb=2',
        \ s:leader . ' :<<:EasyAlign',
        \ ]
  call s:reset(s:input, 2)
  silent EasyRealignAll
  call assert_equal(
        \ [s:input[0], 'a  = 1', 'bb = 2', s:input[3]],
        \ getline(1, '$'))
endfor

" Optional bang form is passed through.
call s:reset([
      \ '# :>>:EasyAlign! =',
      \ 'a=1',
      \ 'bb=2',
      \ '# :<<:EasyAlign',
      \ ], 2)
silent EasyRealign
call assert_equal([' a = 1', 'bb = 2'], getline(2, 3))

" Distinct regions use their own specifications and one undo restores both.
let s:all_input = [
      \ '# :>>:EasyAlign /\S\+\ze=/l1r0',
      \ "alias l='x'",
      \ "alias lls='x'",
      \ '# :<<:EasyAlign',
      \ '// :>>:EasyAlign! =',
      \ 'a=1',
      \ 'long=2',
      \ '// :<<:EasyAlign',
      \ ]
call s:reset(s:all_input, 1)
silent EasyRealignAll
call assert_equal(["alias   l='x'", "alias lls='x'"], getline(2, 3))
call assert_equal(['   a = 1', 'long = 2'], getline(6, 7))
silent undo
call assert_equal(s:all_input, getline(1, '$'))

" A bad later specification leaves an earlier valid region unapplied.
let s:atomic_input = [
      \ '# :>>:EasyAlign =',
      \ 'a=1',
      \ 'bb=2',
      \ '# :<<:EasyAlign',
      \ '# :>>:EasyAlign zzz',
      \ 'c=3',
      \ 'dd=4',
      \ '# :<<:EasyAlign',
      \ ]
call s:reset(s:atomic_input, 1)
call s:assert_error('EasyRealignAll', 'invalid EasyAlign specification at line 5')
call assert_equal(s:atomic_input, getline(1, '$'))

" Strict structural failures.
let s:bad_cases = [
      \ [['# :<<:EasyAlign'], 'orphan close marker'],
      \ [['# :>>:EasyAlign =', 'a=1'], 'unclosed region'],
      \ [['# :>>:EasyAlign =', '# :>>:EasyAlign =', 'a=1', '# :<<:EasyAlign'], 'nested start marker'],
      \ [['# :>>:EasyAlign =', 'a=1', '// :<<:EasyAlign'], 'comment leader mismatch'],
      \ [['# :>>:EasyAlign =', '# :<<:EasyAlign'], 'empty region'],
      \ [['# :>>:EasyAlign', 'a=1', '# :<<:EasyAlign'], 'malformed start marker'],
      \ ]
for s:case in s:bad_cases
  call s:reset(s:case[0], 1)
  call s:assert_error('EasyRealignAll', s:case[1])
endfor

" Options without a delimiter target are rejected instead of going interactive.
call s:reset(['# :>>:EasyAlign l1r0', 'a=1', '# :<<:EasyAlign'], 2)
call s:assert_error('EasyRealign', 'options but no delimiter target')
call s:reset(["# :>>:EasyAlign l1r0 {'ignore_groups': []}", 'a=1', '# :<<:EasyAlign'], 2)
call s:assert_error('EasyRealign', 'options but no delimiter target')

" Current-region lookup and buffer checks.
call s:reset(['outside', '# :>>:EasyAlign =', 'a=1', '# :<<:EasyAlign'], 1)
call s:assert_error('EasyRealign', 'cursor is not inside')
call s:reset(['plain text'], 1)
call s:assert_error('EasyRealignAll', 'contains no EasyAlign regions')
call s:reset(['# :>>:EasyAlign =', 'a=1', '# :<<:EasyAlign'], 2)
setlocal nomodifiable
call s:assert_error('EasyRealign', 'not modifiable')
setlocal modifiable

" View, search state, alternate buffer, and EasyAlign repeat state survive.
call s:reset(s:alias_fixture(), 1)
let @/ = 'preserved-search'
let g:easy_align_last_command = 'preserved-command'
let s:view = winsaveview()
let s:alternate = bufnr('#')
silent EasyRealign
call assert_equal('preserved-search', @/)
call assert_equal('preserved-command', g:easy_align_last_command)
call assert_equal(s:view, winsaveview())
call assert_equal(s:alternate, bufnr('#'))

" Reapplying an already aligned region does not touch the source buffer.
let s:tick = b:changedtick
silent EasyRealign
call assert_equal(s:tick, b:changedtick)

" Missing dependency is reported without edits.
delcommand EasyAlign
let s:missing_input = ['# :>>:EasyAlign =', 'a=1', '# :<<:EasyAlign']
call s:reset(s:missing_input, 2)
call s:assert_error('EasyRealign', ':EasyAlign command is unavailable')
call assert_equal(s:missing_input, getline(1, '$'))

if !empty(v:errors)
  for s:error in v:errors
    echomsg s:error
  endfor
  cquit
endif
qa!
