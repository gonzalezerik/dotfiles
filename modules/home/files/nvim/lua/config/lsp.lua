-- ── LSP ──────────────────────────────────────────────────────────────────────
-- Uses Neovim's native vim.lsp.config/vim.lsp.enable (0.11+) rather than the
-- deprecated require('lspconfig').<server>.setup{} wrapper — nvim-lspconfig
-- stays installed purely as a config database (its lsp/<server>.lua files
-- on the runtimepath); it's never require()'d directly, which is also what
-- avoids the "framework is deprecated" warning on every startup.
-- All servers below are installed via Nix (programs.neovim.extraPackages in
-- nvim.nix) and put on nvim's wrapped PATH — no Mason, nothing downloaded at
-- runtime.
local capabilities = require("cmp_nvim_lsp").default_capabilities()

require("fidget").setup({})

-- Merged as the base of every server's config below.
vim.lsp.config("*", { capabilities = capabilities })

vim.diagnostic.config({
  virtual_text = { prefix = "●" },
  severity_sort = true,
  float = { border = "rounded" },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
  },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    map("n", "gd", vim.lsp.buf.definition, "Goto definition")
    map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
    map("n", "gr", require("telescope.builtin").lsp_references, "References")
    map("n", "gI", vim.lsp.buf.implementation, "Goto implementation")
    map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
    map("n", "K", vim.lsp.buf.hover, "Hover docs")
    map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("v", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
    map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
    map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
  end,
})

-- Servers that only need the defaults.
local simple_servers = {
  "clangd", "html", "cssls", "jsonls", "bashls", "yamlls",
  "taplo", "dockerls", "sqls", "texlab", "marksman",
}

-- Rust: rustaceanvim-free plain config (kept simple / non-invasive).
vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true },
      checkOnSave = true,
      check = { command = "clippy" },
    },
  },
})

-- Python: pyright for types/nav, ruff for lint+format+import-organize.
-- Disable pyright's own diagnostics duplication with ruff where they overlap.
vim.lsp.config("pyright", {
  settings = {
    pyright = { disableOrganizeImports = true },
    python = { analysis = { typeCheckingMode = "basic" } },
  },
})
vim.lsp.config("ruff", {
  on_attach = function(client) client.server_capabilities.hoverProvider = false end, -- defer hover to pyright
})

-- Nix
vim.lsp.config("nil_ls", {
  settings = { ["nil"] = { formatting = { command = { "alejandra" } } } },
})

-- Lua (incl. this very config — vim globals recognised)
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

-- Go
vim.lsp.config("gopls", {
  settings = { gopls = { gofumpt = true, staticcheck = true } },
})

-- C#
vim.lsp.config("omnisharp", { cmd = { "OmniSharp" } })

-- Arduino (.ino): wraps clangd using arduino-cli's build flags for the board.
vim.lsp.config("arduino_language_server", {
  cmd = {
    "arduino-language-server",
    "-cli", "arduino-cli",
    "-cli-config", vim.fn.expand("~/.arduino15/arduino-cli.yaml"),
    "-clangd", "clangd",
    "-fqbn", "arduino:avr:uno",
  },
})

vim.lsp.enable(simple_servers)
vim.lsp.enable({
  "rust_analyzer", "pyright", "ruff", "nil_ls", "lua_ls", "ts_ls", "gopls", "omnisharp",
  "arduino_language_server",
})
