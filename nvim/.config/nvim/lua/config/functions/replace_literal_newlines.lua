function ReplaceLiteralNewlines()
  -- Replace literal \n with actual newlines in the current buffer
  vim.cmd([[%s/\\n/\r/ge]])
end
vim.api.nvim_create_user_command('ReplaceLiteralNewlines', ReplaceLiteralNewlines, {})
