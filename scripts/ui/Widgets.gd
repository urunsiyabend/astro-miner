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
		var s := 30.0 * (1.0 + 0.35 * _pop)
		Widgets.draw_res_icon(self, c, s, res)
		var fs := Pal.FS
		var p := Vector2(82, size.y * 0.5 + fs * 0.36)
		draw_string_outline(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT.lerp(Pal.RES[res], _pop))


## This dig's haul in one small slot: the four gems and the total. Ore that is not a goal flies
## here; the slot then shows the gem that came in for a moment. Tap it for the breakdown.
## (Mobile puzzle HUDs keep the top bar for goals and moves; extras get one compact slot.)
class HaulChip extends Control:
	signal tapped
	var values := [0, 0, 0, 0]
	var _pop := 0.0
	var _last := -1
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(190, 76)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = ThemeDB.fallback_font

	func set_values(v: Array) -> void:
		for r in 4:
			if v[r] > values[r]:
				_last = r
				_pop = 1.0
		values = v.duplicate()
		queue_redraw()

	func total() -> int:
		var t := 0
		for x in values:
			t += x
		return t

	func icon_global() -> Vector2:
		return get_global_transform_with_canvas() * _icon_c()

	func _icon_c() -> Vector2:
		return Vector2(44, size.y * 0.5)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			tapped.emit()
			accept_event()

	func _process(delta: float) -> void:
		if _pop > 0.0:
			_pop = maxf(0.0, _pop - delta * 1.2)
			queue_redraw()

	func _draw() -> void:
		var c := _icon_c()
		if _pop > 0.0 and _last >= 0:
			# the gem that just came in, popping
			Widgets.draw_res_icon(self, c, 26.0 * (1.0 + 0.3 * minf(1.0, _pop * 2.0)), _last)
		else:
			for r in 4:
				var o := Vector2(-17 if r % 2 == 0 else 17, -16 if r < 2 else 16)
				Widgets.draw_res_icon(self, c + o, 15.0, r)
		var fs := Pal.FS
		var p := Vector2(88, size.y * 0.5 + fs * 0.36)
		var txt := str(total())
		draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT.lerp(Pal.RES[maxi(_last, 0)], minf(1.0, _pop * 2.0)))


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
		# starts at 60% of the room and grows to full with Power Station upgrades
		var w := full_w * (0.6 + 0.4 * float(capacity - 20) / (max_capacity - 20))
		var r := Rect2(Vector2(80, 8), Vector2(w, h))
		var frac := clampf(float(energy) / maxf(1.0, capacity), 0.0, 1.0)
		var col := Pal.GOOD if frac > 0.4 else (Pal.WARN if frac > 0.2 else Pal.BAD)
		col = col.lerp(Color.WHITE, _flash * 0.6)
		const K := 0.6  # battery art scale for a 54 px bar
		var inner := r.grow(-6)
		if Art.draw(self, "battery", r, Color.WHITE, K):
			inner = Art.face("battery", r, K).grow(-3)
		else:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(14)
			sb.bg_color = Pal.PANEL_HI
			sb.border_color = Pal.LINE
			sb.set_border_width_all(3)
			draw_style_box(sb, r)
		if energy > 0:
			var fr := Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * frac), inner.size.y))
			if not Art.draw(self, "bar_fill_base", fr, col, inner.size.y / 61.0):
				var f := StyleBoxFlat.new()
				f.set_corner_radius_all(11)
				f.bg_color = col
				draw_style_box(f, fr)
		# one tick per energy unit
		for i in range(1, capacity):
			var x := inner.position.x + inner.size.x * i / capacity
			draw_line(Vector2(x, inner.position.y + 4), Vector2(x, inner.end.y - 4), Color(0, 0, 0, 0.18), 2.0)
		Widgets.draw_bolt(self, Vector2(38, size.y * 0.5), 24, col)
		var txt := "%d/%d" % [energy, capacity]
		var tp := Vector2(r.end.x + 16, size.y * 0.5 + Pal.FS * 0.36)
		draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS, 8, Color("2a1830"))
		draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS, Pal.TEXT)


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
		draw_string_outline(_font, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Pal.OUTLINE)
		draw_string(_font, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.TEXT)
		var count := "%d / %d" % [have, need]
		var cw := _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, Vector2(size.x - cw, fs), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Pal.OUTLINE)
		draw_string(_font, Vector2(size.x - cw, fs), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.DIM)
		var r := Rect2(Vector2(0, fs + 12), Vector2(size.x, 12))
		draw_rect(r, Pal.PANEL_HI)
		draw_rect(Rect2(r.position, Vector2(r.size.x * float(have) / need, r.size.y)), Pal.GOOD if done else color)


## Objectives as big icons with counters, right above the board where the eyes are.
## Collected ore flies into the matching icon (see icon_global).
class GoalStrip extends Control:
	var goals: Array = []
	var have: Array = []
	var _pop: Array = []
	var big := false
	var _font: Font

	func _init(large := false) -> void:
		big = large
		custom_minimum_size = Vector2(0, 230 if large else 160)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_goals(g: Array) -> void:
		goals = g
		have = []
		_pop = []
		for i in g.size():
			have.append(0)
			_pop.append(0.0)
		queue_redraw()

	func set_have(i: int, v: int) -> void:
		v = mini(v, goals[i].n)
		if v != have[i]:
			_pop[i] = 1.0
		have[i] = v
		queue_redraw()

	func icon_global(i: int) -> Vector2:
		return get_global_transform_with_canvas() * _icon_pos(i)

	func _slot_w() -> float:
		return size.x / maxf(1.0, goals.size())

	func _icon_pos(i: int) -> Vector2:
		var w := _slot_w()
		if big:
			return Vector2(w * (i + 0.5), size.y * 0.36)
		# icon + count are centred as one group in the face above the bar
		var top := _top_area(i)
		var txt := "%d/%d" % [goals[i].n, goals[i].n]
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS).x
		var group := _icon_size() * 2.0 + 14.0 + tw
		return Vector2(top.get_center().x - group * 0.5 + _icon_size(), top.get_center().y)

	func _slot(i: int) -> Rect2:
		var w := _slot_w()
		return Rect2(Vector2(w * i + 8, 4), Vector2(w - 16, size.y - 8))

	func _bar(i: int) -> Rect2:
		var face := Art.face("plate", _slot(i))
		return Rect2(Vector2(face.position.x + 16, face.end.y - 26), Vector2(face.size.x - 32, 20))

	## The part of the slot's face above its progress bar.
	func _top_area(i: int) -> Rect2:
		var face := Art.face("plate", _slot(i))
		return Rect2(face.position, Vector2(face.size.x, _bar(i).position.y - 6 - face.position.y))

	func _icon_size() -> float:
		if big:
			return 62.0
		# the icon art is ~1.9 s tall: keep it inside the area above the bar
		return minf(46.0, (_top_area(0).size.y - 4.0) / 1.9) if goals.size() > 0 else 46.0

	func _process(delta: float) -> void:
		var any := false
		for i in _pop.size():
			if _pop[i] > 0.0:
				_pop[i] = maxf(0.0, _pop[i] - delta * 3.0)
				any = true
		if any:
			queue_redraw()

	func _draw() -> void:
		var w := _slot_w()
		var s := _icon_size()
		for i in goals.size():
			var g: Dictionary = goals[i]
			var done: bool = have[i] >= g.n
			var c := _icon_pos(i)
			var col := Pal.GOOD if done else Pal.TEXT
			var slot := _slot(i)
			var tint := Color.WHITE.lerp(Pal.GOOD, 0.35) if done else Color.WHITE.lerp(Color(1.3, 1.3, 1.3), _pop[i])
			if not Art.draw(self, "plate", slot, tint):
				var sb := StyleBoxFlat.new()
				sb.set_corner_radius_all(26)
				sb.bg_color = Pal.PANEL.lerp(Pal.GOOD, 0.18) if done else Pal.PANEL
				sb.border_color = Pal.GOOD if done else Pal.LINE.lerp(Color.WHITE, _pop[i] * 0.6)
				sb.set_border_width_all(3)
				draw_style_box(sb, slot)
			Widgets.draw_goal_icon(self, c, s * (1.0 + 0.3 * _pop[i]), g)
			var fs := Pal.FS_BIG if big else Pal.FS
			var txt := ("x %d" % g.n) if big else ("%d/%d" % [have[i], g.n])
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := Vector2(c.x - tw * 0.5, size.y * 0.82) if big else Vector2(c.x + s + 14.0, c.y + fs * 0.36)
			draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
			draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			if not big:
				var bar := _bar(i)
				const K := 0.29  # bar art scale for a 20 px bar
				var frac: float = float(have[i]) / g.n
				if Art.draw(self, "bar_track", bar, Color.WHITE, K):
					var inner := Art.face("bar_track", bar, K)
					if frac > 0.0:
						var fr := Rect2(inner.position, Vector2(maxf(inner.size.y * 1.5, inner.size.x * frac), inner.size.y))
						Art.draw(self, "bar_fill_base", fr, Pal.GOOD if done else Pal.ACCENT, inner.size.y / 61.0)
				else:
					draw_rect(bar, Pal.PANEL_HI)
					draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Pal.GOOD if done else Pal.ACCENT)
			if done:
				var k := c + Vector2(s * 0.75, -s * 0.75)
				draw_circle(k, s * 0.38, Pal.GOOD)
				draw_polyline(PackedVector2Array([k + Vector2(-s * 0.18, 0), k + Vector2(-s * 0.04, s * 0.14), k + Vector2(s * 0.2, -s * 0.14)]), Pal.BG, 5.0, true)


## A cost as resource icons with numbers; red when the bank is short.
class CostRow extends Control:
	var cost: Array = []
	var bank: Array = [0, 0, 0, 0]
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(c: Array, b: Array) -> void:
		cost = c
		bank = b
		queue_redraw()

	func _draw() -> void:
		var x := 18.0
		for i in 4:
			if cost.is_empty() or cost[i] <= 0:
				continue
			Widgets.draw_res_icon(self, Vector2(x, size.y * 0.5), 15, i)
			var enough: bool = bank[i] >= cost[i]
			var t := str(cost[i])
			draw_string(_font, Vector2(x + 26, size.y * 0.5 + Pal.FS_SMALL * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS_SMALL, Pal.TEXT if enough else Pal.BAD)
			x += 50 + _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS_SMALL).x


## Building badge: the tool it gives the robot.
class BuildingIcon extends Control:
	var building := 0
	var level := 0

	func _init(b: int, px := 110.0) -> void:
		building = b
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.5
		draw_circle(c, s, Pal.PANEL_HI)
		draw_arc(c, s - 3, 0, TAU, 40, Pal.GOOD if level > 0 else Pal.LINE, 5.0, true)
		Widgets.draw_building_icon(self, c, s * 0.55, building, Pal.TEXT if level > 0 else Pal.DIM)


static func draw_goal_icon(ci: CanvasItem, c: Vector2, s: float, g: Dictionary) -> void:
	match g.type:
		"ore":
			draw_res_icon(ci, c, s * 0.8, g.ore)
		"crystal":
			draw_res_icon(ci, c, s * 0.85, 3)
		"rock":
			var rk := Art.rock(1, 1)
			if rk != null:
				ci.draw_texture_rect(rk, Rect2(c - Vector2(s, s) * 1.05, Vector2(s, s) * 2.1), false)
				return
			var pts := PackedVector2Array()
			for k in 8:
				var a := TAU * (k + 0.5) / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.85 + 0.08 * sin(k * 2.3)))
			ci.draw_colored_polygon(pts, Pal.ROCK[1])
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.6), c + Vector2(s * 0.1, -s * 0.05), c + Vector2(-s * 0.15, s * 0.3), c + Vector2(s * 0.05, s * 0.7)]), Pal.ROCK[3], 5.0, true)
		"blast":
			ci.draw_arc(c, s * 0.62, 0, TAU, 24, Pal.CHARGE, s * 0.22, true)
			ci.draw_circle(c, s * 0.24, Pal.CHARGE)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + d * s * 0.8, c + d * s * 1.0, Pal.CHARGE, 5.0, true)
		_:  # any ore
			draw_res_icon(ci, c + Vector2(0, -s * 0.32), s * 0.42, 2)
			draw_res_icon(ci, c + Vector2(-s * 0.42, s * 0.3), s * 0.42, 0)
			draw_res_icon(ci, c + Vector2(s * 0.42, s * 0.3), s * 0.42, 1)


static func draw_building_icon(ci: CanvasItem, c: Vector2, s: float, b: int, col: Color) -> void:
	match b:
		0:  # power station: battery with a bolt
			ci.draw_rect(Rect2(c - Vector2(s * 0.55, s * 0.85), Vector2(s * 1.1, s * 1.7)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 1.05), Vector2(s * 0.5, s * 0.2)), col)
			draw_bolt(ci, c, s * 0.6, Pal.BG)
		1:  # workshop: drill bit
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.35), Vector2(s * 0.8, s * 0.7)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.5), c + Vector2(s * 1.0, 0), c + Vector2(-s * 0.1, s * 0.5)]), col)
			for k in 3:
				var x := -s * 0.05 + k * s * 0.3
				ci.draw_line(c + Vector2(x, -s * 0.42 + k * s * 0.13), c + Vector2(x + s * 0.18, s * 0.42 - k * s * 0.13), Pal.BG, 4.0)
		_:  # lab: scanner dish
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.8, PI * 0.15, PI * 0.85, 16, col, 7.0, true)
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.45, PI * 0.2, PI * 0.8, 12, col, 6.0, true)
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.16, col)
			ci.draw_line(c + Vector2(0, s * 0.3), c + Vector2(0, s * 0.95), col, 6.0)


static func draw_res_icon(ci: CanvasItem, c: Vector2, s: float, res: int) -> void:
	var t := Art.ore(res)
	if t != null:
		# ore sprites share one canvas with the gem centred on its box, so every kind lands
		# on the same point and looks the same size (see tools/art/build_assets.py)
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 1.15, Vector2(s, s) * 2.3), false)
		return
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
