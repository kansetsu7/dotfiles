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
