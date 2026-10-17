-- ── Terminal: a VSCode-style bottom panel + a floating popup ────────────────
require("toggleterm").setup({
  size = function(term)
    if term.direction == "horizontal" then return 15 end
    if term.direction == "vertical" then return vim.o.columns * 0.4 end
    return 20
  end,
  open_mapping = [[<C-`>]], -- VSCode's own default toggle key
  direction = "horizontal", -- default = the bottom panel
  shade_terminals = true,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  close_on_exit = false,
  float_opts = { border = "curved" },
})

local Terminal = require("toggleterm.terminal").Terminal

-- bottom_term (id=1) is the general-purpose panel *and* where <leader>r*
-- build/run/test commands land — matching VSCode's single
-- integrated-terminal-does-everything behaviour. Exported via M.run() so
-- config/runners.lua can drive it.
local bottom_term = Terminal:new({ direction = "horizontal", id = 1, hidden = true })
local float_term = Terminal:new({ direction = "float", id = 2, hidden = true })

local map = vim.keymap.set
map("n", "<leader>tt", function() bottom_term:toggle() end, { desc = "Toggle bottom terminal" })
map("n", "<leader>tf", function() float_term:toggle() end, { desc = "Toggle floating terminal" })
map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", { desc = "Toggle vertical terminal" })
-- Escape back to normal mode from inside any terminal
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
map("t", "<C-h>", [[<Cmd>wincmd h<CR>]])
map("t", "<C-j>", [[<Cmd>wincmd j<CR>]])
map("t", "<C-k>", [[<Cmd>wincmd k<CR>]])
map("t", "<C-l>", [[<Cmd>wincmd l<CR>]])

-- Exported for config/runners.lua: run a shell command in the bottom panel,
-- opening it if needed (VSCode "Run Task" behaviour).
local M = {}
function M.run(cmd)
  bottom_term:open()
  vim.defer_fn(function() bottom_term:send(cmd, false) end, 50)
end

return M
