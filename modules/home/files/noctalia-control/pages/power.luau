--!nonstrict
-- Battery & power: charge, state, time remaining, draw and battery health
-- from UPower, and power-mode selection (power-profiles-daemon via
-- Noctalia's IPC, so the bar and OSD agree).

local P = { title = "Battery" }

local b = {}
local profiles = {}

local GLYPH = { ["power-saver"] = "leaf", balanced = "scale-balanced", performance = "rocket-launch" }
local LABEL = { ["power-saver"] = "Power Saver", balanced = "Balanced", performance = "Performance" }
local SUB = {
  ["power-saver"] = "Longest battery life, reduced performance",
  balanced = "Performance and battery life in balance",
  performance = "Highest performance, uses more power",
}

function P.load(ctx)
  ctx.run({ ctx.paths.state, "power" }, function(r)
    b = {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local k, v = string.match(line, "^([%w_]+)=(.*)$")
      if k then b[k] = noctalia.string.trim(v) end
    end
    profiles = {}
    for p in string.gmatch(b.profiles or "", "%S+") do table.insert(profiles, p) end
    ctx.rerender()
  end)
end

function P.view(ctx, H)
  local pct = tonumber(string.match(b.percent or "", "(%d+)")) or 0
  local state = b.state or ""
  local stateText = if state == "charging" then "Charging"
    elseif state == "fully-charged" then "Fully charged"
    elseif state == "discharging" then "On battery"
    else state
  local remaining = if state == "charging" and b.tofull then `{b.tofull} until full`
    elseif b.toempty then `{b.toempty} remaining` else ""

  local details = {}
  local rate = tonumber(string.match(b.rate or "", "([%d%.]+)"))
  local health = tonumber(string.match(b.health or "", "([%d%.]+)"))
  if rate and rate > 0 then table.insert(details, string.format("Drawing %.1f W", rate)) end
  if health then table.insert(details, string.format("Battery health %d%%", math.floor(health + 0.5))) end

  local out = {}
  table.insert(out, H.card({ key = "p-bat", gap = 8 }, {
    ui.row({ gap = 12, align = "center" }, {
      H.circle(if state == "charging" then "bolt" else "battery-full", state == "charging", 40),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = `{pct}%`, fontSize = 22, fontWeight = "bold" }),
        ui.label({ text = stateText .. (if remaining ~= "" then `  ·  {remaining}` else ""),
                   fontSize = 11, color = "on_surface_variant" }),
      }),
    }),
    ui.progress({ progress = pct / 100, height = 6, radius = 3,
                  fill = if pct <= 15 and state ~= "charging" then "error" else "primary" }),
    H.note(table.concat(details, "  ·  ")),
  }))

  local rows = { H.section("POWER MODE") }
  for _, p in ipairs(profiles) do
    local on = b.profile == p
    table.insert(rows, H.listRow("pp-" .. p, {
      glyph = GLYPH[p] or "gauge-high", active = on, selected = on,
      title = LABEL[p] or p, sub = SUB[p] or "",
      onClick = if on then nil else function()
        ctx.run({ ctx.paths.noctalia, "msg", "power-set", p }, function() P.load(ctx) end)
      end,
    }))
  end
  table.insert(out, H.card({ key = "p-modes", gap = 4 }, rows))
  return out
end

return P
