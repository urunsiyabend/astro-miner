class_name Art
extends RefCounted

## Painted art and how it maps onto the game (see docs/art/art-direction.md). Everything that
## places a texture goes through here, using the numbers tools/art/build_assets.py measured
## (UiMetrics), so alignment never depends on eyeballed offsets.
## When a texture is missing the callers fall back to the code-drawn look.

## Resource index (board ore type 0-3, then 4 = crystal) -> assets/ore/<name>.png
const ORE := ["ferrite", "cryo", "lumen", "ruby", "crystal"]
const ROCK := ["boulder", "stone", "basalt"]  # starting layers 1, 2, 3
## Visible share of the earth band under each row: rows sit this much further apart than
## columns, so every block shows a strip of its thickness (the floating-island look).
const BAND_VISIBLE := 0.0
## Extra room around a UI face for text and icons, in screen pixels: [x, y].
const PAD := Vector2(18, 2)

static var _tex := {}


static func clear_cache() -> void:
	_tex.clear()


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Planet whose tileset the board uses: "" = the first planet (assets/tiles/), otherwise
## assets/tiles/<planet>/. A missing tile falls back to the first planet's.
static var planet := ""


static func tile(name: String) -> Texture2D:
	if planet != "":
		var t := tex("res://assets/tiles/%s/%s.png" % [planet, name])
		if t != null:
			return t
	return tex("res://assets/tiles/%s.png" % name)


static func has_tiles() -> bool:
	return tile("soil_a") != null


static func ore(kind: int) -> Texture2D:
	return tex("res://assets/ore/%s.png" % ORE[kind]) if kind >= 0 and kind < ORE.size() else null


## Rock sprite for a rock that started with `layers` and has `left` layers now: the form shows
## how tough it is, the break state how much of it is gone (3 layers: intact, cracked, crumbling;
## 2 layers: intact, crumbling; 1 layer: intact).
static func rock(layers: int, left: int) -> Texture2D:
	var form := clampi(layers, 1, 3) - 1
	var lost := clampi(layers - left, 0, 2)
	var state := lost if layers == 3 else (2 if lost > 0 else 0)
	return tex("res://assets/rocks/%s_%d.png" % [ROCK[form], state])


static func background() -> Texture2D:
	return tex("res://assets/bg/space.jpg")



## A 9-slice box from a UI piece. The control's rect is the whole art; its content area is the
## visible face (outline, top highlight and bottom lip excluded) plus PAD, so a label or icon in
## a Button/PanelContainer centres on what the eye sees.
static func style(piece: String, tint := Color.WHITE) -> StyleBox:
	var t := tex("res://assets/ui/%s.png" % piece)
	if t == null or not UiMetrics.DATA.has(piece):
		return null
	var m: Dictionary = UiMetrics.DATA[piece]
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = m.slice[0]
	s.texture_margin_top = m.slice[1]
	s.texture_margin_right = m.slice[2]
	s.texture_margin_bottom = m.slice[3]
	s.content_margin_left = m.face[0] + PAD.x
	s.content_margin_top = m.face[1] + PAD.y
	s.content_margin_right = m.face[2] + PAD.x
	s.content_margin_bottom = m.face[3] + PAD.y
	s.modulate_color = tint
	return s


## Button art for a palette colour: the painted teal and orange buttons for the two main
## colours, the grey base piece tinted for any other, so every button shares one shape.
static func button_style(color: Color, state := "normal") -> StyleBox:
	var piece := "button_base"
	var tint := color
	if color == Pal.ACCENT:
		piece = "button_teal"
		tint = Color.WHITE
	elif color == Pal.WARN:
		piece = "button_orange"
		tint = Color.WHITE
	match state:
		"hover": tint = tint.lightened(0.08)
		"pressed": tint = tint.darkened(0.18)
		"disabled":
			piece = "button_base"
			tint = Pal.PANEL_HI.lightened(0.15)
	return style(piece, tint)


## Draw a 9-slice piece into any rect of a CanvasItem (bars, slots). `k` scales the art
## (corners, borders) for rects smaller than the art's own margins, e.g. a thin goal bar.
## Uses the canvas transform, so call it from controls that don't set their own.
static func draw(ci: CanvasItem, piece: String, r: Rect2, tint := Color.WHITE, k := 1.0) -> bool:
	var s := style(piece, tint)
	if s == null:
		return false
	if is_equal_approx(k, 1.0):
		ci.draw_style_box(s, r)
	else:
		ci.draw_set_transform(r.position, 0.0, Vector2(k, k))
		ci.draw_style_box(s, Rect2(Vector2.ZERO, r.size / k))
		ci.draw_set_transform(Vector2.ZERO)
	return true


## Face rect of a piece drawn into `r` at scale `k`: where a fill or label goes in the frame.
static func face(piece: String, r: Rect2, k := 1.0) -> Rect2:
	if not UiMetrics.DATA.has(piece):
		return r
	var f: Array = UiMetrics.DATA[piece].face
	return Rect2(r.position + Vector2(f[0], f[1]) * k, r.size - Vector2(f[0] + f[2], f[1] + f[3]) * k)
