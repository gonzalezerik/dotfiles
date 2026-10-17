--!nonstrict
-- Shared Control Center building blocks. W.new(ctx) returns helpers bound to
-- the panel's hover state: ctx.hovered() is the key under the pointer and
-- ctx.hov(key) is an onHover handler that tracks it and re-renders.
--
-- Look: surface_variant cards with a faint outline; anything clickable gets
-- a muted-blue (primary) tint + outline under the pointer.

local icon = require("./icon.luau")

local W = {}

W.CARD_FILL = "surface_variant/0.55"
W.CARD_BORDER = "outline/0.45"

function W.new(ctx)
  local H = {}

  local function isLit(key)
    return key ~= nil and ctx.hovered() == key
  end
  H.isLit = isLit

  -- Round icon button.
  function H.iconButton(key, name, onClick, opts)
    opts = opts or {}
    local enabled = opts.enabled ~= false and onClick ~= nil
    local size = opts.size or 28
    local lit = enabled and isLit(key)
    return ui.row({
      key = key, width = size, height = size, radius = size / 2,
      align = "center", justify = "center",
      fill = if lit then "primary/0.20" elseif opts.fill then opts.fill else "surface_variant/0",
      opacity = if opts.enabled == false then 0.4 else 1,
      onClick = if enabled then onClick else nil,
      onHover = if enabled then ctx.hov(key) else nil,
    }, {
      icon.icon(name, opts.iconSize or 12, if lit then "primary" else (opts.color or "on_surface_variant"), opts.weight),
    })
  end

  -- Text button (pill), e.g. "Connect", "Disconnect".
  function H.textButton(key, text, onClick, opts)
    opts = opts or {}
    local lit = isLit(key)
    local strong = opts.primary
    return ui.row({
      key = key, paddingH = 12, height = 28, radius = 14, align = "center", justify = "center",
      fill = if strong then (if lit then "primary" else "primary/0.85")
             elseif lit then "primary/0.20" else "on_surface/0.08",
      border = if lit and not strong then "primary" else "surface_variant/0", borderWidth = 1,
      onClick = onClick, onHover = ctx.hov(key),
    }, {
      ui.label({ text = text, fontSize = 12, fontWeight = "medium",
                 color = if strong then "on_primary" elseif lit then "primary" else "on_surface" }),
    })
  end

  -- Card; clickable ones (props.hoverable) light up under the pointer.
  function H.card(props, children)
    local lit = props.hoverable and isLit(props.key)
    props.fill = props.fill or (if lit then "primary/0.14" else W.CARD_FILL)
    props.radius = props.radius or 16
    props.border = props.border or (if lit then "primary" else W.CARD_BORDER)
    props.borderWidth = props.borderWidth or 1
    props.padding = props.padding or 12
    if props.hoverable then
      props.onHover = ctx.hov(props.key)
    end
    props.hoverable = nil
    return ui.column(props, children)
  end

  -- Round glyph badge: solid primary when active.
  function H.circle(glyph, active, size, lit)
    size = size or 30
    return ui.row({
      width = size, height = size, radius = size / 2,
      fill = if active then "primary" elseif lit then "on_surface/0.22" else "on_surface/0.12",
      align = "center", justify = "center",
    }, {
      icon.icon(glyph, size * 0.42, if active then "on_primary" else "on_surface", if active then "heavy" else nil),
    })
  end

  function H.textStack(title, sub, opts)
    opts = opts or {}
    local kids = { ui.label({ text = title, fontSize = opts.titleSize or 13, fontWeight = "semibold", maxLines = 1 }) }
    if sub and sub ~= "" then
      table.insert(kids, ui.label({ text = sub, fontSize = 11, color = opts.subColor or "on_surface_variant", maxLines = 1 }))
    end
    return ui.column({ gap = 1, flexGrow = 1, justify = "center" }, kids)
  end

  -- List row inside a card: leading badge, title/sub, trailing controls.
  -- Whole row is the click target and highlights under the pointer;
  -- `selected` keeps a primary check mark on the right.
  function H.listRow(key, opts)
    local lit = isLit(key)
    local trailing = opts.trailing or {}
    if opts.selected then
      table.insert(trailing, 1, icon.icon("check", 12, "primary", "heavy"))
    end
    return ui.row({ key = key, gap = 8, align = "center", radius = 12, paddingH = 6, paddingV = 4,
                    fill = if lit then "primary/0.14" else "surface_variant/0" }, {
      ui.row({ gap = 10, align = "center", flexGrow = 1, onClick = opts.onClick,
               onHover = if opts.onClick then ctx.hov(key) else nil }, {
        H.circle(opts.glyph, opts.active, opts.badgeSize or 28, lit),
        H.textStack(opts.title, opts.sub, { subColor = opts.subColor }),
      }),
      ui.row({ gap = 4, align = "center" }, trailing),
    })
  end

  function H.section(text)
    return ui.label({ text = text, fontSize = 11, fontWeight = "semibold", color = "on_surface_variant" })
  end

  -- Slider line: [glyph button] ─────●──── 56%
  function H.sliderLine(key, glyph, value, onGlyph, onChange, onEnd, opts)
    opts = opts or {}
    return ui.row({ gap = 8, align = "center" }, {
      H.iconButton(key .. "-glyph", glyph, onGlyph, { iconSize = 13, color = opts.glyphColor or "primary" }),
      ui.slider({ min = 0, max = opts.max or 100, step = 1, value = value, flexGrow = 1, controlSize = "sm",
                  onChange = onChange, onDragEnd = onEnd }),
      ui.label({ text = `{math.floor(value + 0.5)}%`, fontSize = 11, color = "on_surface_variant", width = 34, textAlign = "end" }),
    })
  end

  -- Page header: back arrow, title, optional right-hand actions.
  function H.pageHeader(title, onBack, actions)
    local kids = {
      H.iconButton("hdr-back", "chevron-left", onBack, { color = "on_surface", iconSize = 13 }),
      ui.label({ text = title, fontSize = 15, fontWeight = "bold", flexGrow = 1 }),
    }
    for _, a in ipairs(actions or {}) do
      table.insert(kids, a)
    end
    return ui.row({ gap = 6, align = "center" }, kids)
  end

  function H.note(text, color)
    return ui.label({ text = text, fontSize = 11, color = color or "on_surface_variant", maxLines = 3 })
  end

  return H
end

return W
