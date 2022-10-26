local km_opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap

require("user.plugin")
require("user.cmp")
require("user.lsp")

-- General {{{
local options = {
  hidden         = true,
  hlsearch       = true,
  wrap           = false,
  cursorline     = true,
  cursorcolumn   = true,
  startofline    = false,
  expandtab      = true,
  ignorecase     = true,
  smartcase      = true,
  relativenumber = true,
  swapfile       = false,
  undofile       = true,
  splitright     = true,
  tabstop        = 2,
  softtabstop    = 2,
  shiftwidth     = 2,
  regexpengine   = 1,
  scrolloff      = 1,
  sidescrolloff  = 5,
  encoding       = "utf8",
  mouse          = "",
  updatetime     = 750,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- TODO: find lua command for autocmd
vim.cmd "autocmd BufRead,BufNewFile *.thor set filetype=ruby"
vim.cmd "autocmd FileType markdown setlocal wrap"
vim.cmd "autocmd FileType eruby.yaml setlocal commentstring=#\\ %s"
vim.cmd "autocmd BufWritePre * call StripTrailingWhitespace()" -- trim trailing space on save
-- }}}

-- Theme {{{
vim.cmd "colorscheme dracula"
vim.cmd "hi clear Search"
vim.cmd "hi Search  cterm=underline"
vim.cmd "hi CursorLine ctermbg=234"
vim.g.airline_powerline_fonts = 1
vim.g['airline#extensions#tabline#enabled'] = 1
vim.g['airline#extensions#tabline#buffer_nr_show'] = 1

-- }}}

-- Remap {{{
vim.g.mapleader=","
vim.g.maplocalleader=" "
keymap('n', "'", "`", km_opts)
keymap('n', "`", "'", km_opts)
keymap('n', "^", "0", km_opts)
keymap('n', "0", "^", km_opts)
keymap("v", "p", "\"_dP", km_opts) -- Don't copy the contents of an overwritten selection.
-- }}}

-- Plugin {{{
-- nvim-tree
vim.g.loaded = 1
vim.g.loaded_netrwPlugin = 1
require("nvim-tree").setup{
  update_focused_file = {
    enable      = true,
    update_root = true
  },
  actions = {
    open_file = {
      quit_on_open = true
    }
  },
  renderer = {
    icons = {
      show = {
        file   = false,
        folder = false,
        git    = false,
      }
    }
  }
}

vim.g.gitgutter_enabled=1
vim.g.indentLine_enabled=1
vim.opt.wildignore = vim.opt.wildignore + "*/.git/*,*/node_modules/*"
vim.opt.completeopt = vim.opt.completeopt - 'preview' -- Disable documentation window
vim.g['rainbow#blacklist'] = { 117 }

-- vim.g.ale_linters = {
--   clojure = { 'clj-kondo' }
-- }
-- vim.g.ale_clojure_clj_kondo_options = ''

vim.cmd [[
  augroup rainbow_lisp
    autocmd!
    autocmd FileType lisp,clojure,scheme RainbowParentheses
  augroup END
]]
vim.cmd "autocmd FileType clojure setlocal commentstring=;;%s"
vim.cmd "autocmd FileType clojure setlocal formatoptions+=r"

vim.g.sexp_filetypes                   = "clojure,scheme,lisp,fennel,janet"
vim.g.sexp_enable_insert_mode_mappings = 0
vim.g.sexp_mappings = {
  sexp_round_head_wrap_element = "<localleader>e(",
  sexp_round_tail_wrap_element = "<localleader>e)",
  sexp_insert_at_list_head = "<localleader>eh",
  sexp_insert_at_list_tail = "<localleader>el",
}

-- lsp
vim.cmd "autocmd CursorHold * lua require('echo-diagnostics').echo_line_diagnostic()"

-- conjure settings
vim.cmd "hi NormalFloat ctermbg=232" -- https://github.com/Olical/conjure/wiki/Frequently-asked-questions#the-hud-window-background-colour-makes-the-text-unreadable-how-can-i-change-it
vim.g['conjure#log#hud#width']=1.0
vim.g.conjure_map_prefix=","
vim.g.conjure_log_direction="horizontal"
vim.g.conjure_log_size_small=15

vim.g.clojure_align_subforms = 1
vim.g["conjure#client#clojure#nrepl#connection#auto_repl#enabled"] = false
vim.g["conjure#mapping#log_reset_soft"] = "lc"
vim.g["conjure#mapping#log_reset_hard"] = "lC"

-- fzf search
keymap('n', "<C-p>", ":GFiles<CR>", km_opts)
keymap('n', "<leader>b", ":Buffers<CR>", km_opts)
vim.g.fzf_preview_window = {}
vim.g.fzf_layout = {
	up = '~90%',
	window = {
		width   =  1,
		height  =  0.8,
		yoffset =  0.0,
		xoffset =  0.0,
		border  =  'sharp'
	}
}

-- }}}

-- Shortcut {{{
keymap('i', ",,", "<esc>", km_opts)
keymap('v', ",,", "<esc>", km_opts)
keymap('i', ",jj", ",<esc>", km_opts)
keymap('n', "<Tab>", ":bnext!<CR>", km_opts)
keymap('n', "<S-Tab>", ":bprev!<CR>", km_opts)
keymap('n', "<leader>w", "<c-w>", km_opts)
keymap("n", "<C-h>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateLeft()<CR>", km_opts)
keymap("n", "<C-j>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateDown()<CR>", km_opts)
keymap("n", "<C-k>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateUp()<CR>", km_opts)
keymap("n", "<C-l>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateRight()<CR>", km_opts)
keymap("n", "<C-\\>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateLastActive()<CR>", km_opts)
keymap('i', "<C-h>", "<Left>",  km_opts)
keymap('i', "<C-j>", "<Down>",  km_opts)
keymap('i', "<C-k>", "<Up>",    km_opts)
keymap('i', "<C-l>", "<Right>", km_opts)
keymap('c', "<C-h>", "<Left>",  km_opts)
keymap('c', "<C-j>", "<Down>",  km_opts)
keymap('c', "<C-k>", "<Up>",    km_opts)
keymap('c', "<C-l>", "<Right>", km_opts)
keymap('', "<leader>n", ":noh<CR>", km_opts)

keymap('n', "<leader>f", ":NvimTreeToggle<CR>", km_opts)
keymap('n', "<leader>d", ":bd<CR>", km_opts)
keymap('n', ":bd!", ":bdelete!<CR>", km_opts)
keymap('n', ":cl", ":close<CR>", km_opts)
keymap('n', ":et", ":e tmp/tools/tester.rb<CR>", km_opts)
keymap('n', ":ets", ":e tmp/tools/sql/test.sql<CR>", km_opts)

keymap('v', "<leader>s", "\"hy:%s/<C-r>h", km_opts)
keymap('v', "<leader>/", "\"hy/<C-r>h<CR>", km_opts)
keymap('n', "<leader>/", "\"hye/<C-r>h<CR>", km_opts)
-- noremap <silent><leader>V :so $MYVIMRC<CR>:echo 'reloaded!'<CR>

-- use system clipboard
keymap('v', "<Leader>y", "\"+y", km_opts)
keymap('n', "<Leader>P", "\"+p", km_opts)
keymap('n', "<Leader>y", "\"+y", km_opts)

keymap('n', "<localleader>cs", ":call abagile#cljs#setup_cljs_plugin_connection()<CR>", km_opts)
keymap('n', "<localleader>wc", ":call abagile#cljs#write_core()<CR>", km_opts)
-- <leader>g  :GitGutterToggle<CR>
-- <leader>ew :e <C-R>=expand('%:h').'/'<cr>
-- <leader>es :sp <C-R>=expand('%:h').'/'<cr>
-- <leader>ev :vsp <C-R>=expand('%:h').'/'<cr>
-- <leader>et :tabe <C-R>=expand('%:h').'/'<cr>
vim.cmd "autocmd FileType ruby nnoremap <leader>p obinding.pry<Esc>"
vim.cmd "autocmd FileType clojure nnoremap <leader>p o(prn<Esc>"
vim.cmd "autocmd BufEnter,BufNew,BufRead *.cljs nnoremap <leader>p o(js/console.log <Esc>"

keymap('n', "<leader>gb", ":Git blame<cr>", {})
keymap('', "<Down>", "gj", {})
keymap('', "<Up>", "gk", {})

keymap('v', "<Enter>", "<Plug>(EasyAlign)", {})

vim.cmd [[
  augroup lisp_filetype
    autocmd!
    autocmd FileType clojure,fennel setlocal iskeyword-=.
    autocmd FileType clojure,fennel setlocal iskeyword-=/
    autocmd FileType clojure,fennel setlocal formatoptions+=or
    autocmd FileType clojure,fennel setlocal lispwords+=are,comment,cond,do,try
    autocmd Filetype clojure let b:AutoPairs = {'"':'"'}
  augroup end
]]
-- }}}

-- Trim whitespace {{{
-- NOTE: &ft -> vim.bo.filetype
vim.cmd [[
   fun! StripTrailingWhitespace()
       " Don't strip on these filetypes
       if &ft =~ 'markdown\|text'
           return
       endif
       %s/\s\+$//e
   endfun
]]
-- }}}

-- SQL helpers {{{
vim.cmd [[
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
]]
-- }}}


-- Bulk change SQL keywords to upper case {{{
keymap('n', "<silent><leader>sql", ":call BulkUpperCaseSqlKeywords()<CR>", km_opts)
vim.cmd [[
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
]]
-- }}}

vim.cmd "autocmd FileType sql setlocal commentstring=--\\ %s"
