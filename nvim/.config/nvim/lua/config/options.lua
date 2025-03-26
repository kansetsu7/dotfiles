-- ============================
--      Settings / options
-- ============================
local options = {
  expandtab = true,  -- expand tabs to spaces
  hidden = true,     -- allow you to switch between buffers without saving
  ignorecase = true, -- case-insensitive search
  cursorline = true,
  hlsearch = true,
  swapfile = false,   -- disable .swp files creation in vim vim.opt.wrap = false
  relativenumber = true,
  scrolloff = 1,      -- show context above/below cursorline
  shiftwidth = 2,     -- normal mode indentation commands use 2 spaces
  showcmd = true,
  smartcase = true,   -- case-sensitive search if any caps
  softtabstop = 2,    -- insert mode tab and backspace use 2 spaces
  splitright = true,
  tabstop = 2,        -- actual tabs occupy 8 characters
  undofile = true,
  smartindent = true, -- Insert indents automatically
  wildmode = "longest,list,full",
  termguicolors = true,
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  updatetime = 250,
  signcolumn = "yes",
  wrap = false,
  cursorcolumn   = true,
  startofline    = false,
  -- regexpengine   = 1,
  sidescrolloff  = 5,
  encoding       = "utf8",
  mouse          = "",
  clipboard      = 'unnamed',
  wildignore = "*/.git/*,log/**,node_modules/**,target/**,*.rbc",
  -- list = true,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

vim.opt.nrformats = vim.opt.nrformats + "alpha"
vim.opt.diffopt = vim.opt.diffopt + "vertical"

vim.cmd([[hi Winseparator guibg=none]])

-- vim-dadbod-ui {{{
vim.g.dbs = {
  -- PostgreSQL connection URI format: `postgres://<username>:<password>@<host>:<port>/<database>`
  -- ref: https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
  { name = 'hk',     url = 'postgres://psql@host.docker.internal:5432/nerv_hk' },
  { name = 'ck',     url = 'postgres://psql@host.docker.internal:5432/nerv_ck' },
  { name = 'sg',     url = 'postgres://psql@host.docker.internal:5432/nerv_sg' },
  { name = 'ave_ck', url = 'postgres://psql@host.docker.internal:5432/nerv_ave_ck' },
  { name = 'amoeba', url = 'postgres://psql@host.docker.internal:5410/amoeba_development' },
}
vim.g.db_ui_use_nvim_notify = 1
-- }}}
