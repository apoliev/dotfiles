set nocompatible
filetype on
filetype plugin indent on
syntax enable

set background=dark
colorscheme jay

set number
set cursorline
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set showmatch
set laststatus=2
set noshowmode
set updatetime=100
set clipboard=unnamedplus
set incsearch
set hlsearch

"-------------vim-plug (plugin manager)--------------
call plug#begin('~/.vim/plugged')
    Plug 'junegunn/vim-plug'
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    Plug 'preservim/nerdtree'
    Plug 'itchyny/lightline.vim'
    Plug 'Dimercel/todo-vim'
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug '907th/vim-auto-save'
    Plug 'terryma/vim-multiple-cursors'
    Plug 'preservim/tagbar'
    Plug 'junegunn/fzf'
    Plug 'junegunn/fzf.vim'
    Plug 'vim-ruby/vim-ruby'
    Plug 'tpope/vim-rails'
    Plug 'tpope/vim-bundler'
    Plug 'slim-template/vim-slim'
    Plug 'prabirshrestha/vim-lsp'
    Plug 'prabirshrestha/asyncomplete.vim'
    Plug 'prabirshrestha/asyncomplete-lsp.vim'
call plug#end()

:autocmd Filetype ruby set softtabstop=2
:autocmd Filetype ruby set sw=2
:autocmd Filetype ruby set ts=2
:autocmd BufNewFile,BufRead *.slim :set filetype=slim

" Maps
nmap <F5> :TODOToggle<CR>
nmap <C-o> :NERDTreeToggle<CR>
nmap <C-p> :Files<CR>
nmap <C-w>f :Rg<CR>

"-------------vim-lsp (LSP support)--------------
" Extensible server list. To add a new LSP, append one dictionary and make
" sure its binary is installed (it is auto-skipped while missing).
let g:lsp_servers = [
    \ {
    \   'name': 'ruby-lsp',
    \   'cmd': ['ruby-lsp'],
    \   'filetypes': ['ruby'],
    \ },
    \ {
    \   'name': 'pyright',
    \   'cmd': ['pyright-langserver', '--stdio'],
    \   'filetypes': ['python'],
    \ },
    \ {
    \   'name': 'typescript-language-server',
    \   'cmd': ['typescript-language-server', '--stdio'],
    \   'filetypes': ['javascript', 'typescript'],
    \ },
    \]

function! s:register_lsp_servers() abort
    for srv in g:lsp_servers
        if executable(srv['cmd'][0])
            call lsp#register_server({
                \ 'name': srv['name'],
                \ 'cmd': srv['cmd'],
                \ 'whitelist': srv['filetypes'],
                \ })
        endif
    endfor
endfunction

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    if exists('b:undo_ftplugin')
        let b:undo_ftplugin .= " | setlocal omnifunc<"
    endif
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> K <plug>(lsp-hover)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
endfunction

augroup lsp_install
    au!
    autocmd User lsp_setup call s:register_lsp_servers()
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

" Completion via asyncomplete-lsp
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_auto_completeopt = 1
set completeopt=menuone,noinsert
imap <c-space> <Plug>(asyncomplete_force_refresh)
