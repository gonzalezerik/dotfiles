--!nonstrict
-- Shared bar pill: plain surface_variant capsule at rest, muted-blue
-- (primary) outline + tint while hovered or while its panel is open.
-- Bar widgets using this set capsule = false in the shell config so the
-- host doesn't draw a second capsule behind it.

local M = {}

M.HEIGHT = 26

function M.pill(props, children)
  local lit = props.hovered or props.active
  return ui.row({
    key = props.key,
    gap = props.gap or 6,
    align = "center",
    paddingH = props.paddingH or 10,
    height = M.HEIGHT,
    radius = M.HEIGHT / 2,
    fill = if lit then "primary/0.16" else "surface_variant/0.85",
    border = if lit then "primary" else "surface_variant/0",
    borderWidth = 1,
    onHover = props.onHover,
  }, children)
end

-- Returns (isHovered, handler): the handler flips the flag and re-renders.
function M.hoverState(rerender)
  local st = { hovered = false }
  st.handler = function(state)
    st.hovered = state == "true"
    rerender()
  end
  return st
end

return M
