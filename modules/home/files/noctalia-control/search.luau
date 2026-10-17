--!nonstrict
-- Search: opens Noctalia's launcher (apps, files, calculator, ...).

local pill = require("./lib/pill.luau")
local icon = require("./lib/icon.luau")
local paths = require("./paths.luau")

local hover

local function render()
  barWidget.render(pill.pill({ hovered = hover.hovered, onHover = hover.handler, paddingH = 9 }, {
    icon.icon("magnifying-glass", 13, "primary"),
  }))
end

hover = pill.hoverState(render)
barWidget.setTooltip("Search")

function onClick()
  noctalia.runAsync({ paths.noctalia, "msg", "panel-toggle", "launcher" })
end

render()
