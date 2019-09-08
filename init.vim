call plug#begin()
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-rails' ", {'for': ['ruby', 'haml', 'eruby', 'coffee']}
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-unimpaired'
Plug 'junegunn/vim-easy-align'
Plug 'scrooloose/nerdtree'
Plug 'dracula/vim'
Plug 'Shougo/denite.nvim'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'Shougo/deoplete.nvim', {'do': ':UpdateRemotePlugins'}
Plug 'w0rp/ale'
" Plug 'justinmk/vim-sneak'
Plug 'Yggdroot/indentLine'
Plug 'michaeljsmith/vim-indent-object'
Plug 'airblade/vim-gitgutter'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'christoomey/vim-tmux-navigator'
Plug 'slim-template/vim-slim' ", {'for': ['slim']}
Plug 'vim-ruby/vim-ruby' ", {'for': ['ruby', 'haml', 'eruby']}
Plug 'janko-m/vim-test'
Plug 'kassio/neoterm'
Plug 'tpope/vim-salve'
Plug 'tpope/vim-projectionist'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-fireplace'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'eraserhd/parinfer-rust', {'do': 'cargo build --release'}
Plug 'guns/vim-sexp'
Plug 'tpope/vim-sexp-mappings-for-regular-people'
call plug#end()

color dracula

set hidden
set hlsearch
set nowrap
set cursorline
set cursorcolumn
set nostartofline
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set ignorecase
set smartcase
set relativenumber
set regexpengine=1
set noswapfile

set scrolloff=1
set sidescrolloff=5

autocmd BufRead,BufNewFile *.thor set filetype=ruby

autocmd FileType markdown setlocal wrap
autocmd FileType eruby.yaml setlocal commentstring=#\ %s

" let g:python_host_prog = '/usr/bin/python'
" let g:python3_host_prog = '/usr/bin/python3'
let g:gitgutter_enabled=1
let g:indentLine_enabled=1
let g:NERDTreeQuitOnOpen=1
let g:ctrlp_cmd='CtrlPMixed'
let g:ctrlp_match_window='order:ttb,max:20'
set wildignore+=*/.git/*,*/node_modules/*
let g:deoplete#enable_at_startup=1
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#buffer_nr_show=1
let test#strategy='dispatch'
let g:dispatch_quickfix_height=20
" let g:neoterm_default_mod='belowright'
" let g:neoterm_keep_term_open=0
" let g:neoterm_autoscroll=1

augroup rainbow_lisp
  autocmd!
  autocmd FileType lisp,clojure,scheme RainbowParentheses
augroup END
autocmd FileType clojure setlocal commentstring=;;%s
autocmd FileType clojure setlocal formatoptions+=r
let g:sexp_enable_insert_mode_mappings = 0

" let g:sneak#s_next=1
" nmap f <Plug>Sneak_f
" nmap F <Plug>Sneak_F
" xmap f <Plug>Sneak_f
" xmap F <Plug>Sneak_F
" omap f <Plug>Sneak_f
" omap F <Plug>Sneak_F
" nmap t <Plug>Sneak_t
" nmap T <Plug>Sneak_T
" xmap t <Plug>Sneak_t
" xmap T <Plug>Sneak_T
" omap t <Plug>Sneak_t
" omap T <Plug>Sneak_T

let mapleader=","

nnoremap ' `
nnoremap ` '
inoremap jj <esc>
inoremap jk <esc>
inoremap ,, <esc>
nnoremap <Tab> :bnext!<CR>
nnoremap <S-Tab> :bprev!<CR>
nnoremap <leader>w <c-w>
noremap <c-h> <c-w>h
noremap <c-j> <c-w>j
noremap <c-k> <c-w>k
noremap <c-l> <c-w>l

nnoremap <leader>f :NERDTreeFind<CR>
nnoremap <leader>d :NERDTreeToggle<CR>

nnoremap <leader>b :CtrlPBuffer<CR>

" nnoremap <leader>s  :set nolist! nolist?<CR>
" nnoremap <leader>n  :set number! number?<CR>
nnoremap <leader>g  :GitGutterToggle<CR>
" nnoremap <Leader>hl :set hlsearch! hlsearch?<CR>
" nnoremap <leader>iw :set invwrap wrap?<CR>
nnoremap <leader>ew :e <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>es :sp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>ev :vsp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>et :tabe <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>p obinding.pry<Esc>
nmap 0 ^

map <Down> gj
map <Up>   gk

vmap <Enter> <Plug>(EasyAlign)

nnoremap <silent> <Leader>tn :TestNearest<CR>
nnoremap <silent> <Leader>tf :TestFile<CR>
nnoremap <silent> <Leader>ts :TestSuite<CR>
nnoremap <silent> <Leader>tl :TestLast<CR>
nnoremap <silent> <Leader>tv :TestVisit<CR>
