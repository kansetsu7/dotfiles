" INFO: vimscript cheatsheet
" https://devhints.io/vimscript

call plug#begin()
" ===========================
" Vim Enhancement
" ===========================
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-unimpaired'
Plug 'junegunn/vim-easy-align'
Plug 'scrooloose/nerdtree'
Plug 'Shougo/denite.nvim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tpope/vim-projectionist'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'guns/vim-sexp'
Plug 'tpope/vim-sexp-mappings-for-regular-people'
Plug 'ssh://git@gitlab.abagile.com:7788/abagile/vim-abagile.git'
Plug 'ap/vim-css-color'
" Plug 'Shougo/deoplete.nvim', {'do': ':UpdateRemotePlugins'}
Plug 'jiangmiao/auto-pairs'

" ===========================
" Dev tools
" ===========================
Plug 'w0rp/ale'
Plug 'Yggdroot/indentLine'
Plug 'michaeljsmith/vim-indent-object'
Plug 'thinca/vim-quickrun'
Plug 'bootleq/vim-qrpsqlpq' ", { 'for': 'sql' }
Plug 'tpope/vim-dispatch'
Plug 'AndrewRadev/splitjoin.vim'
Plug 'tpope/vim-abolish'
Plug 'jgdavey/tslime.vim'

" ===========================
" Git
" ===========================
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" ===========================
" Theme
" ===========================
Plug 'dracula/vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" ===========================
" Ruby and Rails
" ===========================
Plug 'tpope/vim-rails' ", {'for': ['ruby', 'haml', 'eruby', 'coffee']}
Plug 'slim-template/vim-slim' ", {'for': ['slim']}
Plug 'vim-ruby/vim-ruby' ", {'for': ['ruby', 'haml', 'eruby']}

" ===========================
" Clojure
" ===========================
Plug 'tpope/vim-fireplace'
Plug 'Olical/conjure', { 'for': 'clojure' }
Plug 'eraserhd/parinfer-rust', {'do': 'cargo build --release', 'for': 'clojure' }
Plug 'clojure-vim/vim-jack-in', { 'for': 'clojure' }
call plug#end()

" General {{{
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
set undofile
set scrolloff=1
set sidescrolloff=5
set encoding=utf8
set splitright

autocmd BufRead,BufNewFile *.thor set filetype=ruby
autocmd FileType markdown setlocal wrap
autocmd FileType eruby.yaml setlocal commentstring=#\ %s
autocmd BufWritePre * call StripTrailingWhitespace() " trim trailing space on save
" }}}

" Theme {{{
color dracula

hi clear Search
hi Search  cterm=underline
hi CursorLine ctermbg=234
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#buffer_nr_show=1

"}}}

" Plugin {{{
let g:gitgutter_enabled=1
let g:indentLine_enabled=1
let g:NERDTreeQuitOnOpen=1
let g:NERDTreeShowHidden=1
set wildignore+=*/.git/*,*/node_modules/*
" let g:deoplete#enable_at_startup = 1
set completeopt-=preview " Disable documentation window
let g:rainbow#blacklist = [117]

let g:ale_linters = {'clojure': ['clj-kondo']}
let g:ale_clojure_clj_kondo_options = ''

augroup rainbow_lisp
  autocmd!
  autocmd FileType lisp,clojure,scheme RainbowParentheses
augroup END
autocmd FileType clojure setlocal commentstring=;;%s
autocmd FileType clojure setlocal formatoptions+=r
let g:sexp_enable_insert_mode_mappings = 0

" conjure settings
hi NormalFloat ctermbg=232 " https://github.com/Olical/conjure/wiki/Frequently-asked-questions#the-hud-window-background-colour-makes-the-text-unreadable-how-can-i-change-it
let g:conjure#log#hud#width=1.0
let g:conjure_map_prefix=","
let g:conjure_log_direction="horizontal"
let g:conjure_log_size_small=15

" tslime
let g:tslime_always_current_window = 1
vmap <C-c><C-c> <Plug>SendSelectionToTmux
nmap <C-c><C-c> <Plug>NormalModeSendToTmux
nmap <C-c>r <Plug>SetTmuxVars
"}}}

" Remap {{{
let mapleader=","
let maplocalleader=" "
nnoremap ' `
nnoremap ` '
nnoremap 0 ^
nnoremap ^ 0
" Don't copy the contents of an overwritten selection.
vnoremap p "_dP
"}}}

" Shortcut {{{
inoremap ,, <esc>
vnoremap ,, <esc>
inoremap ,jj ,<esc>
nnoremap <Tab> :bnext!<CR>
nnoremap <S-Tab> :bprev!<CR>
nnoremap <leader>w <c-w>
noremap <c-h> <c-w>h
noremap <c-j> <c-w>j
noremap <c-k> <c-w>k
noremap <c-l> <c-w>l
inoremap <C-h> <Left>
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-l> <Right>
cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>
noremap <leader>n :noh<CR>

nnoremap <leader>f :NERDTreeFind<CR>
nnoremap <leader>d :bd<CR>
nnoremap :bd! :bdelete!<CR>
nnoremap :cl :close<CR>
nnoremap :et :e tmp/tools/tester.rb<CR>
nnoremap :ets :e tmp/tools/sql/test.sql<CR>

nnoremap <leader>s :%s/
vnoremap <leader>s "hy:%s/<C-r>h
vnoremap <leader>/ "hy/<C-r>h<CR>
nnoremap <leader>/ "hye/<C-r>h<CR>
noremap <silent><leader>V :so $MYVIMRC<CR>:echo 'reloaded!'<CR>

" use system clipboard
vnoremap <Leader>y "+y
nnoremap <Leader>P "+p
nnoremap <Leader>y "+y

" Ref: https://vim.fandom.com/wiki/Making_a_list_of_numbers
" Add argument (can be negative, default 1) to global variable i.
" Return value of i before the change.
function Inc(...)
  let result = g:i
  let g:i += a:0 > 0 ? a:1 : 1
  return result
endfunction

vnoremap <leader>ic "hy :let i = 1 \| %s/<C-r>h/\='<C-r>h' . Inc()/g<CR>

nnoremap <leader>g  :GitGutterToggle<CR>
nnoremap <leader>ew :e <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>es :sp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>ev :vsp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>et :tabe <C-R>=expand('%:h').'/'<cr>
autocmd FileType ruby nnoremap <leader>p obinding.pry<Esc>
autocmd FileType clojure nnoremap <leader>p o(prn<Esc>
autocmd BufEnter,BufNew,BufRead *.cljs nnoremap <leader>p o(js/console.log <Esc>
nnoremap <localleader>cs :call abagile#cljs#setup_cljs_plugin_connection()<CR>
nnoremap <localleader>wc :call abagile#cljs#write_core()<CR>

nmap <leader>gb :Git blame<cr>

map <Down> gj
map <Up>   gk

vmap <Enter> <Plug>(EasyAlign)

autocmd FileType clojure set iskeyword-=.
autocmd FileType clojure set iskeyword-=/
autocmd Filetype clojure let b:AutoPairs = {'"':'"'}
"}}}

" fzf search
nnoremap <C-p> :GFiles<CR>
nnoremap <leader>b :Buffers<CR>
let g:fzf_preview_window = []
let g:fzf_layout = {'up':'~90%', 'window': { 'width': 1, 'height': 0.8,'yoffset': 0.0,'xoffset': 0.0, 'border': 'sharp' } }

" Trim whitespace {{{
fun! StripTrailingWhitespace()
    " Don't strip on these filetypes
    if &ft =~ 'markdown\|text'
        return
    endif
    %s/\s\+$//e
endfun
"}}}

" SQL helpers {{{
function! s:init_qrpsqlpq()
  nmap <buffer> <Leader>r [qrpsqlpq]
  nnoremap <silent> <buffer> [qrpsqlpq]j :call qrpsqlpq#run('split')<CR>
  nnoremap <silent> <buffer> [qrpsqlpq]l :call qrpsqlpq#run('vsplit')<CR>
  nnoremap <silent> <buffer> [qrpsqlpq]r :call qrpsqlpq#run()<CR>

  if !exists('b:rails_root')
    call RailsDetect()
  endif
  if !exists('b:rails_root')
    let b:qrpsqlpq_db_name = 'postgres'
  endif
endfunction

if executable('psql')
  let g:qrpsqlpq_expanded_format_max_lines = -1
  autocmd FileType sql call s:init_qrpsqlpq()
endif
"}}}


" Bulk change SQL keywords to upper case {{{
nnoremap <silent> <leader>sql :call BulkUpperCaseSqlKeywords()<CR>
fun! BulkUpperCaseSqlKeywords()
    " Don't strip on these filetypes
    if &ft =~ 'sql'
      %s/select /SELECT /g
      %s/ as / AS /g
      %s/from /FROM /g
      %s/ on / ON /g
      %s/left join /LEFT JOIN /g
      %s/right join / RIGHT JOIN /g
      %s/union all /UNION ALL /g
      %s/union /UNION /g
      %s/join /JOIN /g
      %s/full /FULL /g
      %s/outer /OUTER /g
      %s/where /WHERE /g
      %s/and /AND /g
      %s/ in / IN /g
      %s/group by /GROUP BY /g
      %s/order by /ORDER BY /g
      %s/is null/IS NULL/g
      %s/is not null/IS NOT NULL/g
      %s/ not / NOT /g
      %s/case /CASE /g
      %s/case(/CASE(/g
      %s/when /WHEN /g
      %s/then /THEN /g
      %s/else /ELSE /g
      %s/end as /END AS /g
      %s/end)/END) /g
      %s/coalesce(/COALESCE(/g
      %s/ asc/ ASC/g
      %s/ desc/ DESC/g
      %s/ distinct on / DISTINCT ON /g
      %s/ distinct(/ DISTINCT(/g
      %s/distinct /DISTINCT /g
      %s/with /WITH /g
      %s/max(/MAX(/g
      %s/sum(/SUM(/g
      %s/count(/COUNT(/g
      %s/having /HAVING /g
      %s/returning /RETURNING /g
      %s/update /UPDATE /g
      %s/set /SET /g
    endif
endfun
"}}}

autocmd FileType sql setlocal commentstring=--\ %s
