--!nonstrict
-- Sound: output + input device switching with volume/mute, and a per-app
-- mixer (volume, mute, which output each app plays to). PipeWire through
-- its PulseAudio interface (pactl), so every change is the real system one.

local icon = require("../lib/icon.luau")

local P = { title = "Sound" }

local data = { sinks = {}, sources = {}, streams = {}, defaultSink = "", defaultSource = "" }
local volumes = {}   -- key -> percent currently shown (kept while dragging)
local dragging = {}  -- key -> true while a slider is held

-- App icon paths, resolved once per name. noctalia.appIconPath matches
-- desktop entries and walks the icon theme without caching misses, which
-- blew the 25 ms per-callback CPU budget when it ran on every hover
-- re-render (3 overruns in a row disable the panel). Each lookup runs in
-- its own callback; false = no icon, nil = not looked up yet.
local iconCache = {}
local iconPending = {}

local function appIcon(ctx, name)
  if name == "" then return nil end
  local cached = iconCache[name]
  if cached ~= nil then return cached or nil end
  if not iconPending[name] then
    iconPending[name] = true
    ctx.run({ "true" }, function()
      iconCache[name] = noctalia.appIconPath(name, 32) or false
      iconPending[name] = nil
      ctx.rerender()
    end)
  end
  return nil
end

local function pctOf(vol)
  for _, ch in pairs(vol or {}) do
    return tonumber(string.match(ch.value_percent or "", "(%d+)")) or 0
  end
  return 0
end

local function shown(key, actual)
  if dragging[key] then
    return volumes[key] or actual
  end
  volumes[key] = actual
  return actual
end

-- A jack device (Headphones / Headset Microphone) whose port reports
-- "not available" has nothing plugged in: hide it unless it is the current
-- default, so the list only shows what you can actually use.
local function plugged(dev, isDefault)
  if isDefault then return true end
  for _, p in ipairs(dev.ports or {}) do
    if p.name == dev.active_port then
      return p.availability ~= "not available"
    end
  end
  return true
end

local function deviceGlyph(dev)
  local text = string.lower((dev.description or "") .. " " .. (dev.name or ""))
  if string.find(text, "headphone") or string.find(text, "headset") then return "headphones" end
  if string.find(text, "bluez") then return "headphones" end
  if string.find(text, "hdmi") or string.find(text, "displayport") then return "tv" end
  return "speaker"
end

function P.load(ctx)
  ctx.run({ ctx.paths.state, "audio" }, function(r)
    local decoded = noctalia.json.decode(r.stdout)
    if type(decoded) == "table" then
      data = decoded
      ctx.rerender()
    end
  end)
end

local function pactl(ctx, ...)
  local argv = { ctx.paths.pactl, ... }
  ctx.run(argv, function() P.load(ctx) end)
end

local function volumeSlider(ctx, H, key, glyph, dev, setCmd, muteCmd, target)
  local actual = if dev.mute then 0 else pctOf(dev.volume)
  return H.sliderLine(key, glyph, shown(key, actual),
    function() pactl(ctx, muteCmd, target, "toggle") end,
    function(v)
      dragging[key] = true
      volumes[key] = tonumber(v) or volumes[key]
      ctx.run({ ctx.paths.pactl, setCmd, target, `{math.floor(volumes[key])}%` })
      ctx.rerender()
    end,
    function() dragging[key] = nil; P.load(ctx) end)
end

function P.view(ctx, H)
  local out = {}

  -- Outputs
  local sinks = data.sinks or {}
  local def
  for _, s in ipairs(sinks) do
    if s.name == data.defaultSink then def = s end
  end
  local outRows = { H.section("OUTPUT") }
  if def then
    local g = if def.mute or pctOf(def.volume) == 0 then "volume-xmark" else "volume-high"
    table.insert(outRows, volumeSlider(ctx, H, "out-vol", g, def, "set-sink-volume", "set-sink-mute", def.name))
  end
  for _, s in ipairs(sinks) do
    local isDef = s.name == data.defaultSink
    if not plugged(s, isDef) then continue end
    table.insert(outRows, H.listRow("sink-" .. s.name, {
      glyph = deviceGlyph(s), active = isDef, selected = isDef,
      title = s.description or s.name,
      sub = if s.mute then "Muted" else `{pctOf(s.volume)}%`,
      onClick = if isDef then nil else function() pactl(ctx, "set-default-sink", s.name) end,
    }))
  end
  table.insert(out, H.card({ key = "c-out", gap = 6 }, outRows))

  -- Inputs (monitors of outputs are not microphones)
  local inRows = { H.section("INPUT") }
  local defIn
  local sources = {}
  for _, s in ipairs(data.sources or {}) do
    local class = s.properties and s.properties["device.class"] or ""
    if class ~= "monitor" and not string.find(s.name or "", "%.monitor$")
       and plugged(s, s.name == data.defaultSource) then
      table.insert(sources, s)
      if s.name == data.defaultSource then defIn = s end
    end
  end
  if defIn then
    local g = if defIn.mute then "microphone-slash" else "microphone"
    table.insert(inRows, volumeSlider(ctx, H, "in-vol", g, defIn, "set-source-volume", "set-source-mute", defIn.name))
  end
  for _, s in ipairs(sources) do
    local isDef = s.name == data.defaultSource
    table.insert(inRows, H.listRow("src-" .. s.name, {
      glyph = if string.find(string.lower(s.description or ""), "headset") then "headset" else "microphone",
      active = isDef, selected = isDef,
      title = s.description or s.name,
      sub = if s.mute then "Muted" else `{pctOf(s.volume)}%`,
      onClick = if isDef then nil else function() pactl(ctx, "set-default-source", s.name) end,
    }))
  end
  if #sources == 0 then
    table.insert(inRows, H.note("No microphones found."))
  end
  table.insert(out, H.card({ key = "c-in", gap = 6 }, inRows))

  -- Applications
  local appRows = { H.section("APPLICATIONS") }
  local sinkNames, sinkLabels = {}, {}
  local visibleSinks = {}
  for _, s in ipairs(sinks) do
    if plugged(s, s.name == data.defaultSink) then table.insert(visibleSinks, s) end
  end
  for _, s in ipairs(visibleSinks) do
    table.insert(sinkNames, s.name)
    table.insert(sinkLabels, s.description or s.name)
  end
  for _, st in ipairs(data.streams or {}) do
    local props = st.properties or {}
    local name = props["application.name"] or props["application.process.binary"] or "Application"
    local media = props["media.name"] or ""
    local iconName = props["application.icon_name"] or props["application.process.binary"] or ""
    local iconPath = appIcon(ctx, iconName)
    local key = "app-" .. tostring(st.index)
    local actual = if st.mute then 0 else pctOf(st.volume)
    local current = 0
    for i, vs in ipairs(visibleSinks) do
      if vs.index == st.sink then current = i - 1 end
    end
    local head = {
      if iconPath then ui.image({ path = iconPath, width = 22, height = 22 })
        else icon.icon("music", 14, "on_surface_variant"),
      H.textStack(name, if media ~= name then media else ""),
    }
    local rows = {
      ui.row({ gap = 10, align = "center" }, head),
      H.sliderLine(key, if st.mute then "volume-xmark" else "volume", shown(key, actual),
        function() pactl(ctx, "set-sink-input-mute", tostring(st.index), "toggle") end,
        function(v)
          dragging[key] = true
          volumes[key] = tonumber(v) or volumes[key]
          ctx.run({ ctx.paths.pactl, "set-sink-input-volume", tostring(st.index), `{math.floor(volumes[key])}%` })
          ctx.rerender()
        end,
        function() dragging[key] = nil; P.load(ctx) end),
    }
    if #sinkNames > 1 then
      table.insert(rows, ui.select({
        key = key .. "-out", options = sinkLabels, selectedIndex = current, controlSize = "sm",
        onChange = function(i)
          local n = sinkNames[(tonumber(i) or 0) + 1]
          if n then pactl(ctx, "move-sink-input", tostring(st.index), n) end
        end,
      }))
    end
    table.insert(appRows, ui.column({ key = key .. "-box", gap = 6, paddingV = 4 }, rows))
  end
  if #(data.streams or {}) == 0 then
    table.insert(appRows, H.note("No apps are playing audio right now."))
  end
  table.insert(out, H.card({ key = "c-apps", gap = 6 }, appRows))

  return out
end

return P
