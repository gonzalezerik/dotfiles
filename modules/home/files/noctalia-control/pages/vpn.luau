--!nonstrict
-- VPN: Mullvad (connect + relay country/city), Tailscale (up/down + exit node)
-- and every NetworkManager VPN / WireGuard profile (wg-lab included), each
-- with its own switch, live status and errors. Importing/editing NM
-- profiles stays in the VPN Manager plugin ("Manage…").

local P = { title = "VPN" }

local conns = {}   -- NetworkManager: { name, type, active }
local mv = nil     -- Mullvad: { state, country, city, host } (nil = daemon not running)
local mvLoc = ""   -- relay constraint, e.g. "country us" / "city us lax"
local ts = nil     -- Tailscale: { state, ip, tailnet, exitId }
local exits = {}   -- Tailscale exit nodes: { host, ip, online, used }
local countries = {} -- Mullvad relay countries: { code, name, cities = { code, name } }
local busy = {}
local err = nil

local function loadCountries(ctx)
  ctx.run({ ctx.paths.state, "vpn-countries" }, function(r)
    local list, byCode = {}, {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local f = string.split(line, "\t")
      if f[1] == "country" then
        byCode[f[2]] = { code = f[2], name = f[3], cities = {} }
        table.insert(list, byCode[f[2]])
      elseif f[1] == "city" and byCode[f[2]] then
        table.insert(byCode[f[2]].cities, { code = f[3], name = f[4] })
      end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, c in ipairs(list) do
      table.sort(c.cities, function(a, b) return a.name < b.name end)
    end
    countries = list
    ctx.rerender()
  end)
end

function P.enter(ctx)
  err = nil
  if #countries == 0 then loadCountries(ctx) end
end

function P.load(ctx)
  ctx.run({ ctx.paths.state, "vpn" }, function(r)
    mv, ts, mvLoc, exits = nil, nil, "", {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local f = string.split(line, "\t")
      if f[1] == "mullvad" then
        mv = { state = f[2] or "", country = f[3] or "", city = f[4] or "", host = f[5] or "" }
      elseif f[1] == "mullvadloc" then
        mvLoc = f[2] or ""
      elseif f[1] == "tailscale" then
        ts = { state = f[2] or "", ip = f[3] or "", tailnet = f[4] or "", exitId = f[5] or "" }
      elseif f[1] == "exit" then
        table.insert(exits, { host = f[2], ip = f[3], online = f[4] == "true", used = f[5] == "true" })
      end
    end
    ctx.rerender()
  end)
  ctx.run({ ctx.paths.nmcli, "-g", "NAME,TYPE,ACTIVE", "connection", "show" }, function(r)
    conns = {}
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local name, typ, active = string.match(line, "^(.*):([^:]*):([^:]*)$")
      if (typ == "vpn" or typ == "wireguard") and name ~= "wg0-mullvad" then
        name = string.gsub(name, "\\(.)", "%1")
        table.insert(conns, { name = name, type = typ, active = active == "yes" })
      end
    end
    table.sort(conns, function(a, b) return a.name < b.name end)
    ctx.rerender()
  end)
end

-- Run a VPN command; `id` keys the busy label and becomes the home row's
-- "last VPN" once it comes up.
local function act(ctx, id, label, argv, up)
  busy[id] = label
  err = nil
  ctx.run(argv, function(r)
    busy[id] = nil
    if r.exitCode ~= 0 then
      err = noctalia.string.trim(r.stderr ~= "" and r.stderr or r.stdout)
      if err == "" then err = `{id}: command failed ({r.exitCode})` end
    elseif up then
      noctalia.state.set("lastVpn", id)
    end
    P.load(ctx)
    ctx.refreshHome()
  end)
  ctx.rerender()
end

local function setNm(ctx, name, up)
  act(ctx, name, if up then "Connecting…" else "Disconnecting…",
    { ctx.paths.nmcli, "connection", if up then "up" else "down", "id", name }, up)
end

-- Mullvad on also brings wg-lab up: the mullvad-coexist nft table
-- (configuration.nix) keeps homelab + tailnet reachable beside it.
local function setMullvad(ctx, up)
  act(ctx, "mullvad", if up then "Connecting…" else "Disconnecting…",
    { ctx.paths.mullvad, if up then "connect" else "disconnect" }, up)
  if up then
    for _, c in ipairs(conns) do
      if c.name == "wg-lab" and not c.active then setNm(ctx, "wg-lab", true) end
    end
  end
end

local function setTailscale(ctx, up)
  act(ctx, "tailscale", if up then "Connecting…" else "Disconnecting…",
    if up then { ctx.paths.state, "tailscale-up" } else { ctx.paths.tailscale, "down" }, up)
end

-- Home row click: switch the last VPN used from this page (default
-- Mullvad) on or off. `active` is the home summary ("Mullvad · wg-lab").
function P.toggleLast(ctx, summary)
  local last = noctalia.state.get("lastVpn") or (if ctx.paths.mullvad then "mullvad" else "wg-lab")
  local on = false
  for part in string.gmatch(summary or "", "[^·]+") do
    if string.lower(noctalia.string.trim(part)) == string.lower(last) then on = true end
  end
  if last == "mullvad" then
    setMullvad(ctx, not on)
  elseif last == "tailscale" then
    setTailscale(ctx, not on)
  else
    setNm(ctx, last, not on)
  end
end

local function toggle(key, checked, onChange)
  return ui.toggle({ key = key, checked = checked, onChange = function(v) onChange(v == "true") end })
end

local function mullvadCard(ctx, H)
  local rows = { H.section("MULLVAD") }
  if mv == nil then
    table.insert(rows, H.note("Mullvad daemon is not running."))
    return H.card({ key = "c-mullvad", gap = 4 }, rows)
  end
  local on = mv.state == "connected"
  local sub
  if busy.mullvad then
    sub = busy.mullvad
  elseif on then
    local where = if mv.city ~= "" then `{mv.city}, {mv.country}` else mv.country
    sub = if where ~= "" then `Connected · {where}` else "Connected"
  elseif mv.state == "connecting" then
    sub = "Connecting…"
  elseif mv.state == "error" then
    sub = "Error — blocking traffic"
  else
    sub = "Disconnected"
  end
  table.insert(rows, H.listRow("vpn-mullvad", {
    glyph = "shield-halved", active = on, title = "Mullvad", sub = sub,
    onClick = function() setMullvad(ctx, not on) end,
    trailing = { toggle("vpn-t-mullvad", on or mv.state == "connecting", function(v) setMullvad(ctx, v) end) },
  }))

  if #countries > 0 then
    -- "country us" / "city us lax" / "hostname us lax us-lax-wg-001" / "any"
    local words = string.split(mvLoc, " ")
    local wantCountry, wantCity = words[2] or "", words[3] or ""
    local function locSelect(key, label, names, current, onPick)
      return ui.row({ gap = 10, align = "center", paddingH = 6, paddingV = 2 }, {
        ui.label({ text = label, fontSize = 12, color = "on_surface_variant", flexGrow = 1 }),
        ui.select({ key = key, options = names, selectedIndex = current, controlSize = "sm", width = 200,
                    onChange = function(i) onPick(tonumber(i) or 0) end }),
      })
    end
    local function setLoc(...)
      act(ctx, "mullvad-loc", "Changing location…", { ctx.paths.mullvad, "relay", "set", "location", ... }, false)
    end

    local names, current, sel = { "Any country" }, 0, nil
    for i, c in ipairs(countries) do
      table.insert(names, c.name)
      if c.code == wantCountry then current, sel = i, c end
    end
    table.insert(rows, locSelect("vpn-mullvad-loc", "Country", names, current, function(idx)
      if idx == 0 then setLoc("any") elseif countries[idx] then setLoc(countries[idx].code) end
    end))

    if sel and #sel.cities > 0 then
      local cityNames, cityCurrent = { "Any city" }, 0
      for i, c in ipairs(sel.cities) do
        table.insert(cityNames, c.name)
        if c.code == wantCity then cityCurrent = i end
      end
      table.insert(rows, locSelect("vpn-mullvad-city-" .. sel.code, "City", cityNames, cityCurrent, function(idx)
        if idx == 0 then setLoc(sel.code) elseif sel.cities[idx] then setLoc(sel.code, sel.cities[idx].code) end
      end))
    end
  end
  return H.card({ key = "c-mullvad", gap = 4 }, rows)
end

local function tailscaleCard(ctx, H)
  local rows = { H.section("TAILSCALE") }
  if ts == nil then
    table.insert(rows, H.note("tailscaled is not running."))
    return H.card({ key = "c-tailscale", gap = 4 }, rows)
  end
  local on = ts.state == "Running"
  local sub
  if busy.tailscale then
    sub = busy.tailscale
  elseif on then
    sub = "Connected · " .. ts.ip .. (if ts.tailnet ~= "" then " · " .. ts.tailnet else "")
  elseif ts.state == "NeedsLogin" then
    sub = "Logged out — run `tailscale login`"
  elseif ts.state == "Starting" then
    sub = "Connecting…"
  else
    sub = "Disconnected"
  end
  table.insert(rows, H.listRow("vpn-tailscale", {
    glyph = "network-wired", active = on, title = "Tailscale", sub = sub,
    onClick = function() setTailscale(ctx, not on) end,
    trailing = { toggle("vpn-t-tailscale", on, function(v) setTailscale(ctx, v) end) },
  }))

  if on and #exits > 0 then
    local names, current = { "No exit node" }, 0
    for i, e in ipairs(exits) do
      table.insert(names, e.host .. (if e.online then "" else " (offline)"))
      if e.used then current = i end
    end
    table.insert(rows, ui.row({ gap = 10, align = "center", paddingH = 6, paddingV = 2 }, {
      ui.label({ text = "Exit node", fontSize = 12, color = "on_surface_variant", flexGrow = 1 }),
      ui.select({
        key = "vpn-ts-exit", options = names, selectedIndex = current, controlSize = "sm", width = 200,
        onChange = function(i)
          local idx = tonumber(i) or 0
          local ip = if idx == 0 then "" else (exits[idx] and exits[idx].ip)
          if ip then
            act(ctx, "tailscale-exit", "Switching exit node…", { ctx.paths.tailscale, "set", "--exit-node=" .. ip }, false)
          end
        end,
      }),
    }))
  end
  return H.card({ key = "c-tailscale", gap = 4 }, rows)
end

local function nmCard(ctx, H)
  local rows = { H.section("NETWORKMANAGER") }
  for _, c in ipairs(conns) do
    table.insert(rows, H.listRow("vpn-" .. c.name, {
      glyph = "shield-halved", active = c.active, title = c.name,
      sub = busy[c.name] or (if c.active then "Connected" else (if c.type == "wireguard" then "WireGuard" else "VPN")),
      onClick = function() setNm(ctx, c.name, not c.active) end,
      trailing = { toggle("vpn-t-" .. c.name, c.active, function(v) setNm(ctx, c.name, v) end) },
    }))
  end
  if #conns == 0 then table.insert(rows, H.note("No VPN profiles configured.")) end
  table.insert(rows, ui.row({ paddingV = 4 }, {
    H.textButton("vpn-manage", "Manage profiles…", function()
      ctx.close()
      noctalia.togglePanel("andrewdems/vpn-manager:panel")
    end),
  }))
  return H.card({ key = "c-nm", gap = 4 }, rows)
end

function P.view(ctx, H)
  local out = {}
  if err then
    table.insert(out, H.card({ key = "c-vpn-err", gap = 4, border = "error/0.6" }, { H.note(err, "error") }))
  end
  -- Mullvad / Tailscale only where they're installed (paths.luau).
  if ctx.paths.mullvad then table.insert(out, mullvadCard(ctx, H)) end
  if ctx.paths.tailscale then table.insert(out, tailscaleCard(ctx, H)) end
  table.insert(out, nmCard(ctx, H))
  return out
end

return P
