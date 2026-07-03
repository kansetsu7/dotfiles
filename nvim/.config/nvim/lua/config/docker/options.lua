-- ============================
--  share clipboard with macOS
-- ============================
if vim.env.NVIM and vim.env.NVIM ~= '' then
  -- Nested nvim (e.g. git editor spawned from lazygit inside :terminal).
  -- Nvim's terminal emulator forwards OSC 52 writes but never answers
  -- OSC 52 read queries, so paste would hang and fall back to the local
  -- register. Read the parent instance's clipboard over RPC instead.
  local function paste_from_parent()
    local ok, chan = pcall(vim.fn.sockconnect, 'pipe', vim.env.NVIM, { rpc = true })
    if not ok or chan == 0 then
      return { { '' }, 'v' }
    end
    local lines = vim.rpcrequest(chan, 'nvim_eval', 'getreg("+", 1, 1)')
    local regtype = vim.rpcrequest(chan, 'nvim_eval', 'getregtype("+")')
    vim.fn.chanclose(chan)
    return { lines, regtype }
  end

  local osc52 = require('vim.ui.clipboard.osc52')
  vim.g.clipboard = {
    name = 'osc52-nested',
    copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
    paste = { ['+'] = paste_from_parent, ['*'] = paste_from_parent },
  }
else
  vim.g.clipboard = 'osc52'
end
