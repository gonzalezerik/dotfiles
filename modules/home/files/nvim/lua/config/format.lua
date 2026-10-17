-- ── Formatting (conform.nvim) + linting (nvim-lint) ─────────────────────────
-- All formatter/linter binaries come from Nix (extraPackages in nvim.nix).
require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "ruff_organize_imports", "ruff_format" },
    rust = { "rustfmt" },
    c = { "clang_format" },
    cpp = { "clang_format" },
    cuda = { "clang_format" },
    go = { "gofumpt" },
    nix = { "alejandra" },
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    javascriptreact = { "prettierd" },
    typescriptreact = { "prettierd" },
    html = { "prettierd" },
    css = { "prettierd" },
    json = { "prettierd" },
    yaml = { "prettierd" },
    markdown = { "prettierd" },
    toml = { "taplo" },
    sh = { "shfmt" },
    sql = { "sqlfluff" },
  },
  format_on_save = {
    timeout_ms = 2000,
    lsp_fallback = true,
  },
})

vim.keymap.set({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer/selection" })

local lint = require("lint")
lint.linters_by_ft = {
  python = { "ruff" },
  javascript = { "eslint_d" },
  typescript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescriptreact = { "eslint_d" },
  sh = { "shellcheck" },
  dockerfile = { "hadolint" },
  nix = { "statix" },
  go = { "golangcilint" },
  sql = { "sqlfluff" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("lint-on-save", { clear = true }),
  callback = function() lint.try_lint() end,
})
