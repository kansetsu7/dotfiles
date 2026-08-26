-- ERB-safe commenting.
--
-- HTML comments (`<!-- ... -->`) do NOT comment out ERB: the template is
-- evaluated first, so `<!-- <% elsif x %> -->` still runs the branch and
-- leaks a literal `-->` into the page.
--
-- The only construct that reliably swallows *any* content is the ERB comment
-- tag `<%# ... %>`, but it terminates at the first `%>`. So every `%>` inside
-- the line is re-opened with `<%#`, which makes the transform work for pure
-- HTML, pure ERB, mixed lines and even fragments of multi-line ERB tags:
--
--   <p>hi</p>                  ->  <%# <p>hi</p> %>
--   <% elsif foo? %>           ->  <%# <% elsif foo? %> %>
--   <div><%= x %></div>        ->  <%# <div><%= x %> <%# </div> %>
--
-- All of the above render nothing.
local M = {}

local OPEN, CLOSE = '<%#', '%>'

local function split_indent(line)
  return line:match('^(%s*)(.-)%s*$')
end

local function is_commented(body)
  return body:sub(1, #OPEN) == OPEN and body:sub(-#CLOSE) == CLOSE
end

function M.comment_line(line)
  local indent, body = split_indent(line)
  if body == '' or is_commented(body) then
    return line
  end
  -- re-open a comment tag after every `%>` so nothing escapes the comment
  local escaped = body:gsub('%%>', '%%> <%%#')
  return indent .. OPEN .. ' ' .. escaped .. ' ' .. CLOSE
end

function M.uncomment_line(line)
  local indent, body = split_indent(line)
  if body == '' or not is_commented(body) then
    return line
  end
  local inner = body:sub(#OPEN + 1, -(#CLOSE + 1))
  inner = inner:gsub('%%> <%%#', '%%>')
  inner = inner:match('^%s*(.-)%s*$')
  return indent .. inner
end

function M.toggle_lines(first, last)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)

  local all_commented, any_content = true, false
  for _, line in ipairs(lines) do
    local _, body = split_indent(line)
    if body ~= '' then
      any_content = true
      if not is_commented(body) then
        all_commented = false
      end
    end
  end
  if not any_content then
    return
  end

  local fn = all_commented and M.uncomment_line or M.comment_line
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = fn(line)
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, out)
end

-- `gc{motion}` support
function _G.ErbCommentOpFunc()
  M.toggle_lines(
    vim.api.nvim_buf_get_mark(0, '[')[1],
    vim.api.nvim_buf_get_mark(0, ']')[1]
  )
end

function M.attach(bufnr)
  bufnr = bufnr or 0
  vim.bo[bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr].commentstring = '<%# %s %>'

  local opts = { buffer = bufnr, silent = true }

  vim.keymap.set('n', 'gcc', function()
    local first = vim.fn.line('.')
    M.toggle_lines(first, first + vim.v.count1 - 1)
  end, vim.tbl_extend('force', opts, { desc = 'Toggle ERB comment (line)' }))

  vim.keymap.set('n', 'gc', function()
    vim.go.operatorfunc = 'v:lua.ErbCommentOpFunc'
    return 'g@'
  end, vim.tbl_extend('force', opts, { expr = true, desc = 'Toggle ERB comment (operator)' }))

  vim.keymap.set('x', 'gc', function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
    M.toggle_lines(vim.fn.line("'<"), vim.fn.line("'>"))
  end, vim.tbl_extend('force', opts, { desc = 'Toggle ERB comment (selection)' }))
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('_erb_comment', { clear = true }),
    pattern = 'eruby',
    callback = function(args)
      M.attach(args.buf)
    end,
  })
end

return M
