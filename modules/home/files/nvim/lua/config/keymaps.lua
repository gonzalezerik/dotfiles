-- ── General keymaps (non buffer-local; LSP/DAP/terminal/runner keymaps live
--    in their own modules) ────────────────────────────────────────────────
local map = vim.keymap.set

-- Better up/down on wrapped lines
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Window navigation (Ctrl+hjkl, like every IDE's pane switching)
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Buffer navigation (VSCode-style tab cycling)
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Move selected lines up/down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep cursor centered on half-page jumps / search
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Indent and reselect
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Save / quit parity with normal editors
map({ "n", "i" }, "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit window" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- File explorer (nvim-tree)
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
map("n", "<leader>o", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal file in explorer" })

-- Telescope (fuzzy finder — Ctrl+P / Ctrl+Shift+F parity)
map("n", "<C-p>", function() require("telescope.builtin").find_files() end, { desc = "Find files" })
map("n", "<leader>ff", function() require("telescope.builtin").find_files() end, { desc = "Find files" })
map("n", "<leader>fg", function() require("telescope.builtin").live_grep() end, { desc = "Grep workspace" })
map("n", "<C-S-f>", function() require("telescope.builtin").live_grep() end, { desc = "Grep workspace" })
map("n", "<leader>fb", function() require("telescope.builtin").buffers() end, { desc = "Find buffers" })
map("n", "<leader>fh", function() require("telescope.builtin").help_tags() end, { desc = "Help tags" })
map("n", "<leader>fr", function() require("telescope.builtin").oldfiles() end, { desc = "Recent files" })
map("n", "<leader>fs", function() require("telescope.builtin").lsp_document_symbols() end, { desc = "Document symbols" })
map("n", "<leader>fw", function() require("telescope.builtin").grep_string() end, { desc = "Grep word under cursor" })

-- Diagnostics / Trouble
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics (workspace)" })
map("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Diagnostics (buffer)" })
map("n", "<leader>xt", "<cmd>Trouble todo toggle<CR>", { desc = "TODOs" })
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Quickfix list" })

-- Git (gitsigns hunk nav sits in ui.lua's on_attach; this is the summary view)
map("n", "<leader>gg", "<cmd>Telescope git_status<CR>", { desc = "Git status" })
map("n", "<leader>gc", "<cmd>Telescope git_commits<CR>", { desc = "Git commits" })
