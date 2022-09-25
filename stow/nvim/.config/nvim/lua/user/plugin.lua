-- Use packer to manage plugin
-- Ref: https://github.com/wbthomason/packer.nvim#quickstart
local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save this file
vim.cmd [[
  augroup packer_user_plugins
    autocmd!
    autocmd BufWritePost plugin.lua source <afile> | PackerSync
  augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

-- Install your plugins here
return packer.startup(function(use)
  use "lewis6991/impatient.nvim" -- Speed up loading Lua modules to improve startup time
  use "wbthomason/packer.nvim" -- Have packer manage itself
  use "nvim-lua/popup.nvim" -- An implementation of the Popup API from vim in Neovim
  use "nvim-lua/plenary.nvim" -- Useful lua functions used by lots of plugins

  -- ===========================
  -- Vim Enhancement
  -- ===========================
  use 'tpope/vim-sensible'
  use 'tpope/vim-surround'
  use 'tpope/vim-repeat'
  use 'tpope/vim-commentary'
  use 'tpope/vim-unimpaired'
  use 'junegunn/vim-easy-align'
  use 'scrooloose/nerdtree'
  use 'Shougo/denite.nvim'
  use { "junegunn/fzf", run = ":call fzf#install()" }
  use 'junegunn/fzf.vim'
  use 'alexghergh/nvim-tmux-navigation'
  use 'tpope/vim-projectionist'
  use 'junegunn/rainbow_parentheses.vim'
  use 'guns/vim-sexp'
  use 'tpope/vim-sexp-mappings-for-regular-people'
  use 'ssh://git@gitlab.abagile.com:7788/abagile/vim-abagile.git'
  use 'ap/vim-css-color'
  use 'jiangmiao/auto-pairs'

  -- ===========================
  -- Dev tools
  -- ===========================
  use 'w0rp/ale'
  use 'Yggdroot/indentLine'
  use 'michaeljsmith/vim-indent-object'
  use 'thinca/vim-quickrun'
  use 'bootleq/vim-qrpsqlpq'
  use 'tpope/vim-dispatch'
  use 'AndrewRadev/splitjoin.vim'
  use 'tpope/vim-abolish'

  -- ===========================
  -- Git
  -- ===========================
  use 'tpope/vim-fugitive'
  use 'airblade/vim-gitgutter'

  -- ===========================
  -- Theme
  -- ===========================
  use 'dracula/vim'
  use 'vim-airline/vim-airline'
  use 'vim-airline/vim-airline-themes'

  -- ===========================
  -- Ruby and Rails
  -- ===========================
  use 'tpope/vim-rails'
  use 'slim-template/vim-slim'
  use 'vim-ruby/vim-ruby'

  -- ===========================
  -- Clojure
  -- ===========================
  use 'tpope/vim-fireplace'
  -- use 'Olical/conjure', { 'for': 'clojure' }
  -- use 'eraserhd/parinfer-rust', {'do': 'cargo build --release', 'for': 'clojure' }
  -- use 'clojure-vim/vim-jack-in', { 'for': 'clojure' }
  use {
    "Olical/conjure",
    ft = "clojure",
  }
  use {
    "eraserhd/parinfer-rust",
    ft = "clojure",
    run = "cargo build --release",
  }
  use {
    "clojure-vim/vim-jack-in",
    ft = "clojure",
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
