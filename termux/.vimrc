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

"-------------Vundle (plugin manager)--------------
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
    Plugin 'VundleVim/Vundle.vim'
    Plugin 'tpope/vim-fugitive'
    Plugin 'https://github.com/airblade/vim-gitgutter.git'
    Plugin 'scrooloose/syntastic'
    Plugin 'scrooloose/nerdtree'
    Plugin 'itchyny/lightline.vim'
    Plugin 'Dimercel/todo-vim'
    Plugin 'Xuyuanp/nerdtree-git-plugin'
    Plugin 'vim-scripts/vim-auto-save.git'
    Plugin 'terryma/vim-multiple-cursors'
    Plugin 'majutsushi/tagbar'
    Plugin 'junegunn/fzf'
    Plugin 'junegunn/fzf.vim'
    Plugin 'w0rp/ale'
    Plugin 'vim-ruby/vim-ruby'
    Plugin 'tpope/vim-rails'
    Plugin 'tpope/vim-bundler'
    Plugin 'slim-template/vim-slim'
    Plugin 'autozimu/LanguageClient-neovim', {
    \   'branch': 'next',
    \   'do': 'bash install.sh',
    \ }
call vundle#end()
:autocmd Filetype ruby set softtabstop=2
:autocmd Filetype ruby set sw=2
:autocmd Filetype ruby set ts=2
:autocmd BufNewFile,BufRead *.slim :set filetype=slim

" Maps
nmap <F5> :TODOToggle<CR>
nmap <C-o> :NERDTreeToggle<CR>
nmap <C-p> :Files<CR>
nmap <C-w>f :Rg<CR>
nnoremap <silent> K :call LanguageClient#textDocument_hover()<CR>
nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>

" ALE settings
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier', 'eslint'],
\   'ruby': ['rubocop']
\}

let g:ale_linters = {
\   'ruby': ['rubocop']
\}

let g:ale_linters_explicit = 1
let g:ale_completion_enabled = 1
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
let g:ale_set_balloons=1
let g:ale_hover_to_floating_preview=1
let g:ale_sign_column_always = 1
let g:ale_disable_lsp = 1

" LanguageClient settings
let g:LanguageClient_serverCommands = {
\   'ruby': ['$(which ruby-lsp)', 'stdio'],
\ }
