--!nonstrict
-- Display: brightness, Night Light, Keep Awake, what each screen is running
-- at, and its colour profile. Brightness/night light/caffeine go through
-- Noctalia's IPC so its OSD and schedule stay in charge; night light and
-- caffeine have no status query, so their switches track what was toggled
-- from here.
--
-- Colour profiles are niri's (the HDR fork here): the `niri-color-profile`
-- helper reads/writes ~/.config/niri/color-profiles.kdl, which niri
-- includes and reloads live, then programs the GPU's colour pipeline.

local P = { title = "Display" }

local dragging = false
local bri = nil

-- Per output: { source, icc, hdrIcc, intensity, profiles = { {path, name} } }
local color = {}
local intensityDrag = {}

local SOURCES = { "srgb", "icc", "edid" }
local SOURCE_LABELS = { "None (treat as sRGB)", "ICC profile", "From the display (EDID)" }

local function loadColor(ctx, name)
  ctx.run({ ctx.paths.colorProfile, "get", name }, function(r)
    local decoded = noctalia.json.decode(r.stdout)
    if type(decoded) == "table" then
      color[name] = decoded
      ctx.rerender()
    end
  end)
end

function P.load(ctx)
  ctx.refreshHome()
  for _, o in ipairs(noctalia.outputs()) do
    loadColor(ctx, o.name)
  end
end

local function saveColor(ctx, name, c)
  local argv = { ctx.paths.colorProfile, "set", name, "--source", c.source,
                 "--intensity", tostring(math.floor((c.intensity or 0) + 0.5)) }
  if c.icc then
    table.insert(argv, "--icc"); table.insert(argv, c.icc)
  end
  if c.hdrIcc then
    table.insert(argv, "--hdr-icc"); table.insert(argv, c.hdrIcc)
  end
  ctx.run(argv, function() loadColor(ctx, name) end)
end

local function indexOf(list, value)
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return nil
end

local function colorCard(ctx, H, o)
  local c = color[o.name]
  local key = "d-color-" .. o.name
  if not c then
    return H.card({ key = key, gap = 6 }, { H.section("COLOUR PROFILE"), H.note("Loading…") })
  end
  local profiles = c.profiles or {}
  local names, paths = {}, {}
  for _, p in ipairs(profiles) do
    table.insert(names, p.name); table.insert(paths, p.path)
  end

  local kids = { H.section(if #noctalia.outputs() > 1 then `COLOUR PROFILE · {o.name}` else "COLOUR PROFILE") }

  table.insert(kids, ui.select({
    key = key .. "-src", options = SOURCE_LABELS, controlSize = "sm",
    selectedIndex = (indexOf(SOURCES, c.source) or 1) - 1,
    onChange = function(i)
      local src = SOURCES[(tonumber(i) or 0) + 1]
      if src and src ~= c.source then
        c.source = src
        if src == "icc" and not c.icc and #paths > 0 then c.icc = paths[1] end
        saveColor(ctx, o.name, c)
        ctx.rerender()
      end
    end,
  }))

  if c.source == "icc" then
    if #names == 0 then
      table.insert(kids, H.note("No ICC profiles found. Put .icc/.icm files in ~/.local/share/icc."))
    else
      table.insert(kids, ui.select({
        key = key .. "-icc", options = names, controlSize = "sm",
        selectedIndex = (indexOf(paths, c.icc) or 1) - 1,
        onChange = function(i)
          local path = paths[(tonumber(i) or 0) + 1]
          if path and path ~= c.icc then
            c.icc = path
            saveColor(ctx, o.name, c)
            ctx.rerender()
          end
        end,
      }))
    end
  end

  if c.source ~= "srgb" then
    local shown = intensityDrag[o.name] or c.intensity or 0
    table.insert(kids, H.note("SDR colour intensity: 0% = accurate sRGB, 100% = the panel's full native gamut"))
    table.insert(kids, H.sliderLine(key .. "-int", "palette", shown, nil,
      function(v)
        intensityDrag[o.name] = tonumber(v) or shown
        ctx.rerender()
      end,
      function()
        c.intensity = intensityDrag[o.name] or c.intensity
        intensityDrag[o.name] = nil
        saveColor(ctx, o.name, c)
      end))
  end

  local hdrNames = { "None" }
  local hdrPaths = { false }
  for i, n in ipairs(names) do
    table.insert(hdrNames, n); table.insert(hdrPaths, paths[i])
  end
  table.insert(kids, H.note("HDR profile (used while the screen is in HDR mode)"))
  table.insert(kids, ui.select({
    key = key .. "-hdr", options = hdrNames, controlSize = "sm",
    selectedIndex = (if c.hdrIcc then (indexOf(paths, c.hdrIcc) or 0) else 0),
    onChange = function(i)
      local path = hdrPaths[(tonumber(i) or 0) + 1]
      local new = if path then path else nil
      if new ~= c.hdrIcc then
        c.hdrIcc = new
        saveColor(ctx, o.name, c)
        ctx.rerender()
      end
    end,
  }))

  return H.card({ key = key, gap = 6 }, kids)
end

local function toggleRow(ctx, H, key, glyph, title, sub, on, onChange)
  return H.listRow(key, {
    glyph = glyph, active = on, title = title, sub = sub,
    onClick = function() onChange(not on) end,
    trailing = { ui.toggle({ key = key .. "-t", checked = on, onChange = function(v) onChange(v == "true") end }) },
  })
end

function P.view(ctx, H)
  local s = ctx.s
  if not dragging then bri = s.bri end
  local night = noctalia.state.get("nightlight") == true
  local caffeine = noctalia.state.get("caffeine") == true

  local out = {}
  table.insert(out, H.card({ key = "d-bri", gap = 6 }, {
    H.section("BRIGHTNESS"),
    H.sliderLine("d-bri", "sun-bright", bri or 0, nil,
      function(v)
        dragging = true
        bri = tonumber(v) or bri
        ctx.msg("brightness-set", math.floor(bri))
        ctx.rerender()
      end,
      function() dragging = false; ctx.refreshHome() end),
  }))

  table.insert(out, H.card({ key = "d-toggles", gap = 4 }, {
    toggleRow(ctx, H, "d-night", "lightbulb-on", "Night Light",
      "Warmer colours to reduce blue light", night, function(on)
        if on ~= night then
          noctalia.state.set("nightlight", on)
          ctx.msg("nightlight-force-toggle")
        end
      end),
    toggleRow(ctx, H, "d-caff", "mug-hot", "Keep Awake",
      "Don't dim, lock or sleep while on", caffeine, function(on)
        noctalia.state.set("caffeine", on)
        ctx.msg(if on then "caffeine-enable" else "caffeine-disable")
      end),
  }))

  local screens = { H.section("SCREENS") }
  for _, o in ipairs(noctalia.outputs()) do
    table.insert(screens, H.listRow("out-" .. o.name, {
      glyph = if string.sub(o.name, 1, 3) == "eDP" then "laptop" else "display",
      active = o.focused, title = o.description ~= "" and o.description or o.name,
      sub = `{o.name}  ·  {o.width}×{o.height}`,
    }))
  end
  table.insert(out, H.card({ key = "d-screens", gap = 4 }, screens))

  for _, o in ipairs(noctalia.outputs()) do
    table.insert(out, colorCard(ctx, H, o))
  end
  return out
end

return P
