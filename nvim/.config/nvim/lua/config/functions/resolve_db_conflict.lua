local M = {}

local function resolve_schema_conflict(lines)
  local versions = {}
  for _, l in ipairs(lines) do
    local v = l:match("version:%s*(%d+_%d+_%d+_%d+)")
    if v then table.insert(versions, v) end
  end
  if #versions == 0 then
    vim.notify("No schema versions found in selection", vim.log.levels.ERROR)
    return nil
  end
  table.sort(versions, function(a, b)
    return (a:gsub("_", "")) < (b:gsub("_", ""))
  end)
  local max_v = versions[#versions]
  return { ("ActiveRecord::Schema.define(version: %s) do"):format(max_v) }
end

local function resolve_structure_conflict(lines)
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
    return nil
  end
  table.sort(versions)
  local result = {}
  for i, v in ipairs(versions) do
    if i < #versions then
      table.insert(result, ("('%s'),"):format(v))
    else
      table.insert(result, ("('%s');"):format(v))
    end
  end
  return result
end

function M.resolve_db_conflict()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local start_line = vim.fn.getpos("'<")[2]
  local end_line = vim.fn.getpos("'>")[2]
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line-1, end_line, false)

  local result = nil
  if filename:find("schema%.rb$") then
    result = resolve_schema_conflict(lines)
  elseif filename:find("structure%.sql$") then
    result = resolve_structure_conflict(lines)
  else
    vim.notify("This command works only on db/schema.rb or db/structure.sql files", vim.log.levels.ERROR)
    return
  end

  if result then
    vim.api.nvim_buf_set_lines(bufnr, start_line-1, end_line, false, result)
  end
end

vim.api.nvim_create_user_command(
  "ResolveDbConflict",
  function() M.resolve_db_conflict() end,
  { range = true, desc = "Resolve selected DB schema/structure merge conflict" }
)

vim.keymap.set(
  "x",
  "<leader>rd",
  ":<C-u>ResolveDbConflict<CR>",
  { silent = true, desc = "Resolve selected DB conflict" }
)

return M
