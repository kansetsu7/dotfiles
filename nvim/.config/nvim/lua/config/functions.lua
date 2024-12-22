-- qrpsqlpq {{{
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

-- upper case sql keywords {{{
function FormatSQLKeywords()
  local keywords = {
    "select",
    "as",
    "from",
    "on",
    "left",
    "right",
    "all",
    "union",
    "join",
    "full",
    "outer",
    "where",
    "and",
    "in",
    "group",
    "order",
    "by",
    "null",
    "is",
    "not",
    "case",
    "when",
    "then",
    "else",
    "end",
    "coalesce",
    "asc",
    "desc",
    "distinct",
    "with",
    "max",
    "sum",
    "count",
    "having",
    "returning",
    "update",
    "set",
  }
  for _, word in ipairs(keywords) do
    vim.cmd(string.format("silent! %%s/\\<%s\\>/%s/g", word, word:upper()))
  end
end
vim.api.nvim_create_user_command('UppercaseSQL', FormatSQLKeywords, {})
-- }}}

-- telescope: fallback to find_files if not in git dir {{{
-- ref: https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes#falling-back-to-find_files-if-git_files-cant-find-a-git-directory
local is_inside_work_tree = {}
function TelescopeGitOrFindFiles()
  local opts = {} -- define here if you want to define something

  local cwd = vim.fn.getcwd()
  if is_inside_work_tree[cwd] == nil then
    vim.fn.system("git rev-parse --is-inside-work-tree")
    is_inside_work_tree[cwd] = vim.v.shell_error == 0
  end

  if is_inside_work_tree[cwd] then
    require("telescope.builtin").git_files(opts)
  else
    require("telescope.builtin").find_files(opts)
  end
end
vim.api.nvim_create_user_command('ProjectFiles', TelescopeGitOrFindFiles, {})
-- }}}
