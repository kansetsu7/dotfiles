-- Neovim 0.11+ LSP configuration using vim.lsp.config and vim.lsp.enable

-- Diagnostic signs
local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

-- Diagnostic configuration
vim.diagnostic.config {
  virtual_text = false,
  signs = {
    active = signs,
  },
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
  },
}

-- LSP handlers
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})

-- LspAttach autocmd (replaces on_attach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
  callback = function(ev)
    local bufnr = ev.buf
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    -- Keymaps
    local keymap = vim.keymap.set
    local opts = { noremap = true, silent = true, buffer = bufnr }

    keymap("n", "K", vim.lsp.buf.hover, opts)
    keymap("n", "gD", vim.lsp.buf.declaration, opts)
    keymap("n", "gd", vim.lsp.buf.definition, opts)
    keymap("n", "<localleader>li", "<cmd>lua require('telescope.builtin').lsp_implementations()<cr>", opts)
    keymap("n", "<localleader>lr", "<cmd>lua require('telescope.builtin').lsp_references()<cr>", opts)
    keymap("n", "<localleader>lt", vim.lsp.buf.type_definition, opts)
    keymap("n", "<localleader>lh", vim.lsp.buf.signature_help, opts)
    keymap("n", "<localleader>ln", vim.lsp.buf.rename, opts)
    keymap({ "v", "n" }, "<localleader>la", vim.lsp.buf.code_action, opts)
    keymap("n", "<localleader>lf", vim.lsp.buf.format, opts)

    vim.cmd [[ command! Format execute 'lua vim.lsp.buf.format()' ]]

    -- Document highlight
    if client and client.server_capabilities.documentHighlightProvider then
      local highlight_group = vim.api.nvim_create_augroup("LspDocumentHighlight", { clear = false })
      vim.api.nvim_clear_autocmds({ group = highlight_group, buffer = bufnr })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd("CursorMoved", {
        group = highlight_group,
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})

-- Mason setup (still needed for installing LSP servers)
require("mason").setup()
require("mason-lspconfig").setup {
  ensure_installed = { "jsonls", "lua_ls", "clojure_lsp", "tailwindcss", "eslint", "gopls", "rubocop" }
}

-- Add cmp_nvim_lsp capabilities to all servers
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Configure and enable LSP servers
local servers = { "jsonls", "lua_ls", "clojure_lsp", "tailwindcss", "eslint", "gopls", "rubocop" }

for _, server in ipairs(servers) do
  vim.lsp.config(server, {
    capabilities = capabilities,
  })
end

-- Enable all servers
vim.lsp.enable(servers)
