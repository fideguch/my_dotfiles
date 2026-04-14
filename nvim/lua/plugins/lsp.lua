return {
  -- Mason: ensure common language servers and tools are installed
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- LSP servers
        "lua-language-server",
        "typescript-language-server",
        "pyright",
        "json-lsp",
        "yaml-language-server",
        "bash-language-server",
        -- Formatters
        "stylua",
        "prettier",
        -- Linters
        "eslint-lsp",
      },
    },
  },
}
