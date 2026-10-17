--!nonstrict
-- Control Center sheet. Home shows connectivity, toggles, brightness,
-- volume and Now Playing; each arrow opens that setting's own page inside
-- the sheet (pages/*.luau) with the full controls - no hand-off to other
-- panels. Everything uses the real system services (NetworkManager, BlueZ,
-- PipeWire, UPower, power-profiles-daemon) or Noctalia's IPC.

local paths = require("./paths.luau")
local icon = require("./lib/icon.luau")
local Widgets = require("./lib/widgets.luau")

local PAGES = {
  sound = require("./pages/sound.luau"),
  wifi = require("./pages/wifi.luau"),
  bluetooth = require("./pages/bluetooth.luau"),
  vpn = require("./pages/vpn.luau"),
  display = require("./pages/display.luau"),
  power = require("./pages/power.luau"),
}

local s = {
  wifi = false, ssid = "",
  bt = false, btdev = "",
  vpn = false, vpnname = "",
  dnd = false,
  vol = 0, muted = false,
  bri = 0,
  bat = -1, batstatus = "",
  profile = "",
  mstatus = "", title = "", artist = "", art = "",
}
local page = "home"
local artPath, artUrl = "", ""
local dragging = { vol = false, bri = false }
local hovered = nil

-- ── Context shared with pages ───────────────────────────────────────────────

local ctx = {}
ctx.s = s
ctx.paths = paths
ctx.hovered = function() return hovered end
ctx.hov = function(key)
  return function(state)
    if state == "true" then
      hovered = key
    elseif hovered == key then
      hovered = nil
    end
    render()
  end
end
ctx.rerender = function() render() end
ctx.run = function(argv, cb)
  noctalia.runAsync(argv, cb or function() end)
end
ctx.msg = function(...)
  local argv = { paths.noctalia, "msg" }
  for _, a in ipairs({ ... }) do
    table.insert(argv, tostring(a))
  end
  noctalia.runAsync(argv, function() refresh() end)
end
ctx.refreshHome = function() refresh() end
ctx.close = function() panel.close() end

local H = Widgets.new(ctx)
local msg = ctx.msg

local function go(p)
  page = p
  hovered = nil
  if PAGES[p] and PAGES[p].enter then PAGES[p].enter(ctx) end
  if PAGES[p] then PAGES[p].load(ctx) end
  render()
end

-- ── Album art: file:// used directly, http(s) cached under ~/.cache ─────────

local function hash(str)
  local h = 5381
  for i = 1, #str do
    h = (h * 33 + string.byte(str, i)) % 4294967296
  end
  return string.format("%08x", h)
end

local function resolveArt(url)
  if url == artUrl then return end
  artUrl = url
  artPath = ""
  if url == "" then return end
  if string.sub(url, 1, 7) == "file://" then
    artPath = string.sub(url, 8)
  elseif string.match(url, "^https?://") then
    local dest = noctalia.expandPath("~/.cache/noctalia-control/art-" .. hash(url))
    noctalia.runAsync({ "mkdir", "-p", noctalia.expandPath("~/.cache/noctalia-control") }, function()
      noctalia.download(url, dest, function(ok)
        if ok and artUrl == url then
          artPath = dest
          render()
        end
      end)
    end)
  end
end

-- ── Home state ──────────────────────────────────────────────────────────────

function refresh()
  noctalia.runAsync({ paths.state }, function(r)
    if r.exitCode ~= 0 then
      noctalia.log("control: state helper failed: " .. r.stderr)
      return
    end
    for line in string.gmatch(r.stdout, "[^\n]+") do
      local k, v = string.match(line, "^([%w_]+)=(.*)$")
      if k then
        if k == "wifi" or k == "bt" or k == "vpn" or k == "dnd" or k == "muted" then
          s[k] = v == "on"
        elseif k == "vol" or k == "bri" or k == "bat" then
          local n = tonumber(v)
          if n and not ((k == "vol" and dragging.vol) or (k == "bri" and dragging.bri)) then
            s[k] = n
          end
        else
          s[k] = v
        end
      end
    end
    resolveArt(s.art)
    render()
  end)
end

-- ── Home building blocks ────────────────────────────────────────────────────

-- Row in the connectivity card: click toggles, chevron opens its page.
local function connRow(key, glyph, title, sub, active, onToggle, onMore)
  local lit = H.isLit(key)
  return ui.row({ key = key, gap = 6, align = "center", radius = 12, paddingH = 4, paddingV = 3,
                  fill = if lit then "primary/0.14" else "surface_variant/0" }, {
    ui.row({ gap = 10, align = "center", flexGrow = 1, onClick = onToggle, onHover = ctx.hov(key) }, {
      H.circle(glyph, active, 30, lit),
      H.textStack(title, sub),
    }),
    H.iconButton(key .. "-more", "chevron-right", onMore),
  })
end

local function wideTile(key, glyph, title, sub, active, onClick)
  return H.card({ key = key, flexGrow = 1, onClick = onClick, padding = 10, hoverable = true,
                  border = if active then "primary/0.7" else nil }, {
    ui.row({ gap = 10, align = "center", flexGrow = 1 }, {
      H.circle(glyph, active, 30, H.isLit(key)),
      H.textStack(title, sub),
    }),
  })
end

local function smallTile(key, glyph, title, active, onClick)
  return H.card({ key = key, flexGrow = 1, onClick = onClick, padding = 8, align = "center", hoverable = true,
                  border = if active then "primary/0.7" else nil }, {
    ui.column({ gap = 5, align = "center" }, {
      H.circle(glyph, active, 32, H.isLit(key)),
      ui.label({ text = title, fontSize = 10, color = "on_surface_variant", maxLines = 1 }),
    }),
  })
end

local function sliderCard(key, title, glyph, value, onGlyph, onChange, onEnd, onMore)
  return H.card({ key = key, gap = 6, hoverable = true }, {
    ui.row({ align = "center" }, {
      ui.label({ text = title, fontSize = 13, fontWeight = "semibold", flexGrow = 1 }),
      H.iconButton(key .. "-more", "chevron-right", onMore),
    }),
    H.sliderLine(key, glyph, value, onGlyph, onChange, onEnd),
  })
end

local function nowPlaying()
  local has = s.title ~= ""
  local art
  if artPath ~= "" then
    art = ui.image({ path = artPath, width = 46, height = 46, radius = 10, fit = "cover" })
  else
    art = ui.row({ width = 46, height = 46, radius = 10, fill = "on_surface/0.10", align = "center", justify = "center" }, {
      icon.icon("music", 18, "on_surface_variant"),
    })
  end
  return H.card({ key = "media", gap = 8, hoverable = true }, {
    ui.row({ gap = 12, align = "center" }, {
      art,
      H.textStack(if has then s.title else "Not Playing", if has then s.artist else ""),
      ui.row({ gap = 2, align = "center" }, {
        H.iconButton("m-prev", "backward-step", function() msg("media", "previous") end,
          { enabled = has, weight = "heavy", color = "on_surface" }),
        H.iconButton("m-play", if s.mstatus == "Playing" then "pause" else "play", function() msg("media", "toggle") end,
          { enabled = has, weight = "heavy", color = "on_surface", size = 32, iconSize = 14 }),
        H.iconButton("m-next", "forward-step", function() msg("media", "next") end,
          { enabled = has, weight = "heavy", color = "on_surface" }),
      }),
    }),
  })
end

-- Switches the VPN last used on the VPN page (Mullvad, Tailscale or an NM
-- profile) on/off; the subtitle lists everything that is up.
local function toggleVpn()
  PAGES.vpn.toggleLast(ctx, if s.vpn then s.vpnname else "")
end

-- ── Render ──────────────────────────────────────────────────────────────────

local function homeView()
  local night = noctalia.state.get("nightlight") == true
  local caffeine = noctalia.state.get("caffeine") == true
  local volGlyph = if s.muted or s.vol == 0 then "volume-xmark" elseif s.vol < 34 then "volume-low"
    elseif s.vol < 67 then "volume" else "volume-high"
  local batText = if s.bat >= 0 then `{s.bat}%` .. (if s.batstatus == "Charging" then " · charging" else "") else ""

  return {
    ui.row({ align = "center", paddingH = 4 }, {
      ui.label({ text = "Control Center", fontSize = 14, fontWeight = "bold", flexGrow = 1 }),
      ui.row({ key = "hdr-bat", gap = 6, align = "center", paddingH = 8, height = 24, radius = 12,
               fill = if H.isLit("hdr-bat") then "primary/0.18" else "surface_variant/0",
               onClick = function() go("power") end, onHover = ctx.hov("hdr-bat") }, {
        ui.label({ text = batText, fontSize = 11, color = "on_surface_variant" }),
        icon.icon("chevron-right", 9, "on_surface_variant"),
      }),
    }),

    ui.row({ gap = 10 }, {
      H.card({ key = "conn", gap = 10, flexGrow = 1 }, {
        connRow("wifi", if s.wifi then "wifi" else "wifi-slash", "Wi-Fi",
          if not s.wifi then "Off" elseif s.ssid ~= "" then s.ssid else "Not connected", s.wifi,
          function() msg("wifi-toggle") end, function() go("wifi") end),
        connRow("bt", "bluetooth", "Bluetooth",
          if not s.bt then "Off" elseif s.btdev ~= "" then s.btdev else "On", s.bt,
          function() msg("bluetooth-toggle") end, function() go("bluetooth") end),
        connRow("vpn", "shield-halved", "VPN", if s.vpn then s.vpnname else "Not connected", s.vpn,
          toggleVpn, function() go("vpn") end),
      }),
      ui.column({ gap = 10, width = 150 }, {
        wideTile("dnd", if s.dnd then "bell-slash" else "moon", "Focus", if s.dnd then "Do Not Disturb" else "Off", s.dnd,
          function() msg("notification-dnd-toggle") end),
        wideTile("night", "lightbulb-on", "Night Light", if night then "On" else "Off", night,
          function() noctalia.state.set("nightlight", not night); msg("nightlight-force-toggle") end),
      }),
    }),

    ui.row({ gap = 10 }, {
      smallTile("caffeine", "mug-hot", "Keep Awake", caffeine,
        function() noctalia.state.set("caffeine", not caffeine); msg("caffeine-toggle") end),
      smallTile("profile", "gauge-high", if s.profile ~= "" then s.profile else "Power", s.profile == "performance",
        function() go("power") end),
      smallTile("settings", "gear", "Settings", false, function()
        panel.close()
        noctalia.runAsync({ paths.noctalia, "msg", "panel-open", "control-center", "home" })
      end),
    }),

    sliderCard("display", "Display", "sun-bright", s.bri, nil,
      function(v) dragging.bri = true; s.bri = tonumber(v) or s.bri; msg("brightness-set", math.floor(s.bri)) end,
      function() dragging.bri = false end,
      function() go("display") end),

    sliderCard("sound", "Sound", volGlyph, if s.muted then 0 else s.vol,
      function() msg("volume-mute") end,
      function(v) dragging.vol = true; s.vol = tonumber(v) or s.vol; msg("volume-set", math.floor(s.vol)) end,
      function() dragging.vol = false end,
      function() go("sound") end),

    nowPlaying(),
  }
end

function render()
  if page == "home" or PAGES[page] == nil then
    panel.render(ui.column({ gap = 10, padding = 12, flexGrow = 1 }, homeView()))
    return
  end
  local P = PAGES[page]
  panel.render(ui.column({ gap = 10, padding = 12, flexGrow = 1 }, {
    H.pageHeader(P.title, function() go("home") end, if P.actions then P.actions(ctx, H) else nil),
    ui.scroll({ key = "page-" .. page, gap = 10, flexGrow = 1 }, P.view(ctx, H)),
  }))
end

function onOpen(context)
  noctalia.state.set("panelOpen", true)
  noctalia.setUpdateInterval(2000)
  local want = noctalia.state.get("openPage")
  noctalia.state.set("openPage", nil)
  page = if context and PAGES[context] then context elseif want and PAGES[want] then want else "home"
  if PAGES[page] and PAGES[page].enter then PAGES[page].enter(ctx) end
  if PAGES[page] then PAGES[page].load(ctx) end
  render()
  refresh()
end

function update()
  if PAGES[page] then
    PAGES[page].load(ctx)
  else
    refresh()
  end
end

function onClose()
  hovered = nil
  page = "home"
  noctalia.state.set("panelOpen", false)
end
