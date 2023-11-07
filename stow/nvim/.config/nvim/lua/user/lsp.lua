local lspconfig = require("lspconfig")

local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

vim.diagnostic.config {
  -- disable virtual text
  virtual_text = false,
  -- show signs
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

vim.lsp.handlers["textDocument/hover"]         = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

local function lsp_highlight_document(client)
  -- Set autocommands conditional on server_capabilities
  if client.server_capabilities.document_highlight then
    vim.cmd [[
      augroup lsp_document_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]]
  end
end

local function lsp_keymaps(bufnr)
  local keymap = vim.keymap.set
  local opts = { noremap = true, silent = true, buffer = bufnr }
  keymap("n", "K", vim.lsp.buf.hover, opts)
  keymap("n", "gD", vim.lsp.buf.declaration, opts)
  keymap("n", "gd", vim.lsp.buf.definition, opts)
  keymap("n", "<localleader>lt", vim.lsp.buf.type_definition, opts)
  keymap("n", "<localleader>lh", vim.lsp.buf.signature_help, opts)
  keymap("n", "<localleader>ln", vim.lsp.buf.rename, opts)
  keymap("n", "<localleader>lf", vim.lsp.buf.format, opts)
  keymap("n", "<localleader>la", vim.lsp.buf.code_action, opts)
  keymap("v", "<localleader>la", vim.lsp.buf.range_code_action, opts)

  -- local telescope = require("telescope.builtin")
  -- keymap("n", "<localleader>lw", telescope.diagnostics, opts)
  -- keymap("n", "<localleader>lr", telescope.lsp_references, opts)
  -- keymap("n", "<localleader>li", telescope.lsp_implementations, opts)
  -- keymap("n", "<localleader>ld", telescope.lsp_document_symbols, opts)
end

local on_attach = function(client, bufnr)
  if client.name == "tsserver" then
    client.server_capabilities.document_formatting = false
  end
  lsp_keymaps(bufnr)
  lsp_highlight_document(client)
end

local capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())

local servers = {
  "sumneko_lua",
  "clojure_lsp",  -- should install LSP server in local, see https://clojure-lsp.io/installation/
  -- "solargraph",  -- ruby
  "tsserver",    -- typescript
}

require("nvim-lsp-installer").setup {
  ensure_installed = { "sumneko_lua", "tsserver" }
}

for _, server in pairs(servers) do
  local opts = {
    on_attach    = on_attach,
    capabilities = capabilities,
  }

  if server == "sumneko_lua" then
    local custom_opts = {
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = {
              [vim.fn.expand("$VIMRUNTIME/lua")] = true,
              [vim.fn.stdpath("config") .. "/lua"] = true,
            },
          },
        },
      },
    }
    opts = vim.tbl_deep_extend("force", custom_opts, opts)
  end
  lspconfig[server].setup(opts)
end

local null_ls = require("null-ls")
null_ls.setup {
  sources = {
    null_ls.builtins.diagnostics.rubocop,
    -- null_ls.builtins.formatting.zprint,
    -- clj_kondo supported by LSP in default
  },
}
