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
