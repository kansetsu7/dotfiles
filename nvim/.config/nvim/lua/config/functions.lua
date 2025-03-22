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

-- Redo rails migration {{{
-- Function to check if the file is inside db/migrate/ and extract the version number
local function get_migration_version()
  local filepath = vim.fn.expand("%:p") -- Get full file path
  local match = filepath:match(".*/db/migrate/(%d+)_.*%.rb$") -- Extract timestamp

  if match then
    return match
  else
    vim.notify("Not a migration file!", vim.log.levels.WARN)
    return nil
  end
end

-- Function to send command to tmux pane or open a new one
local function send_to_tmux(command)
  -- Check if vim-tmux-runner is available
  if vim.fn.exists(":VtrSendCommand") == 2 then
    vim.cmd("VtrSendCommand! " .. command) -- Send to existing pane
  else
    -- If no existing pane, create one and send command
    vim.cmd("VtrOpenRunner") -- Open tmux pane
    vim.cmd("VtrSendCommand! " .. command)
  end
end

-- Main function to redo a migration
function RedoMigration()
  local version = get_migration_version()
  if version then
    local command = "be rails db:migrate:redo VERSION=" .. version
    send_to_tmux(command)
    vim.notify("Redoing migration: " .. version, vim.log.levels.INFO)
  end
end
vim.api.nvim_create_user_command('RedoMigration', RedoMigration, {})

-- }}}

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
