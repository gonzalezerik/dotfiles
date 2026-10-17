--!nonstrict
-- Battery: percentage to the LEFT of the glyph. Click opens the Control
-- Center sheet on its Battery page.

local pill = require("./lib/pill.luau")
local icon = require("./lib/icon.luau")
local paths = require("./paths.luau")

local pct = -1
local status = ""
local hover

local function glyph()
  if status == "Charging" or status == "Full" then return "battery-bolt" end
  if pct >= 88 then return "battery-full" end
  if pct >= 63 then return "battery-three-quarters" end
  if pct >= 38 then return "battery-half" end
  if pct >= 13 then return "battery-quarter" end
  return "battery-empty"
end

local function render()
  if pct < 0 then
    barWidget.render(ui.row({}, {}))
    return
  end
  local low = pct <= 15 and status ~= "Charging"
  barWidget.render(pill.pill({ hovered = hover.hovered, onHover = hover.handler }, {
    ui.label({ text = `{pct}%`, color = if low then "error" else "on_surface" }),
    icon.icon(glyph(), 14, if low then "error" else "primary"),
  }))
  barWidget.setTooltip(`Battery {pct}% · {status}`)
end

hover = pill.hoverState(render)

function update()
  noctalia.runAsync({ paths.state, "battery" }, function(r)
    for k, v in string.gmatch(r.stdout, "([%w_]+)=([^\n]*)") do
      if k == "bat" then pct = tonumber(v) or -1 end
      if k == "batstatus" then status = v end
    end
    render()
  end)
end

function onClick()
  noctalia.state.set("openPage", "power")
  noctalia.togglePanel("erikg/control:panel")
end

noctalia.setUpdateInterval(15000)
update()
