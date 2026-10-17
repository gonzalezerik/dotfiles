-- ── General editor options ─────────────────────────────────────────────────
local o = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "

o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.mouse = "a"
o.scrolloff = 8
o.sidescrolloff = 8
o.wrap = false
o.splitright = true
o.splitbelow = true

o.tabstop = 4
o.softtabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.smartindent = true

o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true

o.undofile = true
o.undodir = vim.fn.stdpath("state") .. "/undo"
o.swapfile = false
o.backup = false
o.updatetime = 250
o.timeoutlen = 400

o.completeopt = { "menu", "menuone", "noselect" }
o.pumheight = 12
o.winborder = "rounded"

o.clipboard = "unnamedplus"
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.g.editorconfig = true
