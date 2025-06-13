-- A Neovim Lua module to resolve merge conflicts in db/schema.rb and db/structure.sql
-- Place this in your `~/.config/nvim/lua/` (e.g., `lua/utils/resolve_db_conflict.lua`)

local M = {}

local function resolve_schema_conflict(lines)
  local versions = {}
  for _, l in ipairs(lines) do
    local v = l:match("version:%s*(%d+_%d+_%d+_%d+)")
    if v then table.insert(versions, v) end
  end
  if #versions == 0 then
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

local function resolve_conflict_blocks(bufnr, start_line, end_line, resolver)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local i = 1
  while i <= #lines do
    if lines[i]:match("^<<<<<<<") then
      local conflict_start = i
      while i <= #lines and not lines[i]:match("^=======") do i = i + 1 end
      while i <= #lines and not lines[i]:match("^>>>>>>>") do i = i + 1 end
      local conflict_end = i
      local block = {}
      for j = conflict_start, conflict_end do
        table.insert(block, lines[j])
      end
      local resolved = resolver(block)
      if resolved then
        vim.api.nvim_buf_set_lines(bufnr, start_line + conflict_start - 1, start_line + conflict_end, false, resolved)
        i = conflict_start + #resolved - 1
        lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
      else
        i = conflict_end + 1
      end
    else
      i = i + 1
    end
  end
end

function M.resolve_all_conflicts_in_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local resolver = nil
  if filename:find("schema%.rb$") then
    resolver = resolve_schema_conflict
  elseif filename:find("structure%.sql$") then
    resolver = resolve_structure_conflict
  else
    vim.notify("This command works only on db/schema.rb or db/structure.sql files", vim.log.levels.ERROR)
    return
  end

  resolve_conflict_blocks(bufnr, 0, line_count, resolver)
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

vim.api.nvim_create_user_command(
  "ResolveDbFile",
  function() M.resolve_all_conflicts_in_file() end,
  { desc = "Resolve all merge conflicts in schema.rb or structure.sql automatically" }
)

vim.keymap.set(
  "x",
  "<leader>rd",
  ":<C-u>ResolveDbConflict<CR>",
  { silent = true, desc = "Resolve selected DB conflict" }
)

return M
