let s:leader = '\%(#\|"\|//\|--\|;\|%\)'
let s:start = '^\s*\(' . s:leader . '\)\s*:>>:EasyAlign\(!\?\)\s\+\(.\{-}\S\)\s*$'
let s:close = '^\s*\(' . s:leader . '\)\s*:<<:EasyAlign\s*$'
let s:startish = '^\s*' . s:leader . '\s*:>>:EasyAlign'
let s:closeish = '^\s*' . s:leader . '\s*:<<:EasyAlign'

" EasyAlign enters interactive mode when options are supplied without a target.
" Recognize its compact option grammar so a region command can never block on
" getchar() while being validated in the scratch buffer.
let s:option = '\%('
      \ . '\%(lm\?\|rm\?\)[0-9]\+'
      \ . '\|iu[01]'
      \ . '\|\%(s\%(tl\)\?[01]\|[<>]\)'
      \ . '\|da\?[clr]'
      \ . '\|\%(ms\?\|a\)[lrc*]\+'
      \ . '\|i\%(dt\)\?[kdsn]'
      \ . '\|[gv]/.*/'
      \ . '\|ig\[.*\]'
      \ . '\|j[bc]'
      \ . '\|e[01]'
      \ . '\)'
let s:options_only = '^\s*\%(' . s:option . '\)\+\s*$'

function! s:fail(message) abort
  throw 'EasyRealign: ' . a:message
endfunction

function! s:parse_regions() abort
  let regions = []
  let open = {}

  for lnum in range(1, line('$'))
    let text = getline(lnum)
    let start = matchlist(text, s:start)
    let close = matchlist(text, s:close)

    if !empty(start)
      if !empty(open)
        call s:fail(printf('nested start marker at line %d (region opened at line %d)', lnum, open.start))
      endif
      let open = {
            \ 'start': lnum,
            \ 'leader': start[1],
            \ 'bang': start[2] ==# '!',
            \ 'spec': start[3],
            \ }
    elseif text =~# s:startish
      call s:fail(printf('malformed start marker at line %d', lnum))
    elseif !empty(close)
      if empty(open)
        call s:fail(printf('orphan close marker at line %d', lnum))
      endif
      if close[1] !=# open.leader
        call s:fail(printf(
              \ 'comment leader mismatch at line %d: expected %s, found %s',
              \ lnum, string(open.leader), string(close[1])))
      endif
      if lnum == open.start + 1
        call s:fail(printf('empty region opened at line %d', open.start))
      endif
      let open.end = lnum
      let open.first = open.start + 1
      let open.last = lnum - 1
      call add(regions, open)
      let open = {}
    elseif text =~# s:closeish
      call s:fail(printf('malformed close marker at line %d', lnum))
    endif
  endfor

  if !empty(open)
    call s:fail(printf('unclosed region opened at line %d', open.start))
  endif
  return regions
endfunction

function! s:validate_spec(region) abort
  let target = a:region.spec
  let dictionary = match(target, '\s*{.*}\s*$')
  if dictionary >= 0
    let target = strpart(target, 0, dictionary)
  endif
  if empty(substitute(target, '\s', '', 'g')) || target =~# s:options_only
    call s:fail(printf(
          \ 'EasyAlign specification at line %d has options but no delimiter target',
          \ a:region.start))
  endif
endfunction

function! s:find_current(regions) abort
  let cursor_line = line('.')
  for region in a:regions
    if region.start <= cursor_line && cursor_line <= region.end
      return region
    endif
  endfor
  call s:fail('cursor is not inside an EasyAlign region')
endfunction

function! s:set_scratch_options(options) abort
  let &l:tabstop = a:options.tabstop
  let &l:iskeyword = a:options.iskeyword
  let &l:filetype = a:options.filetype
  if !empty(a:options.syntax)
    execute 'setlocal syntax=' . escape(a:options.syntax, ' \\|')
  endif
endfunction

function! s:run_in_scratch(regions) abort
  let source = bufnr('%')
  let source_view = winsaveview()
  let source_lines = getline(1, '$')
  let source_options = {
        \ 'filetype': &l:filetype,
        \ 'syntax': &l:syntax,
        \ 'tabstop': &l:tabstop,
        \ 'iskeyword': &l:iskeyword,
        \ }
  let had_last_command = exists('g:easy_align_last_command')
  if had_last_command
    let saved_last_command = g:easy_align_last_command
  endif
  let scratch = -1

  try
    noautocmd keepalt keepjumps hide enew
    let scratch = bufnr('%')
    setlocal buftype=nofile bufhidden=wipe noswapfile modifiable
    setlocal undolevels=-1
    call setline(1, source_lines)
    call s:set_scratch_options(source_options)

    for region in a:regions
      call s:validate_spec(region)
      unlet! g:easy_align_last_command
      let command = printf('%d,%dEasyAlign%s %s',
            \ region.first, region.last, region.bang ? '!' : '', region.spec)
      silent execute command
      if !exists('g:easy_align_last_command')
        call s:fail(printf('invalid EasyAlign specification at line %d: %s',
              \ region.start, region.spec))
      endif
    endfor

    let result = getline(1, '$')
    if len(result) != len(source_lines)
      call s:fail('EasyAlign unexpectedly changed the buffer line count')
    endif
  finally
    if bufexists(source) && bufnr('%') != source
      execute 'silent noautocmd keepalt keepjumps buffer ' . source
    endif
    if scratch > 0 && bufexists(scratch)
      execute 'silent! noautocmd bwipeout! ' . scratch
    endif
    if had_last_command
      let g:easy_align_last_command = saved_last_command
    else
      unlet! g:easy_align_last_command
    endif
    if bufnr('%') == source
      call winrestview(source_view)
    endif
  endtry

  return result
endfunction

function! s:apply_result(regions, result) abort
  let changed = 0
  for region in a:regions
    let replacement = a:result[region.first - 1 : region.last - 1]
    if getline(region.first, region.last) !=# replacement
      if changed
        silent! undojoin
      endif
      call setline(region.first, replacement)
      let changed += 1
    endif
  endfor
  return changed
endfunction

function! s:realign(all) abort
  if exists(':EasyAlign') != 2
    call s:fail('the :EasyAlign command is unavailable')
  endif
  if !&l:modifiable
    call s:fail('the current buffer is not modifiable')
  endif

  let regions = s:parse_regions()
  if empty(regions)
    call s:fail('the current buffer contains no EasyAlign regions')
  endif
  if !a:all
    let regions = [s:find_current(regions)]
  endif

  let view = winsaveview()
  try
    let result = s:run_in_scratch(regions)
    let changed = s:apply_result(regions, result)
  finally
    call winrestview(view)
  endtry

  if a:all
    echomsg printf('EasyRealign: %d region%s realigned%s',
          \ len(regions), len(regions) == 1 ? '' : 's', changed ? '' : ' (already aligned)')
  else
    echomsg printf('EasyRealign: region at lines %d-%d realigned%s',
          \ regions[0].start, regions[0].end, changed ? '' : ' (already aligned)')
  endif
endfunction

function! easy_realign#realign_current() abort
  let view = winsaveview()
  try
    call s:realign(0)
  catch /^EasyRealign:/
    echoerr v:exception
  finally
    call winrestview(view)
  endtry
endfunction

function! easy_realign#realign_all() abort
  let view = winsaveview()
  try
    call s:realign(1)
  catch /^EasyRealign:/
    echoerr v:exception
  finally
    call winrestview(view)
  endtry
endfunction

" vim: set et sw=2 :
