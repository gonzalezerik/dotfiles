--!nonstrict
-- Hardware at a glance, one pill:  CPU %  ·  RAM used/total  ·  GPU % VRAM used/total
-- CPU/RAM come from Noctalia's own system monitor (already sampled for the
-- shell); GPU busy % and VRAM/GTT come from amdgpu sysfs via the helper,
-- since the 96 GiB VRAM carve-out vs 31 GiB system RAM split is the point.
-- Hover shows the detail; click opens the built-in Control Center's System
-- tab (graphs, per-core, uptime).

local pill = require("./lib/pill.luau")
local icon = require("./lib/icon.luau")
local paths = require("./paths.luau")

local GiB = 1024 * 1024 * 1024
local gpu = { busy = nil, vramUsed = nil, vramTotal = nil, gttUsed = nil, gttTotal = nil }
local hover

local function gib(bytes, digits)
  return string.format("%." .. (digits or 1) .. "f", bytes / GiB)
end

local function pct(v)
  if v == nil then return "–" end
  return string.format("%d%%", math.floor(v + 0.5))
end

local function stat(glyph, text, width)
  return ui.row({ gap = 5, align = "center" }, {
    icon.icon(glyph, 13, "primary"),
    ui.label({ text = text, color = "on_surface", width = width }),
  })
end

local function dot()
  return ui.label({ text = "·", color = "on_surface_variant" })
end

local function render()
  local s = noctalia.systemStats()
  local cpu = if s then s.cpu.usagePercent else nil
  local ramText = "–"
  if s and s.ram.totalMb then
    ramText = `{gib(s.ram.usedMb * 1024 * 1024)}/{gib(s.ram.totalMb * 1024 * 1024, 0)}G`
  end
  local gpuText = pct(gpu.busy)
  if gpu.vramTotal then
    gpuText ..= `  {gib(gpu.vramUsed)}/{gib(gpu.vramTotal, 0)}G`
  end

  barWidget.render(pill.pill({ hovered = hover.hovered, onHover = hover.handler, gap = 8, paddingH = 12 }, {
    stat("microchip", pct(cpu), 30),
    dot(),
    stat("memory", ramText, 62),
    dot(),
    stat("display", gpuText, 96),
  }))

  -- Detail tooltip
  local lines = {}
  if s then
    local cpuLine = `CPU  {pct(cpu)}`
    if s.cpu.freqMhz then cpuLine ..= string.format("  ·  %.1f GHz", s.cpu.freqMhz / 1000) end
    if s.cpu.tempC then cpuLine ..= string.format("  ·  %d°C", s.cpu.tempC) end
    table.insert(lines, cpuLine)
    table.insert(lines, string.format("RAM  %s of %s GiB (%d%%)", gib(s.ram.usedMb * 1048576),
      gib(s.ram.totalMb * 1048576), math.floor(s.ram.usagePercent + 0.5)))
    if s.swap.totalMb and s.swap.totalMb > 0 then
      table.insert(lines, string.format("Swap %s of %s GiB", gib(s.swap.usedMb * 1048576), gib(s.swap.totalMb * 1048576)))
    end
    local gpuLine = `GPU  {pct(gpu.busy)}`
    if s.gpu.tempC then gpuLine ..= string.format("  ·  %d°C", s.gpu.tempC) end
    table.insert(lines, gpuLine)
  end
  if gpu.vramTotal then
    table.insert(lines, string.format("VRAM %s of %s GiB (dedicated)", gib(gpu.vramUsed), gib(gpu.vramTotal, 0)))
  end
  if gpu.gttTotal then
    table.insert(lines, string.format("GTT  %s of %s GiB (GPU use of system RAM)", gib(gpu.gttUsed), gib(gpu.gttTotal)))
  end
  barWidget.setTooltip(table.concat(lines, "\n"))
end

hover = pill.hoverState(render)

function update()
  noctalia.runAsync({ paths.state, "gpu" }, function(r)
    for k, v in string.gmatch(r.stdout, "([%w_]+)=([^\n]*)") do
      local n = tonumber(v)
      if k == "gpubusy" then gpu.busy = n end
      if k == "vramused" then gpu.vramUsed = n end
      if k == "vramtotal" then gpu.vramTotal = n end
      if k == "gttused" then gpu.gttUsed = n end
      if k == "gtttotal" then gpu.gttTotal = n end
    end
    render()
  end)
end

function onClick()
  noctalia.runAsync({ paths.noctalia, "msg", "panel-toggle", "control-center", "system" })
end

noctalia.setUpdateInterval(2000)
update()
