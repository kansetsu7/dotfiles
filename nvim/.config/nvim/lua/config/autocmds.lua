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
    autocmd! CursorHold,CursorHoldI * lua require('echo-diagnostics').echo_line_diagnostic()
    " trim trailing space on save
    autocmd! BufWritePre * lua StripTrailingWhitespace()
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
]])

vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(event)
    vim.keymap.set("n", "<Leader>p", "obinding.pry<ESC>^", { buffer = event.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "slim",
  callback = function(event)
    vim.keymap.set("n", "<Leader>p", "o- binding.pry<ESC>^", { buffer = event.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "javascript",
  callback = function(event)
    vim.keymap.set("n", "<Leader>p", "oconsole.log()<ESC>^", { buffer = event.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd({"BufEnter", "BufNew", "BufRead"}, {
  pattern = "*.clj",
  callback = function(event)
    vim.keymap.set("n", "<Leader>p", "o(debux.core/dbg )<ESC>^", { buffer = event.buf, silent = true })
  end,
})

vim.api.nvim_create_autocmd({"BufEnter", "BufNew", "BufRead"}, {
  pattern = "*.cljs",
  callback = function(event)
    vim.keymap.set("n", "<Leader>p", "o(js/console.log )<Esc>", { buffer = event.buf, silent = true })
  end,
})
