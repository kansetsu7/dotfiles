-- `cmd` is NOT set here: nvim-lspconfig also ships an `lsp/gopls.lua`, and
-- nvim merges the rtp copies with the plugin's applied last, so anything it
-- also defines (cmd, root_dir, filetypes) wins over this file. The gopls
-- binary is pinned in lua/config/lsp/init.lua instead.
return {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
        nilness = true,
        unusedwrite = true,
        useany = true,
        ST1000 = false, -- package comments
        ST1003 = false -- naming conventions
      },
      staticcheck = true,
      gofumpt = true,
      usePlaceholders = true,
      completeUnimported = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}
