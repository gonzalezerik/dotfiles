--!nonstrict
-- Clock in macOS menu-bar format: "Fri 11 Jul 14:57". Click opens the
-- built-in Control Center's Calendar tab.

local pill = require("./lib/pill.luau")
local paths = require("./paths.luau")

local hover

local function render()
  barWidget.render(pill.pill({ hovered = hover.hovered, onHover = hover.handler }, {
    ui.label({ text = noctalia.formatTime("{:%a %-d %b  %H:%M}"), color = "on_surface" }),
  }))
  barWidget.setTooltip(noctalia.formatTime("{:%A, %B %-d, %Y}"))
end

hover = pill.hoverState(render)

function update()
  render()
end

function onClick()
  noctalia.runAsync({ paths.noctalia, "msg", "panel-toggle", "control-center", "calendar" })
end

noctalia.setUpdateInterval(1000)
render()
