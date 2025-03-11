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
