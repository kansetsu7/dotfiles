--- Resolve merge conflict in db/schema.rb or db/structure.sql under the cursor selection
local M = {}
function M.resolve_db_conflict()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local start_line = vim.fn.getpos("'<")[2]
  local end_line   = vim.fn.getpos("'>")[2]
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line-1, end_line, false)
  local result = {}

  if filename:find("schema%.rb$") then
    -- Collect all version strings like 2025_06_11_004922
    local versions = {}
    for _, l in ipairs(lines) do
      local v = l:match("version:%s*(%d+_%d+_%d+_%d+)")
      if v then table.insert(versions, v) end
    end
    if #versions == 0 then
      vim.notify("No schema versions found in selection", vim.log.levels.ERROR)
      return
    end
    -- Sort by numeric value (underscores removed)
    table.sort(versions, function(a, b)
      return (a:gsub("_", "")) < (b:gsub("_", ""))
    end)
    local max_v = versions[#versions]
    table.insert(result, ("ActiveRecord::Schema.define(version: %s) do"):format(max_v))

  elseif filename:find("structure%.sql$") then
    -- Collect unique migration versions
    local versions = {}
    local seen = {}
    for _, l in ipairs(lines) do
      for v in l:gmatch("%('(%d+)'%)") do
        if not seen[v] then
          seen[v] = true
          table.insert(versions, v)
        end
      end
    end
    if #versions == 0 then
      vim.notify("No migration versions found in selection", vim.log.levels.ERROR)
      return
    end
    table.sort(versions)
    for i, v in ipairs(versions) do
      if i < #versions then
        table.insert(result, ("('%s'),"):format(v))
      else
        table.insert(result, ("('%s');"):format(v))
      end
    end
  else
    vim.notify("This command works only on db/schema.rb or db/structure.sql files", vim.log.levels.ERROR)
    return
  end

  -- Replace the conflict block with resolved lines
  vim.api.nvim_buf_set_lines(bufnr, start_line-1, end_line, false, result)
end

-- Define a user command that can be called from visual mode
vim.api.nvim_create_user_command(
  "ResolveDbConflict",
  function() M.resolve_db_conflict() end,
  { range = true, desc = "Resolve selected DB schema/structure merge conflict" }
)
return M
