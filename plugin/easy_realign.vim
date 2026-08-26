if exists('g:loaded_easy_realign_plugin')
  finish
endif
let g:loaded_easy_realign_plugin = 1

command! -bar EasyRealign call easy_realign#realign_current()
command! -bar EasyRealignAll call easy_realign#realign_all()

nnoremap <silent> <Plug>(EasyRealign) :<C-U>EasyRealign<CR>
nnoremap <silent> <Plug>(EasyRealignAll) :<C-U>EasyRealignAll<CR>

" vim: set et sw=2 :
