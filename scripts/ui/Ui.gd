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
	return l


static func button(text: String, color := Pal.ACCENT, size := Pal.FS, min_h := 112) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Pal.BG)
	b.add_theme_color_override("font_hover_color", Pal.BG)
	b.add_theme_color_override("font_pressed_color", Pal.BG)
	b.add_theme_color_override("font_disabled_color", Pal.MUTED)
	b.add_theme_stylebox_override("normal", box(color, 28))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 28))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 28))
	b.add_theme_stylebox_override("disabled", box(Pal.PANEL_HI, 28))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func panel(color := Pal.PANEL, radius := 28) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius))
	return p
