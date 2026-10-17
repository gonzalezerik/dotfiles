-- ── Autocommands ────────────────────────────────────────────────────────────
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight-yank", { clear = true }),
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

-- Restore cursor position when reopening a file
autocmd("BufReadPost", {
  group = augroup("restore-cursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Trim trailing whitespace on save (skip markdown/diff where it can be meaningful)
autocmd("BufWritePre", {
  group = augroup("trim-whitespace", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.tbl_contains({ "markdown", "diff" }, vim.bo.filetype) then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Auto-create parent directories on save
autocmd("BufWritePre", {
  group = augroup("auto-mkdir", { clear = true }),
  callback = function(args)
    local file = vim.uv.fs_realpath(args.match) or args.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- CUDA files: no dedicated tree-sitter grammar, so ride on the C++ parser
-- and highlight/LSP query set for .cu/.cuh instead of getting no highlighting.
vim.filetype.add({ extension = { cu = "cuda", cuh = "cuda" } })
autocmd("FileType", {
  group = augroup("cuda-as-cpp", { clear = true }),
  pattern = "cuda",
  callback = function()
    pcall(vim.treesitter.start, 0, "cpp")
    vim.bo.commentstring = "// %s"
  end,
})

-- Close certain filetypes with just "q"
autocmd("FileType", {
  group = augroup("close-with-q", { clear = true }),
  pattern = { "help", "qf", "lspinfo", "checkhealth", "man" },
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = args.buf, silent = true })
  end,
})
