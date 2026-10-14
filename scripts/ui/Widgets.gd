class_name Widgets
extends RefCounted

## Tiny custom-drawn HUD widgets.


## Resource icon + count. Pops when the value changes.
class Chip extends Control:
	var res := 0
	var value := 0
	var _pop := 0.0
	var _font: Font

	func _init(r: int) -> void:
		res = r
		custom_minimum_size = Vector2(180, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_value(v: int) -> void:
		if v != value:
			_pop = 1.0
		value = v
		queue_redraw()

	func icon_global() -> Vector2:
		return get_global_transform_with_canvas() * Vector2(38, size.y * 0.5)

	func _process(delta: float) -> void:
		if _pop > 0.0:
			_pop = maxf(0.0, _pop - delta * 4.0)
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(38, size.y * 0.5)
		var s := 20.0 * (1.0 + 0.35 * _pop)
		Widgets.draw_res_icon(self, c, s, res)
		var fs := Pal.FS
		draw_string(_font, Vector2(72, size.y * 0.5 + fs * 0.36), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Pal.TEXT.lerp(Pal.RES[res], _pop))


## Battery bar whose length grows with capacity, so Power Station upgrades are visible.
class EnergyBar extends Control:
	var energy := 20
	var capacity := 20
	var max_capacity := 40
	var _flash := 0.0
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_energy(e: int, cap: int) -> void:
		if e > energy:
			_flash = 1.0
		energy = e
		capacity = cap
		queue_redraw()

	func target_global() -> Vector2:
		return get_global_transform_with_canvas() * Vector2(40, size.y * 0.5)

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 3.0)
			queue_redraw()

	func _draw() -> void:
		var h := size.y - 16
		var full_w := size.x - 210
		var w := full_w * float(capacity) / max_capacity
		var r := Rect2(Vector2(80, 8), Vector2(w, h))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.bg_color = Pal.PANEL_HI
		sb.border_color = Pal.LINE
		sb.set_border_width_all(3)
		draw_style_box(sb, r)
		var frac := clampf(float(energy) / maxf(1.0, capacity), 0.0, 1.0)
		var col := Pal.GOOD if frac > 0.4 else (Pal.WARN if frac > 0.2 else Pal.BAD)
		col = col.lerp(Color.WHITE, _flash * 0.6)
		if energy > 0:
			var f := StyleBoxFlat.new()
			f.set_corner_radius_all(11)
			f.bg_color = col
			draw_style_box(f, Rect2(r.position + Vector2(5, 5), Vector2((r.size.x - 10) * frac, r.size.y - 10)))
		# one tick per energy unit
		for i in range(1, capacity):
			var x := r.position.x + 5 + (r.size.x - 10) * i / capacity
			draw_line(Vector2(x, r.position.y + 8), Vector2(x, r.end.y - 8), Color(0, 0, 0, 0.18), 2.0)
		Widgets.draw_bolt(self, Vector2(38, size.y * 0.5), 24, col)
		var txt := "%d/%d" % [energy, capacity]
		draw_string(_font, Vector2(r.end.x + 16, size.y * 0.5 + Pal.FS * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS, Pal.TEXT)


## One objective with a progress bar.
class GoalRow extends Control:
	var text := ""
	var have := 0
	var need := 1
	var color := Pal.ACCENT
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(t: String, n: int, c: Color) -> void:
		text = t
		need = n
		color = c
		queue_redraw()

	func set_have(v: int) -> void:
		have = mini(v, need)
		queue_redraw()

	func _draw() -> void:
		var done := have >= need
		var fs := Pal.FS_SMALL
		draw_string(_font, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.TEXT)
		var count := "%d / %d" % [have, need]
		var cw := _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(size.x - cw, fs), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.DIM)
		var r := Rect2(Vector2(0, fs + 12), Vector2(size.x, 12))
		draw_rect(r, Pal.PANEL_HI)
		draw_rect(Rect2(r.position, Vector2(r.size.x * float(have) / need, r.size.y)), Pal.GOOD if done else color)


static func draw_res_icon(ci: CanvasItem, c: Vector2, s: float, res: int) -> void:
	var col: Color = Pal.RES[res]
	match res:
		0:
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col)
		1:
			ci.draw_circle(c, s, col)
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.8, -s * 0.2), c + Vector2(0, s * 1.1), c + Vector2(-s * 0.8, -s * 0.2)]), col)


static func draw_bolt(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.1), c + Vector2(-s * 0.05, s * 0.1),
		c + Vector2(-s * 0.2, s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.05, -s * 0.1)]), col)
