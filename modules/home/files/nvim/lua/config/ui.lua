-- ── UI: colorscheme, statusline, tabs, file tree, fuzzy finder, git signs ──

local theme = require("config.theme") -- sets colorscheme + palette overrides as a side effect

-- Statusline
require("lualine").setup({
  options = { theme = theme.lualine, globalstatus = true },
  sections = {
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "encoding", "filetype" },
  },
})

-- Buffer tabs (VSCode-style tab bar)
require("bufferline").setup({
  options = {
    diagnostics = "nvim_lsp",
    separator_style = "slant",
    offsets = {
      { filetype = "NvimTree", text = "Explorer", highlight = "Directory", separator = true },
    },
  },
})
vim.keymap.set("n", "<S-Right>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "<S-Left>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev tab" })

-- File explorer
require("nvim-tree").setup({
  view = { width = 32 },
  renderer = { group_empty = true, icons = { show = { git = true } } },
  filters = { dotfiles = false },
  git = { enable = true },
})

-- Fuzzy finder
local telescope = require("telescope")
telescope.setup({
  defaults = {
    layout_strategy = "horizontal",
    layout_config = { prompt_position = "top" },
    sorting_strategy = "ascending",
    mappings = { i = { ["<Esc>"] = require("telescope.actions").close } },
  },
})
pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "ui-select")

-- Indent guides
require("ibl").setup({ indent = { char = "│" }, scope = { enabled = true } })

-- Git gutter + hunk actions
require("gitsigns").setup({
  on_attach = function(bufnr)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    local gs = require("gitsigns")
    map("n", "]h", gs.next_hunk, "Next hunk")
    map("n", "[h", gs.prev_hunk, "Prev hunk")
    map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>ghb", gs.blame_line, "Blame line")
    map("n", "<leader>gtb", gs.toggle_current_line_blame, "Toggle inline blame")
  end,
})

-- Comments (gcc / gc motion)
require("Comment").setup()

-- Autopairs / surround
require("nvim-autopairs").setup({})
require("nvim-surround").setup({})

-- Diagnostics/quickfix pretty list, TODO highlighting
require("trouble").setup({})
require("todo-comments").setup({})

-- Which-key: discoverability for the large custom keymap surface below
local wk = require("which-key")
wk.add({
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>gh", group = "hunk" },
  { "<leader>c", group = "code" },
  { "<leader>r", group = "run/build" },
  { "<leader>d", group = "debug" },
  { "<leader>t", group = "terminal" },
  { "<leader>x", group = "diagnostics" },
  { "<leader>b", group = "buffer" },
  { "<leader>l", group = "latex" },
  { "<leader>D", group = "database" },
  { "<leader>n", group = "notes" },
})
