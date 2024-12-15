return {
  -- Navigation
  "tpope/vim-unimpaired",

  { url = "ssh://git@gitlab.abagile.com:7788/abagile/vim-abagile.git" },

  {
    "Wansmer/treesj",
    config = function()
      require("treesj").setup({
        max_join_length = 500
      })
    end,
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
    -- use opts = {} for passing setup options
    -- this is equalent to setup({}) function
  },

  "tpope/vim-repeat",
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end
  },
  "tpope/vim-endwise",
  {
    "junegunn/vim-easy-align",
    config = function()
      -- default ignore comment and string
      vim.g.easy_align_ignore_groups = {}
    end
  },

  'michaeljsmith/vim-indent-object',

  -- Commenting
  -- 'tomtom/tcomment_vim'
  {
    "numToStr/Comment.nvim",
    opts = {
      -- add any options here
    },
    lazy = false,
  },

  -- search and replace
  "nvim-pack/nvim-spectre",

  "christoomey/vim-tmux-runner",
  {
    'alexghergh/nvim-tmux-navigation', config = function()
      local nvim_tmux_nav = require('nvim-tmux-navigation')
      nvim_tmux_nav.setup {
        disable_when_zoomed = true -- defaults to false
      }
      vim.keymap.set('n', "<C-h>", nvim_tmux_nav.NvimTmuxNavigateLeft)
      vim.keymap.set('n', "<C-j>", nvim_tmux_nav.NvimTmuxNavigateDown)
      vim.keymap.set('n', "<C-k>", nvim_tmux_nav.NvimTmuxNavigateUp)
      vim.keymap.set('n', "<C-l>", nvim_tmux_nav.NvimTmuxNavigateRight)
      vim.keymap.set('n', "<C-\\>", nvim_tmux_nav.NvimTmuxNavigateLastActive)
      vim.keymap.set('n', "<C-Space>", nvim_tmux_nav.NvimTmuxNavigateNext)
    end
  },

  -- Git
  "tpope/vim-fugitive",
  {
    -- TODO: is it better than 'airblade/vim-gitgutter'? or I just use vim-gitgutter's style
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
        numhl = false,     -- Toggle with `:Gitsigns toggle_numhl`
        linehl = false,    -- Toggle with `:Gitsigns toggle_linehl`
        word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir = {
          interval = 1000,
          follow_files = true,
        },
        attach_to_untracked = true,
        current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
          delay = 1000,
          ignore_whitespace = false,
        },
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil, -- Use default
        max_file_length = 40000,
        preview_config = {
          -- Options passed to nvim_open_win
          border = "single",
          style = "minimal",
          relative = "cursor",
          row = 0,
          col = 1,
        },
      })
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open lazy git" },
    },
  },

  -- text transformation
  'tpope/vim-abolish',

  -- Ruby
  "tpope/vim-rails", -- only load when opening Ruby file
  'vim-ruby/vim-ruby',
  "tpope/vim-bundler",
  "kchmck/vim-coffee-script",
  "slim-template/vim-slim",

  -- Clojure
  "gpanders/nvim-parinfer",
  "tpope/vim-sexp-mappings-for-regular-people",
  "clojure-vim/vim-jack-in",
  'tpope/vim-projectionist',

  {
    "Olical/conjure",
    config = function()
      vim.cmd "hi NormalFloat ctermbg=232" -- https://github.com/Olical/conjure/wiki/Frequently-asked-questions#the-hud-window-background-colour-makes-the-text-unreadable-how-can-i-change-it
      vim.g["conjure#log#hud#width"] = 1.0
      vim.g.conjure_map_prefix=","
      vim.g.conjure_log_direction="horizontal"
      vim.g.conjure_log_size_small=15
      vim.g.clojure_align_subforms = 1
      vim.g["conjure#client#clojure#nrepl#connection#auto_repl#enabled"] = false
      vim.g["conjure#mapping#log_reset_soft"] = "lc"
      vim.g["conjure#mapping#log_reset_hard"] = "lC"
      -- vim.g["conjure#log#hud#height"] = 0.7
      -- vim.g["conjure#log#hud#anchor"] = "SE"
      -- vim.g["conjure#highlight#enable"] = "true"
      -- vim.g["conjure#log#botright"] = "true"
    end
  },
  {
    "guns/vim-sexp",
    config = function()
      vim.g.sexp_enable_insert_mode_mappings = 0
    end
  },

  -- sql
  {
    'thinca/vim-quickrun',  -- used by vim-qrpsqlpq
    dependencies = {
      'bootleq/vim-qrpsqlpq'
    }
  }
}
