-- ── Database UI (vim-dadbod) — SQL only ─────────────────────────────────────
-- dadbod speaks postgres/mysql/sqlite/sqlserver/etc over their normal
-- connection-string protocols. It does NOT speak Bolt, so this does not
-- cover Neo4j/Cypher — there is no mainstream Neo4j Nvim plugin; Cypher
-- files at least get filetype detection + LSP-less editing via treesitter's
-- generic highlighting. Point dadbod at a DB with :DBUI after setting
-- g:dbs or a per-project .dadbod.json / db:// path.
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1

vim.keymap.set("n", "<leader>Du", "<cmd>DBUIToggle<CR>", { desc = "Toggle DB UI" })
vim.keymap.set("n", "<leader>Da", "<cmd>DBUIAddConnection<CR>", { desc = "Add DB connection" })
vim.keymap.set({ "n", "v" }, "<leader>De", "<Plug>(DBUI_ExecuteQuery)", { desc = "Execute query" })

vim.filetype.add({ extension = { cypher = "cypher" } })
