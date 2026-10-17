--!nonstrict
-- Wi-Fi: glyph only, bars follow signal strength. Click opens the Control
-- Center sheet straight on its Wi-Fi page.

local pill = require("./lib/pill.luau")
local icon = require("./lib/icon.luau")
local paths = require("./paths.luau")

local wifi, ssid, signal = "on", "", 0
local hover

local function glyph()
  if wifi ~= "on" or ssid == "" then return "wifi-slash" end
  if signal >= 67 then return "wifi" end
  if signal >= 34 then return "wifi-fair" end
  return "wifi-weak"
end

local function render()
  barWidget.render(pill.pill({ hovered = hover.hovered, onHover = hover.handler, paddingH = 9 }, {
    icon.icon(glyph(), 13, if glyph() == "wifi-slash" then "on_surface_variant" else "primary"),
  }))
  barWidget.setTooltip(if wifi ~= "on" then "Wi-Fi off" elseif ssid == "" then "Not connected"
    else `{ssid} · {signal}%`)
end

hover = pill.hoverState(render)

function update()
  noctalia.runAsync({ paths.state, "wifi" }, function(r)
    for k, v in string.gmatch(r.stdout, "([%w_]+)=([^\n]*)") do
      if k == "wifi" then wifi = v end
      if k == "ssid" then ssid = v end
      if k == "signal" then signal = tonumber(v) or 0 end
    end
    render()
  end)
end

function onClick()
  noctalia.state.set("openPage", "wifi")
  noctalia.togglePanel("erikg/control:panel")
end

noctalia.setUpdateInterval(5000)
update()
