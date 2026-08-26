vim.g.mapleader = ","
vim.g.maplocalleader = " "

require("config.options")
require("config.functions")
require("config.autocmds")
require("config.lazy")
require("config.keymaps")
require("config.lsp")

local is_docker = vim.fn.filereadable("/.dockerenv") == 1
if is_docker then
  require("config.docker.options")
  require("config.docker.lsp.init")
end

-- `<!-- %s -->` does not comment out ERB (the template is evaluated before the
-- HTML is parsed), so eruby gets its own ERB-safe toggle instead.
local ft = require('Comment.ft')
ft.eruby = '<%# %s %>'

require("config.erb-comment").setup()
