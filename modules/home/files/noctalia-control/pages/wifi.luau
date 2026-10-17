--!nonstrict
-- Wi-Fi: radio switch, current connection (IP, signal, disconnect/forget),
-- nearby networks (saved first), connect with an inline password field for
-- new secured networks, forget saved ones, rescan. NetworkManager (nmcli).

local icon = require("../lib/icon.luau")

local P = { title = "Wi-Fi" }

local IFACE = "wlp194s0"

local radio = true
local nets = {}        -- { ssid, signal, secure, inUse, known }
local known = {}       -- ssid -> true (saved connection profiles)
local ip = ""
local expanded = nil   -- ssid whose password row is open
local password = ""
local busy = nil       -- ssid being connected
local err = nil
local passKey = 0

-- nmcli -g escapes ':' and '\' inside values.
local function splitEscaped(line)
  local fields, cur, i = {}, {}, 1
  while i <= #line do
    local c = string.sub(line, i, i)
    if c == "\\" and i < #line then
      table.insert(cur, string.sub(line, i + 1, i + 1))
      i += 2
    elseif c == ":" then
      table.insert(fields, table.concat(cur))
      cur = {}
      i += 1
    else
      table.insert(cur, c)
      i += 1
    end
  end
  table.insert(fields, table.concat(cur))
  return fields
end

local function strengthGlyph(sig)
  if sig >= 67 then return "wifi" end
  if sig >= 34 then return "wifi-fair" end
  return "wifi-weak"
end

function P.load(ctx)
  local nm = ctx.paths.nmcli
  ctx.run({ nm, "-g", "WIFI", "radio" }, function(r)
    radio = noctalia.string.trim(r.stdout) == "enabled"
  end)
  ctx.run({ nm, "-g", "NAME,TYPE", "connection", "show" }, function(r)
    known = {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local f = splitEscaped(line)
      if f[2] == "802-11-wireless" then known[f[1]] = true end
    end
  end)
  ctx.run({ nm, "-g", "IP4.ADDRESS", "device", "show", IFACE }, function(r)
    ip = noctalia.string.trim(string.match(r.stdout, "[^\n|]+") or "")
  end)
  ctx.run({ nm, "-g", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list", "--rescan", "no" }, function(r)
    local best = {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local f = splitEscaped(line)
      local ssid = f[4] or ""
      if ssid ~= "" then
        local n = { ssid = ssid, signal = tonumber(f[2]) or 0, secure = (f[3] or "") ~= "",
                    inUse = f[1] == "*" }
        local b = best[ssid]
        if b == nil or n.inUse or (not b.inUse and n.signal > b.signal) then best[ssid] = n end
      end
    end
    nets = {}
    for _, n in pairs(best) do
      n.known = known[n.ssid] == true
      table.insert(nets, n)
    end
    table.sort(nets, function(a, b)
      if a.inUse ~= b.inUse then return a.inUse end
      if a.known ~= b.known then return a.known end
      return a.signal > b.signal
    end)
    ctx.rerender()
  end)
end

local function finish(ctx, ssid)
  return function(r)
    busy = nil
    if r.exitCode ~= 0 then
      err = `Couldn't connect to {ssid}: ` .. noctalia.string.trim(r.stderr ~= "" and r.stderr or r.stdout)
    else
      err = nil
      expanded = nil
      password = ""
    end
    P.load(ctx)
  end
end

local function connect(ctx, n)
  err = nil
  if n.known then
    busy = n.ssid
    ctx.run({ ctx.paths.nmcli, "connection", "up", "id", n.ssid }, finish(ctx, n.ssid))
  elseif not n.secure then
    busy = n.ssid
    ctx.run({ ctx.paths.nmcli, "device", "wifi", "connect", n.ssid }, finish(ctx, n.ssid))
  else
    expanded = if expanded == n.ssid then nil else n.ssid
    password = ""
    passKey += 1
  end
  ctx.rerender()
end

local function connectWithPassword(ctx, ssid)
  if password == "" then return end
  busy = ssid
  ctx.run({ ctx.paths.nmcli, "device", "wifi", "connect", ssid, "password", password }, finish(ctx, ssid))
  ctx.rerender()
end

-- Fresh scan whenever the page is opened (the list otherwise only shows
-- NetworkManager's cached results).
function P.enter(ctx)
  err = nil
  ctx.run({ ctx.paths.nmcli, "device", "wifi", "rescan" }, function() P.load(ctx) end)
end

function P.actions(ctx, H)
  return {
    H.iconButton("wifi-rescan", "arrows-rotate", function()
      ctx.run({ ctx.paths.nmcli, "device", "wifi", "rescan" }, function() P.load(ctx) end)
    end),
    ui.toggle({ key = "wifi-radio", checked = radio, onChange = function(v)
      radio = v == "true"
      ctx.run({ ctx.paths.nmcli, "radio", "wifi", if radio then "on" else "off" }, function() P.load(ctx) end)
      ctx.rerender()
    end }),
  }
end

function P.view(ctx, H)
  local out = {}
  if not radio then
    table.insert(out, H.card({ key = "wifi-off" }, { H.note("Wi-Fi is off.") }))
    return out
  end

  local current
  for _, n in ipairs(nets) do
    if n.inUse then current = n end
  end
  if current then
    table.insert(out, H.card({ key = "wifi-cur", gap = 8 }, {
      H.section("CONNECTED"),
      ui.row({ gap = 10, align = "center" }, {
        H.circle(strengthGlyph(current.signal), true, 34),
        H.textStack(current.ssid, `{current.signal}% signal` .. (if ip ~= "" then `  ·  {ip}` else "")),
      }),
      ui.row({ gap = 8 }, {
        H.textButton("wifi-disc", "Disconnect", function()
          ctx.run({ ctx.paths.nmcli, "device", "disconnect", IFACE }, function() P.load(ctx) end)
        end),
        H.textButton("wifi-forget-cur", "Forget", function()
          ctx.run({ ctx.paths.nmcli, "connection", "delete", "id", current.ssid }, function() P.load(ctx) end)
        end),
      }),
    }))
  end

  local rows = { H.section("NETWORKS") }
  for _, n in ipairs(nets) do
    if not n.inUse then
      local trailing = {}
      if n.secure then table.insert(trailing, icon.icon("lock", 10, "on_surface_variant")) end
      if n.known then
        table.insert(trailing, H.iconButton("forget-" .. n.ssid, "trash-can", function()
          ctx.run({ ctx.paths.nmcli, "connection", "delete", "id", n.ssid }, function() P.load(ctx) end)
        end, { iconSize = 11 }))
      end
      local sub = if busy == n.ssid then "Connecting…" elseif n.known then "Saved" elseif n.secure then "Secured" else "Open"
      table.insert(rows, H.listRow("net-" .. n.ssid, {
        glyph = strengthGlyph(n.signal), title = n.ssid, sub = sub, trailing = trailing,
        onClick = function() connect(ctx, n) end,
      }))
      if expanded == n.ssid then
        table.insert(rows, ui.row({ key = "pw-" .. n.ssid, gap = 8, align = "center", paddingH = 6 }, {
          ui.input({ key = `pw-input-{passKey}`, placeholder = "Password", password = true, focus = true,
                     controlSize = "sm", flexGrow = 1,
                     onChange = function(v) password = v end,
                     onSubmit = function() connectWithPassword(ctx, n.ssid) end }),
          H.textButton("pw-go-" .. n.ssid, "Join", function() connectWithPassword(ctx, n.ssid) end, { primary = true }),
        }))
      end
    end
  end
  if #rows == 1 then
    table.insert(rows, H.note("No other networks found. Try rescanning."))
  end
  if err then
    table.insert(rows, H.note(err, "error"))
  end
  table.insert(out, H.card({ key = "wifi-list", gap = 4 }, rows))
  return out
end

return P
