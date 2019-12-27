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
Plug 'ctrlpvim/ctrlp.vim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'kassio/neoterm'
Plug 'tpope/vim-projectionist'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'guns/vim-sexp'
Plug 'tpope/vim-sexp-mappings-for-regular-people'
" temp disable because it's for nvim 0.3+
" Plug 'Shougo/deoplete.nvim', {'do': ':UpdateRemotePlugins'}

" ===========================
" Dev tools
" ===========================
Plug 'w0rp/ale'
Plug 'Yggdroot/indentLine'
Plug 'michaeljsmith/vim-indent-object'
Plug 'thinca/vim-quickrun'
Plug 'bootleq/vim-qrpsqlpq'
" Plug 'janko-m/vim-test'
Plug 'tpope/vim-dispatch'

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
" JS
" ===========================
Plug 'mxw/vim-jsx'
Plug 'moll/vim-node'
Plug 'mattn/emmet-vim'
Plug 'tpope/vim-abolish'

" ===========================
" Clojure
" ===========================
Plug 'tpope/vim-salve'
Plug 'tpope/vim-fireplace'
Plug 'eraserhd/parinfer-rust', {'do': 'cargo build --release'}
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
set scrolloff=1
set sidescrolloff=5

autocmd BufRead,BufNewFile *.thor set filetype=ruby
autocmd FileType markdown setlocal wrap
autocmd FileType eruby.yaml setlocal commentstring=#\ %s
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
" let g:python_host_prog = '/usr/bin/python'
" let g:python3_host_prog = '/usr/bin/python3'
let g:gitgutter_enabled=1
let g:indentLine_enabled=1
let g:NERDTreeQuitOnOpen=1
let g:NERDTreeShowHidden=1
let g:ctrlp_cmd='CtrlPMixed'
let g:ctrlp_match_window='order:ttb,max:20'
set wildignore+=*/.git/*,*/node_modules/*
let g:deoplete#enable_at_startup=1
" let test#strategy='neovim'
" let g:test#preserve_screen = 1
" let test#neovim#term_position = 'vert'
" let g:dispatch_quickfix_height=20
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
"}}}

" Remap {{{
let mapleader=","
nnoremap ' `
nnoremap ` '
nmap 0 ^
" Don't copy the contents of an overwritten selection.
vnoremap p "_dP 
"}}}

" Shortcut {{{
inoremap ,, <esc>
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
nnoremap <leader>d :NERDTreeToggle<CR>

nnoremap <leader>b :CtrlPBuffer<CR>
noremap <silent><leader>V :so $MYVIMRC<CR>:echo 'reloaded!'<CR>

nnoremap <leader>g  :GitGutterToggle<CR>
nnoremap <leader>ew :e <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>es :sp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>ev :vsp <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>et :tabe <C-R>=expand('%:h').'/'<cr>
nnoremap <leader>p obinding.pry<Esc>
nmap <leader>gb :Gblame<cr>

map <Down> gj
map <Up>   gk

vmap <Enter> <Plug>(EasyAlign)
" nnoremap <leader>s  :set nolist! nolist?<CR>
" nnoremap <leader>n  :set number! number?<CR>
" nnoremap <Leader>hl :set hlsearch! hlsearch?<CR>
" nnoremap <leader>iw :set invwrap wrap?<CR>

" nnoremap <silent> <Leader>tn :TestNearest<CR>
" nnoremap <silent> <Leader>tf :TestFile<CR>
" nnoremap <silent> <Leader>ts :TestSuite<CR>
" nnoremap <silent> <Leader>tl :TestLast<CR>
" nnoremap <silent> <Leader>tv :TestVisit<CR>
" if has('nvim')
"   tmap <C-o> <C-\><C-n>
" endif
"}}}

"Tmux {{{
function! TmuxNewWindow(...)
  let options = a:0 ? a:1 : {}
  let text = get(options, 'text', '')
  let title = get(options, 'title', '')
  let directory = get(options, 'directory', getcwd())
  let method = get(options, 'method', 'new-window')
  let size = get(options, 'size', '40')
  let remember_pane = get(options, 'remember_pane', 0)
  let pane = ''

  if method == 'file'
    let method = 'h'
  end

  if method == 'last'
    if !exists('s:last_tmux_pane') || empty(s:last_tmux_pane)
      echohl WarningMsg | echomsg "Can't find last tmux pane. Continue with 'horizontal-split'." | echohl None
      let method = 'h'
    else
      let pane = s:last_tmux_pane
    endif
  elseif method == 'quit'
    if !exists('s:last_tmux_pane') || empty(s:last_tmux_pane)
      echohl WarningMsg | echomsg "Can't find last used pane." | echohl None
      return
    else
      call system('tmux kill-pane -t ' . matchstr(s:last_tmux_pane, '%\d\+'))
      unlet! s:last_tmux_pane
      return
    endif
  endif

  if empty(pane) && method != 'new-window'
    " use splitted pane if available
    let pane = matchstr(
          \   system('tmux list-pane -F "#{window_id}#{pane_id}:#{pane_active}" | egrep 0$'),
          \   '\zs@\d\+%\d\+\ze'
          \ )
  endif

  if empty(pane)
    if method == 'new-window'
      let cmd = 'tmux new-window -a '
            \ . (empty(title) ? '' : printf('-n %s', shellescape(title)))
            \ . printf(' -c %s', shellescape(directory))
    elseif method == 'v'
      let cmd = 'tmux split-window -d -v '
            \ . printf('-p %s -c %s ', size, shellescape(directory))
    elseif method == 'h'
      let cmd = 'tmux split-window -d -h '
            \ . printf(' -c %s ', shellescape(directory))
    endif

    let pane = substitute(
          \   system(cmd . ' -P -F "#{window_id}#{pane_id}"'), '\n$', '', ''
          \ )
  endif

  if remember_pane
    let s:last_tmux_pane = pane
  endif

  let window_id = matchstr(pane, '@\d\+')
  let pane_id = matchstr(pane, '%\d\+')

  if !empty(text)
    let cmd = printf(
          \   'tmux set-buffer %s \; paste-buffer -t %s -d \; send-keys -t %s Enter',
          \   shellescape(text),
          \   pane_id,
          \   pane_id
          \ )
    sleep 300m
    call system('tmux select-window -t ' . window_id)
    call system(cmd)
  endif
endfunction
"}}}

" Rails {{{
function! s:rails_test_helpers()
  let type = rails#buffer().type_name()
  let relative = rails#buffer().relative()
  if type =~ '^test' || (type == 'javascript-coffee' && relative =~ '^test/')
    nmap <Leader>t [rtest]
    nnoremap <silent> [rtest]j :call <SID>rails_test_tmux('v')<CR>
    nnoremap <silent> [rtest]l :call <SID>rails_test_tmux('h')<CR>
    nnoremap <silent> [rtest]w :call <SID>rails_test_tmux('new-window')<CR>
    nnoremap <silent> [rtest]. :call <SID>rails_test_tmux('last')<CR>
    nnoremap <silent> [rtest]t :call <SID>rails_test_tmux('last')<CR>
    nnoremap <silent> [rtest]q :call <SID>rails_test_tmux('quit')<CR>
    nnoremap <silent> [rtest]f :call <SID>rails_test_tmux('file')<CR>
  end
endfunction

function! s:rails_test_tmux(method)
  let [it, path] = ['', '']

  let rails_type = rails#buffer().type_name()
  let rails_relative = rails#buffer().relative()

  if rails_type =~ '^test'
    let it = matchstr(
          \   getline(
          \     search('^\s*it\s\+\(\)', 'bcnW')
          \   ),
          \   'it\s*[''"]\zs.*\ze[''"]'
          \ )
    let path = rails_relative
  elseif rails_type == 'javascript-coffee' && rails_relative =~ '^test/'
    " Currently, teaspoon can't filter specs without 'describe' title
    " https://github.com/modeset/teaspoon/issues/304
    let desc = matchstr(
          \   getline(
          \     search('^\s*describe\s*\(\)', 'bcnW')
          \   ),
          \   'describe\s*[''"]\zs.*\ze[''"]'
          \ )
    let it = matchstr(
          \   getline(
          \     search('^\s*it\s\+\(\)', 'bcnW')
          \   ),
          \   'it\s*[''"]\zs.*\ze[''"]'
          \ )
    let it = (empty(desc) || empty(it)) ?
          \ '' :
          \ join([desc, it], ' ')
    let path = rails_relative
  end

  if empty(it) || empty(path)
    let it   = get(s:, 'rails_test_tmux_last_it', '')
    let path = get(s:, 'rails_test_tmux_last_path', '')
  end

  if empty(it) || empty(path)
    echohl WarningMsg | echomsg 'No `it` block found' | echohl None
    return
  end

  let s:rails_test_tmux_last_it = it
  let s:rails_test_tmux_last_path = path

  if rails_type == 'javascript-coffee'
    " https://github.com/modeset/teaspoon/wiki/Teaspoon-Configuration
    " TODO add back `--filter` if I can handle nested `describe` blocks
    " let test_command = printf('RAILS_RELATIVE_URL_ROOT= teaspoon %s --fail-fast -f pride --filter %s', path, shellescape(it))
    let test_command = printf('FAIL_FAST=true FORMATTERS=documentation rake teaspoon files=%s', path)
    let title = '☕️'
  " elseif rails_type == 'test-integration'
  "   " TODO why can't just use ruby -Itest?
  "   let test_command = printf('RAILS_RELATIVE_URL_ROOT= bundle exec rake test:integration TEST=%s', path)
  "   let title = matchstr(rails_type, '\vtest-\zs.{4}')
  else
    if a:method == 'file'
      let test_command = printf('be ruby -Itest %s', path)
    else
      let test_command = printf('be ruby -Itest %s --name /%s/', path, shellescape(escape(it, '()')))
    end

    let type_short = matchstr(rails_type, '\vtest-\zs.{4}')
    if type_short == 'unit'
      let title = type_short
    elseif type_short == 'func'
      let title = type_short
    else
      let title = type_short
    endif
  endif

  call TmuxNewWindow({
        \   "text": test_command,
        \   "title": '∫ ' . title,
        \   "remember_pane": 1,
        \   "method": a:method
        \ })
        " unable to access rails#app().root, so remove it
        " can use getcwd() as alternative
        " \   "directory": rails#app().root,
endfunction

autocmd User Rails call s:rails_test_helpers()
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
