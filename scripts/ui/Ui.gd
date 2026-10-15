class_name Ui
extends RefCounted

## Small factory for consistently styled controls.


static func box(bg: Color, radius := 22, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


static func label(text: String, size := Pal.FS, color := Pal.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outline(l, 6 if size < Pal.FS else 8)
	return l


## Dark outline so text reads on painted art and on the sky. Every Ui.label gets one.
static func outline(l: Label, px := 8) -> void:
	l.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	l.add_theme_constant_override("outline_size", px)


static func button(text: String, color := Pal.ACCENT, size := Pal.FS, min_h := 112) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	paint_button(b, color)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Give a button the painted art for `color` (falls back to flat boxes without the art).
## White text with a dark outline reads on every button colour.
static func paint_button(b: Button, color: Color) -> void:
	var art := Art.button_style(color)
	if art == null:
		b.add_theme_color_override("font_color", Pal.BG)
		b.add_theme_color_override("font_hover_color", Pal.BG)
		b.add_theme_color_override("font_pressed_color", Pal.BG)
		b.add_theme_color_override("font_disabled_color", Pal.MUTED)
		b.add_theme_stylebox_override("normal", box(color, 28))
		b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 28))
		b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 28))
		b.add_theme_stylebox_override("disabled", box(Pal.PANEL_HI, 28))
		return
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, Art.button_style(color, st))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Pal.DIM)
	b.add_theme_color_override("font_outline_color", Color("2a1830"))
	b.add_theme_constant_override("outline_size", 10)


## A framed panel: the painted panel art ("panel"), or the lighter "plate" for slim bars.
static func panel(color := Pal.PANEL, radius := 28, piece := "panel") -> PanelContainer:
	var p := PanelContainer.new()
	var art := Art.style(piece)
	p.add_theme_stylebox_override("panel", art if art != null else box(color, radius))
	return p
