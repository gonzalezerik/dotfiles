--!nonstrict
-- Bluetooth: adapter power, your devices (connect/disconnect, battery,
-- forget) and discovery + pairing of new ones. BlueZ via bluetoothctl;
-- Noctalia's own Bluetooth agent answers PIN/confirmation prompts.

local P = { title = "Bluetooth" }

local power = false
local devices = {}   -- { mac, name, paired, connected, battery, icon }
local scanning = false
local busy = {}      -- mac -> "Connecting…" / "Pairing…" / ...
local err = nil

local function glyphFor(iconName)
  local i = iconName or ""
  if string.find(i, "headset") or string.find(i, "headphone") then return "headphones" end
  if string.find(i, "keyboard") then return "keyboard" end
  if string.find(i, "mouse") or string.find(i, "tablet") then return "computer-mouse" end
  if string.find(i, "phone") then return "mobile" end
  if string.find(i, "computer") then return "laptop" end
  if string.find(i, "gaming") then return "gamepad-modern" end
  if string.find(i, "audio") or string.find(i, "speaker") then return "speaker" end
  if string.find(i, "watch") then return "watch" end
  return "bluetooth"
end

function P.load(ctx)
  ctx.run({ ctx.paths.state, "bt" }, function(r)
    devices = {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local f = string.split(line, "\t")
      if f[1] == "power" then
        power = f[2] == "on"
      elseif f[1] == "dev" then
        table.insert(devices, { mac = f[2], name = f[3] or f[2], paired = f[4] == "yes",
                                connected = f[5] == "yes", battery = tonumber(f[6] or ""), icon = f[7] or "" })
      end
    end
    table.sort(devices, function(a, b)
      if a.connected ~= b.connected then return a.connected end
      return string.lower(a.name) < string.lower(b.name)
    end)
    ctx.rerender()
  end)
end

local function bt(ctx, mac, label, ...)
  busy[mac] = label
  err = nil
  ctx.run({ ctx.paths.bluetoothctl, ... }, function(r)
    busy[mac] = nil
    if r.exitCode ~= 0 or string.find(r.stdout, "Failed") then
      err = noctalia.string.trim(string.match(r.stdout, "[^\n]*Failed[^\n]*") or r.stderr)
    end
    P.load(ctx)
  end)
  ctx.rerender()
end

local function pair(ctx, d)
  busy[d.mac] = "Pairing…"
  err = nil
  ctx.run({ ctx.paths.bluetoothctl, "--timeout", "30", "pair", d.mac }, function(r)
    if string.find(r.stdout, "Pairing successful") or string.find(r.stdout, "AlreadyExists") then
      ctx.run({ ctx.paths.bluetoothctl, "trust", d.mac }, function()
        bt(ctx, d.mac, "Connecting…", "--timeout", "15", "connect", d.mac)
      end)
    else
      busy[d.mac] = nil
      err = `Couldn't pair with {d.name}.`
      P.load(ctx)
    end
  end)
  ctx.rerender()
end

function P.actions(ctx, H)
  return {
    H.iconButton("bt-scan", "arrows-rotate", if power and not scanning then function()
      scanning = true
      ctx.run({ ctx.paths.bluetoothctl, "--timeout", "12", "scan", "on" }, function()
        scanning = false
        P.load(ctx)
      end)
      ctx.rerender()
    end else nil),
    ui.toggle({ key = "bt-power", checked = power, onChange = function(v)
      power = v == "true"
      ctx.run({ ctx.paths.noctalia, "msg", if power then "bluetooth-enable" else "bluetooth-disable" },
        function() P.load(ctx) end)
      ctx.rerender()
    end }),
  }
end

function P.view(ctx, H)
  local out = {}
  if not power then
    table.insert(out, H.card({ key = "bt-off" }, { H.note("Bluetooth is off.") }))
    return out
  end

  local mine = { H.section("MY DEVICES") }
  local others = { H.section(if scanning then "NEARBY DEVICES  ·  searching…" else "NEARBY DEVICES") }
  for _, d in ipairs(devices) do
    if d.paired then
      local sub = busy[d.mac] or (if d.connected then "Connected" else "Not connected")
      if d.connected and d.battery then sub ..= `  ·  {d.battery}%` end
      table.insert(mine, H.listRow("bt-" .. d.mac, {
        glyph = glyphFor(d.icon), active = d.connected, title = d.name, sub = sub,
        onClick = function()
          if d.connected then
            bt(ctx, d.mac, "Disconnecting…", "disconnect", d.mac)
          else
            bt(ctx, d.mac, "Connecting…", "--timeout", "15", "connect", d.mac)
          end
        end,
        trailing = { H.iconButton("bt-rm-" .. d.mac, "trash-can", function()
          bt(ctx, d.mac, "Removing…", "remove", d.mac)
        end, { iconSize = 11 }) },
      }))
    elseif d.name ~= d.mac and not string.match(d.name, "^%x%x%-%x%x%-") then
      table.insert(others, H.listRow("bt-" .. d.mac, {
        glyph = glyphFor(d.icon), title = d.name, sub = busy[d.mac] or "Click to pair",
        onClick = function() pair(ctx, d) end,
      }))
    end
  end
  if #mine == 1 then table.insert(mine, H.note("No paired devices yet.")) end
  if #others == 1 then
    table.insert(others, H.note(if scanning then "Looking for devices…" else "Use the refresh button above to search."))
  end
  if err and err ~= "" then table.insert(mine, H.note(err, "error")) end
  table.insert(out, H.card({ key = "bt-mine", gap = 4 }, mine))
  table.insert(out, H.card({ key = "bt-others", gap = 4 }, others))
  return out
end

return P
