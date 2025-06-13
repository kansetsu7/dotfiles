function StripTrailingWhitespace()
  -- Don't strip whitespace for markdown or text filetypes
  local ft = vim.bo.filetype
  if ft == "markdown" or ft == "text" then
    return
  end

  -- Strip trailing whitespace
  vim.cmd([[%s/\s\+$//e]])
end
vim.api.nvim_create_user_command('StripTrailingWhitespace', StripTrailingWhitespace, {})
