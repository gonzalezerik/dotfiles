-- ── Desktop palette theme ────────────────────────────────────────────────────
-- config.palette is generated from the host theme (modules/home/nvim.nix),
-- the same palette as Noctalia, the niri focus ring and foot, so the editor
-- reads as part of the desktop instead of a generic dark theme.
local c = require("config.palette")

-- tokyonight-night as the base (handles the long tail of plugin/treesitter
-- highlight groups correctly); the overrides below replace its palette with
-- the host palette everywhere it actually shows.
vim.cmd.colorscheme("tokyonight-night")

local hl = vim.api.nvim_set_hl
local groups = {
  Normal = { fg = c.fg, bg = c.bg },
  NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.bg_float },
  FloatBorder = { fg = c.border, bg = c.bg_float },
  SignColumn = { bg = c.bg },
  CursorLine = { bg = c.black },
  CursorLineNr = { fg = c.primary, bold = true },
  LineNr = { fg = c.bright_black },
  Visual = { bg = c.bg_hover },
  Search = { fg = c.bg, bg = c.yellow },
  IncSearch = { fg = c.bg, bg = c.primary },
  Pmenu = { fg = c.fg, bg = c.bg_float },
  PmenuSel = { fg = c.fg_bright, bg = c.bg_hover },
  WinSeparator = { fg = c.border },
  VertSplit = { fg = c.border },
  StatusLine = { fg = c.fg, bg = c.bg_float },
  StatusLineNC = { fg = c.fg_dim, bg = c.bg },
  Directory = { fg = c.primary },
  Title = { fg = c.primary, bold = true },
  NonText = { fg = c.bright_black },
  Comment = { fg = c.fg_dim, italic = true },
  CursorLineFold = { bg = c.black },
  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.yellow },
  DiagnosticInfo = { fg = c.primary },
  DiagnosticHint = { fg = c.green },
  DiffAdd = { fg = c.green, bg = "NONE" },
  DiffChange = { fg = c.yellow, bg = "NONE" },
  DiffDelete = { fg = c.red, bg = "NONE" },
  GitSignsAdd = { fg = c.green },
  GitSignsChange = { fg = c.yellow },
  GitSignsDelete = { fg = c.red },
  TelescopeBorder = { fg = c.border, bg = c.bg_float },
  TelescopeNormal = { bg = c.bg_float },
  TelescopeSelection = { bg = c.bg_hover, fg = c.fg_bright },
  TelescopePromptBorder = { fg = c.primary, bg = c.bg_float },
  WhichKeyBorder = { fg = c.border },
  WhichKeyFloat = { bg = c.bg_float },
  NvimTreeNormal = { fg = c.fg, bg = c.bg },
  NvimTreeWinSeparator = { fg = c.border, bg = c.bg },
  ToggleTermBorder = { fg = c.border },
}
for group, opts in pairs(groups) do
  hl(0, group, opts)
end

return {
  colors = c,
  lualine = {
    normal = {
      a = { fg = c.bg, bg = c.primary, gui = "bold" },
      b = { fg = c.fg, bg = c.bg_float },
      c = { fg = c.fg_dim, bg = c.bg },
    },
    insert = { a = { fg = c.bg, bg = c.green, gui = "bold" } },
    visual = { a = { fg = c.bg, bg = c.magenta, gui = "bold" } },
    replace = { a = { fg = c.bg, bg = c.red, gui = "bold" } },
    command = { a = { fg = c.bg, bg = c.yellow, gui = "bold" } },
    inactive = {
      a = { fg = c.fg_dim, bg = c.bg },
      b = { fg = c.fg_dim, bg = c.bg },
      c = { fg = c.fg_dim, bg = c.bg },
    },
  },
}
