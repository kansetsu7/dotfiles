return {
  {
   "shaunsingh/nord.nvim",
   config = function()
     -- vim.cmd [[colorscheme nord]]
   end
  },
  {
    'dracula/vim',
    config = function()
      -- vim.cmd [[colorscheme dracula]]
    end
  },
  {
    'rebelot/kanagawa.nvim',
    config = function()
      vim.cmd [[colorscheme kanagawa]]
      vim.cmd([[hi SpellBad guibg=#D27E99]]) -- setup SpellBad style after colorscheme set, to prevent reset by colorscheme
    end
  },
}
