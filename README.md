# vim-easy-realign

`vim-easy-realign` reapplies saved [vim-easy-align](https://github.com/junegunn/vim-easy-align)
commands to marked regions of the current buffer.

## installation

Load `vim-easy-align` first, then this plugin. For a local checkout:

```vim
Plug 'mevanlc/vim-easy-align'
Plug '~/.vim/plugged/vim-easy-realign'
```

## region markers

Put a complete, non-interactive EasyAlign specification on the opening marker:

```bash
# :>>:EasyAlign */\s\+\|=['"]/alrl*l0r0ig[]
alias l='eza --color=always -lhr --no-user -smod --no-permissions'
alias ll='eza --color=always -lhr --no-user -smod'
alias la='eza --color=always -lhr --no-user -smod -A'
alias lls='eza --color=always -lhr --no-user -ssize -A'
# :<<:EasyAlign
```

Opening markers may use `EasyAlign!`. The recognized standalone line-comment
leaders are `#`, `"`, `//`, `--`, `;`, and `%`; a region must close with the
same leader. Regions must be nonempty, flat, and properly paired. Block-comment
wrappers and multiline specifications are not supported.

## commands and mappings

- `:EasyRealign` realigns the region containing the cursor. The cursor may be
  on either marker or anywhere in the body.
- `:EasyRealignAll` realigns every region in the current buffer.

The plugin defines bindable targets but no default keys:

```vim
nmap <Leader>ar <Plug>(EasyRealign)
nmap <Leader>aR <Plug>(EasyRealignAll)
```

Both commands validate in an isolated copy before editing the real buffer. An
invalid marker or EasyAlign specification therefore leaves the buffer unchanged;
all successful changes from one command form a single undo step.

Region specifications are passed to EasyAlign. Only invoke realignment in files
you trust, because EasyAlign's dictionary option form accepts Vim expressions.

Run `:help easy-realign` for the complete reference.

## license

MIT
