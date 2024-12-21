-- ===================
--      keymaps
-- ===================
local opts = { noremap = true, silent = true }
local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

-- Remap
keymap('n', "'", "`", opts)
keymap('n', "`", "'", opts)
keymap('n', "^", "0", opts)
keymap('n', "0", "^", opts)
keymap("v", "p", "\"_dP", opts) -- Don't copy the contents of an overwritten selection.

-- TODO: need more check
-- -- sometimes need, to repeat latest f, t, F or T in opposite direction
-- keymap("", "\\", ",", opts)

-- " Helps when I want to delete something without clobbering my unnamed register.
-- keymap("n", "s", '"_d', opts)
-- keymap("n", "ss", '"_dd', opts)

-- " navigating
keymap("n", "<C-h>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateLeft()<CR>", opts)
keymap("n", "<C-j>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateDown()<CR>", opts)
keymap("n", "<C-k>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateUp()<CR>", opts)
keymap("n", "<C-l>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateRight()<CR>", opts)
keymap("n", "<C-\\>", ":lua require('nvim-tmux-navigation').NvimTmuxNavigateLastActive()<CR>", opts)
keymap('i', "<C-h>", "<Left>",  opts)
keymap('i', "<C-j>", "<Down>",  opts)
keymap('i', "<C-k>", "<Up>",    opts)
keymap('i', "<C-l>", "<Right>", opts)
keymap('c', "<C-h>", "<Left>",  opts)
keymap('c', "<C-j>", "<Down>",  opts)
keymap('c', "<C-k>", "<Up>",    opts)
keymap('c', "<C-l>", "<Right>", opts)
keymap('', "<Down>", "gj", {})
keymap('', "<Up>", "gk", {})

-- vim.cmd([[
--   noremap H ^
--   noremap L $
--   nnoremap <space><space> <c-^>
-- ]])

-- keymap("n", "j", "gj", opts)
-- keymap("n", "k", "gk", opts)
-- keymap("n", ",gv", "V`", opts)

-- -- " Keeping it centered
-- keymap("n", "n", "nzzzv", opts)
-- keymap("n", "N", "Nzzzv", opts)
-- keymap("n", "J", "mzJ`z", opts)

-- keymap("n", "<C-n>", "<C-i>", opts)

-- keymap("n", "Y", "yg_", opts)

-- -- " moving text
-- keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
-- keymap("v", "K", ":m '<-2<CR>gv=gv", opts)
-- -- " Don't copy the contents of an overwritten selection.
-- keymap("v", "p", '"_dP', opts)

-- --  Vim Tmux Navigator
-- -- vim.g['tmux_navigator_disable_when_zoomed'] = 1

-- -- " Vim Tmux Runner
-- vim.keymap.set("n", "<leader>ar", ":!tmux display-panes<CR> :VtrAttachToPane<CR>")
-- vim.keymap.set("n", "<leader>kr", ":VtrKillRunner<CR>")
-- vim.keymap.set("n", "<leader>ur", ":VtrUnsetRunnerPane<CR>")
-- vim.keymap.set("n", "<leader>sl", ":VtrSendLinesToRunner<CR>")
-- vim.keymap.set(
--     "n",
--     "<leader>rc",
--     ":VtrUnsetRunnerPane<CR>:VtrOpenRunner {'orientation': 'v', 'percentage': 15, 'cmd': 'rc'}<CR>"
-- )

-- start interactive EasyAlign in visual mode
vim.keymap.set("v", "<Enter>", "<Plug>(EasyAlign)")
-- --  start interactive EasyAlign for a motion/text object (e.g. <leader>eaip)
-- vim.keymap.set("n", "<leader>l", "<Plug>(EasyAlign)")

vim.keymap.set("n", "<leader>V", ":luafile ~/.config/nvim/init.lua<CR>:echo 'vimrc reloaded!'<CR>")

-- Telescope
keymap("n", "<C-p>", "<cmd>lua require('telescope.builtin').git_files()<cr>", opts)
keymap("n", "<leader>b", "<cmd>lua require('telescope.builtin').buffers()<cr>", opts)
keymap("n", "<leader>fl", "<cmd>lua require('telescope.builtin').find_files()<cr>", opts)
keymap("n", "<leader>fh", "<cmd>lua require('telescope.builtin').help_tags()<cr>", opts)
keymap("n", "<leader>fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>", opts)
keymap(
    "n",
    "<leader>fo",
    "<cmd>lua require('telescope.builtin').live_grep({prompt_title = 'find string in open buffers...', grep_open_files=true})<cr>",
    opts
)
keymap("n", "<leader>fc", "<cmd>lua require('telescope.builtin').grep_string()<cr>", opts)
keymap("n", "<leader>dl", "<cmd>lua require('telescope.builtin').diagnostics()<cr>", opts)

-- NvimTree
keymap("n", "<leader>dd", ":NvimTreeToggle<cr>", opts)
-- keymap("n", "<leader>df", ":NvimTreeFindFile<cr>", opts)

-- in case you forgot to sudo
keymap("c", "w!!", "%!sudo tee > /dev/null %", opts)

-- -- indenting
-- keymap("n", "<leader>in", "mmgg=G'm", opts)
-- keymap("n", "<Leader>it", ":IBLToggle<cr>", opts)
keymap("n", "<leader>p", "obinding.pry<ESC>^", term_opts)
keymap("n", "<leader>mr", "oSee merge request metis/nerv!", term_opts)

-- use system clipboard
keymap("v", "<Leader>y", '"+y', opts)
keymap("n", "<Leader>P", '"+p', opts)
keymap("n", "<Leader>y", '"+y', opts)
keymap("n", "<Leader>fy", ":let @+ = expand('%')<cr>:echo 'filename copied!'<cr>", opts)

-- -- window
-- keymap("n", "<leader>w", "<C-w>", opts)
-- keymap("n", "<leader>wf", "<C-w>f<C-w>H", opts)

-- buffer switch
keymap('n', "<Tab>", ":bnext!<CR>", opts)
keymap('n', "<S-Tab>", ":bprev!<CR>", opts)

-- -- Note that remapping C-s requires flow control to be disabled (in .zshrc)
-- keymap("n", "<C-s>", "<esc>:w<CR>", opts)
-- keymap("i", "<C-s>", "<esc>:w<CR>", opts)
-- keymap("v", "<C-s>", "<esc>:w<CR>", opts)

-- Close current buffer
keymap('n', "<leader>db", ":bd<CR>", opts)
-- keymap('n', ":bd!", ":bdelete!<CR>", opts)
keymap('n', ":cl", ":close<CR>", opts)
-- keymap("n", "<leader>q", "<esc>:bw<cr>", opts)
-- keymap("n", "<leader>x", "<esc>:bw<cr>", opts)
-- keymap("i", "<leader>q", "<esc>:bw<cr>", opts)
-- keymap("i", "<leader>x", "<esc>:bw<cr>", opts)

--  in all modes hit ,, can return to normal mode
--  NOTE: better than <esc> because  "<C-\\><C-N>" can exit terminal mode
keymap("n", ",,", "<C-\\><C-N>", opts)
keymap("i", ",,", "<C-\\><C-N>", opts)
keymap('i', ",jj", ",<esc>", opts)

-- -- run commands in vim
-- keymap("n", "<leader>ss", ":!rpu<enter>", opts)
-- keymap("n", "<leader>ks", ":!krpu<enter>", opts)

-- Rails
keymap("n", "<leader>aa", ":A<CR>", opts)
keymap("n", "<leader>av", ":AV<CR>", opts)
keymap("n", "<leader>gr", ":R<CR>", opts)
-- keymap("n", "<leader>vl", ":sp<cr><C-^><cr>", opts)
-- keymap("n", "<leader>hl", ":vsp<cr><C-^><cr>", opts)

keymap('n', ":et", ":e tmp/tools/tester.rb<CR>", opts)
keymap('n', ":ets", ":e tmp/tools/sql/test.sql<CR>", opts)

-- Git related plugins,
-- fugitive
keymap("n", "<leader>gb", ":Git blame<cr>", opts)
-- keymap("n", "<Leader>gs", "<cmd>lua require('neogit').open()<CR>", opts)
keymap("n", "<Leader>gB", ":Telescope git_branches<CR>", opts)

-- -- gitsigns, Navigation
-- keymap("n", "]c", "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", { expr = true })
-- keymap("n", "[c", "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'", { expr = true })

-- -- gitsigns, Actions
-- keymap("n", "<leader>hp", ":Gitsigns preview_hunk<CR>", opts)
-- keymap("n", "<leader>hr", ":Gitsigns reset_hunk<CR>", opts)
-- keymap("n", "<leader>hR", ":Gitsigns reset_buffer<CR>", opts)
-- keymap("v", "<leader>hr", ":Gitsigns reset_hunk<CR>", opts)

-- keymap("n", "<leader>gdi", ":Gitsigns diffthis<CR>", opts)
-- keymap("n", "<leader>gdd", ":Gitsigns diffthis ~<CR>", opts)
-- keymap("n", "<leader>tg", ":Gitsigns toggle_signs<CR>", opts)
-- keymap("n", "<leader>td", ":Gitsigns toggle_deleted<CR>", opts)

-- -- gitsigns, Text object
-- keymap("o", "ih", ":<C-U>Gitsigns select_hunk<CR>", opts)
-- keymap("x", "ih", ":<C-U>Gitsigns select_hunk<CR>", opts)

-- -- git-blame
-- keymap("n", "<leader>tb", ":GitBlameToggle<CR>", opts)

-- Abagile vim
-- vim.g.abagile_rails_test_runner = 0
-- keymap("n", "<leader><space>", ":call abagile#whitespace#strip_trailing()<cr>", opts)

keymap('n', "<localleader>cs", ":call abagile#cljs#setup_cljs_plugin_connection()<CR>", opts)
keymap('n', "<localleader>wc", ":call abagile#cljs#write_core()<CR>", opts)
keymap('n', "<localleader>ns", ":call abagile#clj#sort_require_ns()<CR>", opts)

-- -- Vim Test
-- vim.g["test#strategy"] = "vtr"

-- keymap("n", "<leader>tn", ":TestNearest<CR>", opts)
-- keymap("n", "<leader>tc", ":TestNearest<CR>", opts)
-- keymap("n", "<leader>tf", ":TestFile<CR>", opts)
-- keymap("n", "<leader>tl", ":TestLast<CR>", opts)
-- keymap("n", "<leader>ta", ":TestSuite<cr>", opts)
-- keymap("n", "<leader>tg", ":TestVisit<cr>", opts)

-- keymap("n", "<Leader>]", ":Vista<cr>", opts)

-- TODO: need more check
-- Spectre, search and replace
keymap("v", "<leader>fc", "<cmd>lua require('spectre').open_visual()<CR>", opts)

-- some shortcut
keymap('', "<leader>n", ":noh<CR>", opts)

-- replace words
keymap('v', "<leader>s", "\"hy:%s/<C-r>h", opts)
keymap('v', "<leader>/", "\"hy/<C-r>h<CR>", opts)
keymap('n', "<leader>/", "\"hye/<C-r>h<CR>", opts)

-- TODO: add below things
-- keymap('n', "<silent><leader>sql", ":call BulkUpperCaseSqlKeywords()<CR>", opts)
-- keymap('n', "<silent><leader>sql", ":call BulkUpperCaseSqlKeywords()<CR>", opts)
-- keymap('n', ":ctf!", ":CreateTestFile", opts)
