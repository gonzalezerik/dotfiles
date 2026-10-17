--!nonstrict
-- Control Center button: two-slider glyph. Outlined while hovered and while
-- the panel it drops is open (panel.luau publishes "panelOpen").

local pill = require("./lib/pill.luau")
local icon = require("./lib/icon.luau")

local open = noctalia.state.get("panelOpen") == true
local hover

local function render()
  barWidget.render(pill.pill({ hovered = hover.hovered, active = open, onHover = hover.handler, paddingH = 9 }, {
    icon.icon("sliders", 13, "primary"),
  }))
end

hover = pill.hoverState(render)

noctalia.state.watch("panelOpen", function(v)
  open = v == true
  render()
end)

barWidget.setTooltip("Control Center")

function onClick()
  noctalia.togglePanel("erikg/control:panel")
end

render()
