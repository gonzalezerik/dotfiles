--!nonstrict
-- Icons from the icon font in ./icon-font.luau (generated from the private
-- site input: { family = <font family>, cp = { [name] = codepoint } }). The
-- same codepoint renders Thin/Light/Regular/Solid depending on font weight.

local font = require("./icon-font.luau")

local M = {}

M.FAMILY = font.family

M.cp = font.cp

-- weight: nil = Regular (400), "heavy" = Solid (900), "light" = Light (300)
function M.icon(name, size, color, weight)
  local cp = M.cp[name]
  if cp == nil then
    noctalia.log("icon: unknown icon name " .. tostring(name))
    cp = 0x3F -- "?"
  end
  return ui.label({
    text = utf8.char(cp),
    fontFamily = M.FAMILY,
    fontSize = size,
    fontWeight = weight,
    color = color,
    baseline = "inkCentered",
  })
end

return M
