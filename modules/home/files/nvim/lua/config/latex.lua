-- ── LaTeX (vimtex) — live compile + Zathura preview with forward/inverse
--    synctex search ──────────────────────────────────────────────────────────
-- vimtex talks to Zathura over dbus for both directions automatically once
-- `\lv` has launched it once; no zathurarc editing needed on a normal Linux
-- desktop with dbus running (both machines have it). If inverse search (double-click
-- in the PDF -> jump to source) doesn't come up on first try, that's a one
-- line zathurarc fix, not a vimtex problem.
vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_compiler_latexmk = {
  build_dir = "build",
  continuous = 1,
  options = {
    "-verbose", "-file-line-error", "-synctex=1", "-interaction=nonstopmode",
  },
}
vim.g.vimtex_quickfix_mode = 0 -- don't steal focus on warnings
vim.g.vimtex_syntax_conceal_disable = true

-- vimtex's own leader is backslash by default (\ll, \lv, ...); mirror the
-- most-used ones onto <leader>l for discoverability alongside the rest of
-- the keymap surface.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function(args)
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end
    map("<leader>ll", "<cmd>VimtexCompile<CR>", "Start/stop live compile")
    map("<leader>lv", "<cmd>VimtexView<CR>", "View in Zathura")
    map("<leader>le", "<cmd>VimtexErrors<CR>", "Show compile errors")
    map("<leader>lc", "<cmd>VimtexClean<CR>", "Clean aux files")
    map("<leader>lk", "<cmd>VimtexStop<CR>", "Stop compiler")
  end,
})
