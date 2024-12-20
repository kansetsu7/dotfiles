-- ==================
--      Autocmd
-- ==================
vim.cmd([[
  augroup _general_settings
    autocmd!
    autocmd FileType markdown setlocal wrap
    autocmd FileType qf,help,man,lspinfo nnoremap <silent> <buffer> q :close<CR>
    autocmd TextYankPost * silent!lua require('vim.highlight').on_yank({higroup = 'Visual', timeout = 200})
    "autocmd BufWinEnter * :set formatoptions-=cro
    autocmd FileType qf set nobuflisted
    autocmd BufNewFile,BufRead *.slim setlocal filetype=slim
    autocmd BufNewFile,BufRead *.thor,.pryrc,pryrc setlocal filetype=ruby
    autocmd BufNewFile,BufRead ssh_config,*/.ssh/config.d/*  setf sshconfig
    autocmd InsertLeave * set nopaste
    autocmd User Rails silent! Rnavcommand job app/jobs -glob=**/* -suffix=_job.rb
    autocmd! CursorHold,CursorHoldI * lua vim.diagnostic.open_float(nil, {focus=false, scope="cursor"})
  augroup end
  augroup _git
    autocmd!
    autocmd FileType gitcommit setlocal wrap
    autocmd FileType gitcommit setlocal spell textwidth=72
    autocmd Filetype gitcommit nmap <buffer> <leader>p oSee merge request metis/nerv!
  augroup end
  augroup _yml
    autocmd!
    autocmd FileType eruby.yaml set filetype=yaml
    autocmd BufRead,BufNewFile *.fdoc set filetype=yaml
    " autocmd BufRead,BufNewFile *.yml setlocal spell
  augroup end
  augroup _auto_resize
    " automatically rebalance windows on vim resize
    autocmd!
    autocmd VimResized * tabdo wincmd =
  augroup end
  augroup _clojure
    autocmd!
  " autocmd FileType clojure setlocal iskeyword+=?,*,!,+,/,=,<,>,$
    autocmd FileType clojure setlocal iskeyword-=.
    autocmd FileType clojure setlocal iskeyword-=/
    autocmd FileType clojure nmap <buffer> <leader>p i(debux.core/dbg<Space>
    autocmd BufEnter,BufNew,BufRead *.cljs nnoremap <leader>p o(js/console.log <Esc>
    autocmd FileType clojure setlocal commentstring=;;%s
    autocmd FileType clojure setlocal formatoptions+=r
  augroup end
  augroup _lisp_filetype
    autocmd!
    autocmd FileType clojure,fennel setlocal iskeyword-=.
    autocmd FileType clojure,fennel setlocal iskeyword-=/
    autocmd FileType clojure,fennel setlocal formatoptions+=or
    autocmd FileType clojure,fennel setlocal lispwords+=are,comment,cond,do,try
    autocmd Filetype clojure let b:AutoPairs = {'"':'"'}
  augroup end
  augroup _qrpsqlpq
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
  augroup end
  augroup _sql
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
  augroup end
]])
