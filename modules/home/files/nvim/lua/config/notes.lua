-- ── Note taking: obsidian.nvim + render-markdown.nvim ───────────────────────
-- Vault lives at ~/Notes (plain markdown + YAML frontmatter — the same
-- format the real Obsidian app reads, so it stays portable even though
-- nothing here depends on that app). Directory + the two templates are
-- seeded by home.activation.createNotesVault in nvim.nix; everything else
-- under ~/Notes is yours, not Nix-managed.
--
-- obsidian.nvim (the obsidian-nvim/obsidian.nvim fork, actively developed,
-- pre-4.0) now works as an in-process markdown LSP ("obsidian-ls"):
-- completion, hover, and go-to-definition on [[links]] come through the
-- normal nvim-cmp `nvim_lsp` source (config/completion.lua) and the
-- LspAttach keymaps in config/lsp.lua — no separate cmp source or gf/K
-- remap needed here. It also registers its own buffer-local <CR> (smart
-- action: follow link / toggle checkbox / cycle heading fold depending on
-- what's under the cursor), ]o / [o (next/prev link) automatically for any
-- vault buffer.
require("obsidian").setup({
  legacy_commands = false, -- use `:Obsidian <subcommand>` only, not the old ObsidianXxx names
  workspaces = {
    { name = "notes", path = vim.fn.expand("~/Notes") },
  },
  daily_notes = {
    enabled = true,
    folder = "daily",
    date_format = "%Y-%m-%d",
    template = "daily.md",
    workdays_only = false,
  },
  templates = {
    folder = "templates",
    date_format = "%Y-%m-%d",
    time_format = "%H:%M",
  },
  frontmatter = { enabled = true },
})

require("render-markdown").setup({
  enabled = true,
  bullet = { icons = { "◉", "○", "✸", "✿" } },
})

local map = vim.keymap.set
map("n", "<leader>nn", "<cmd>Obsidian new<CR>", { desc = "New note" })
map("n", "<leader>nt", "<cmd>Obsidian today<CR>", { desc = "Today's daily note" })
map("n", "<leader>ny", "<cmd>Obsidian yesterday<CR>", { desc = "Yesterday's daily note" })
map("n", "<leader>nd", "<cmd>Obsidian dailies<CR>", { desc = "Browse daily notes" })
map("n", "<leader>no", "<cmd>Obsidian quick_switch<CR>", { desc = "Open note (fuzzy)" })
map("n", "<leader>ns", "<cmd>Obsidian search<CR>", { desc = "Search notes (full text)" })
map("n", "<leader>nb", "<cmd>Obsidian backlinks<CR>", { desc = "Backlinks to this note" })
map("n", "<leader>ng", "<cmd>Obsidian tags<CR>", { desc = "Browse by tag" })
map("n", "<leader>nr", "<cmd>Obsidian rename<CR>", { desc = "Rename note (fixes links)" })
map("n", "<leader>nT", "<cmd>Obsidian template<CR>", { desc = "Insert template" })
map("v", "<leader>nl", "<cmd>Obsidian link<CR>", { desc = "Link selected text to a note" })
map("v", "<leader>nL", "<cmd>Obsidian link_new<CR>", { desc = "Create note from selection" })
map("n", "<leader>nc", "<cmd>Obsidian toggle_checkbox<CR>", { desc = "Toggle checkbox" })
map("n", "<leader>nm", "<cmd>RenderMarkdown toggle<CR>", { desc = "Toggle rendered markdown" })
