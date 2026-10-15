class_name ColonyView
extends Control

## Custom-drawn colony skyline. Each building visibly grows with its level.

var levels := [0, 0, 0]
var _time := 0.0
var _celebrate := [0.0, 0.0, 0.0]
var _stars := []


func _ready() -> void:
	custom_minimum_size = Vector2(0, 520)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.6, rng.randf_range(1.5, 3.5)))


func set_levels(l: Array, celebrate := -1) -> void:
	levels = l.duplicate()
	if celebrate >= 0:
		_celebrate[celebrate] = 1.0
	queue_redraw()


func building_global(b: int) -> Vector2:
	return get_global_transform_with_canvas() * _slot(b)


func _slot(b: int) -> Vector2:
	var xs := [0.18, 0.82, 0.5]
	return Vector2(size.x * xs[b], size.y * 0.78)


func _process(delta: float) -> void:
	_time += delta
	for i in 3:
		_celebrate[i] = maxf(0.0, _celebrate[i] - delta)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# sky
	for i in 12:
		var t := i / 12.0
		draw_rect(Rect2(0, h * t, w, h / 12.0 + 1), Color("1a0f2b").lerp(Color("3b1d3d"), t))
	for s in _stars:
		var a := 0.4 + 0.4 * sin(_time * s.z + s.x * 20.0)
		draw_circle(Vector2(s.x * w, s.y * h), s.z, Color(1, 1, 1, a))
	# ringed gas giant
	var pc := Vector2(w * 0.8, h * 0.2)
	draw_circle(pc, 70, Color("e07a5f"))
	draw_circle(pc + Vector2(-18, -14), 50, Color("f2a07b"))
	draw_arc(pc, 110, -0.35, PI - 0.35, 40, Color(1, 0.85, 0.7, 0.55), 6.0, true)
	# ground
	var gy := h * 0.78
	var pts := PackedVector2Array([Vector2(0, h)])
	for i in 13:
		var x := w * i / 12.0
		pts.append(Vector2(x, gy - 18 + 14 * sin(i * 1.7)))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, Color("5a3a52"))
	draw_rect(Rect2(0, gy + 20, w, h - gy), Color("4a2e45"))
	# habitat dome (grows lights with total colony level)
	var total: int = levels[0] + levels[1] + levels[2]
	var hc := Vector2(w * 0.5, gy - 150)
	_power(_slot(0), levels[0])
	_workshop(_slot(1), levels[1])
	_lab(_slot(2), levels[2])
	draw_arc(hc, 92, PI, TAU, 40, Color(0.6, 0.9, 1.0, 0.0), 1.0)
	for i in 3:
		if _celebrate[i] > 0.0:
			var c := _slot(i) + Vector2(0, -90)
			draw_arc(c, 60 + (1.0 - _celebrate[i]) * 160, 0, TAU, 40, Color(Pal.GOOD, _celebrate[i]), 8.0, true)
	var lbl := "Colony level %d / 9" % total
	var f := ThemeDB.fallback_font
	draw_string_outline(f, Vector2(24, 48), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS_SMALL, 6, Pal.OUTLINE)
	draw_string(f, Vector2(24, 48), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS_SMALL, Pal.DIM)


func _blueprint(c: Vector2, sz: Vector2) -> void:
	var r := Rect2(c - Vector2(sz.x * 0.5, sz.y), sz)
	var col := Color(Pal.ACCENT, 0.45)
	var n := 14
	for i in n:
		if i % 2 == 0:
			var a := r.position + Vector2(r.size.x * i / n, 0)
			draw_line(a, a + Vector2(r.size.x / n, 0), col, 3.0)
			draw_line(a + Vector2(0, r.size.y), a + Vector2(r.size.x / n, r.size.y), col, 3.0)
	for i in 8:
		if i % 2 == 0:
			var a := r.position + Vector2(0, r.size.y * i / 8)
			draw_line(a, a + Vector2(0, r.size.y / 8), col, 3.0)
			draw_line(a + Vector2(r.size.x, 0), a + Vector2(r.size.x, r.size.y / 8), col, 3.0)


func _power(c: Vector2, lv: int) -> void:
	if lv == 0:
		_blueprint(c, Vector2(170, 110))
		return
	# reactor block + one solar panel per level
	draw_rect(Rect2(c + Vector2(-60, -100), Vector2(120, 100)), Color("3f4e6b"))
	draw_rect(Rect2(c + Vector2(-60, -100), Vector2(120, 14)), Color("5f7396"))
	var glow := 0.6 + 0.4 * sin(_time * 3.0)
	draw_circle(c + Vector2(0, -50), 22 + lv * 2, Color(Pal.GOOD, glow))
	for i in lv:
		var px := c.x - 150 + i * 100 if i < 2 else c.x + 70
		var base := Vector2(px if i < 2 else c.x + 70, c.y)
		if i == 0:
			base = Vector2(c.x - 140, c.y)
		elif i == 1:
			base = Vector2(c.x + 100, c.y)
		else:
			base = Vector2(c.x, c.y - 100)
		draw_line(base, base + Vector2(0, -50), Color("8892a6"), 6.0)
		var panel := PackedVector2Array([base + Vector2(-46, -50), base + Vector2(46, -50), base + Vector2(34, -80), base + Vector2(-34, -80)])
		draw_colored_polygon(panel, Color("2b6cb0"))
		draw_polyline(panel + PackedVector2Array([panel[0]]), Color("90cdf4"), 3.0)


func _workshop(c: Vector2, lv: int) -> void:
	if lv == 0:
		_blueprint(c, Vector2(170, 120))
		return
	draw_rect(Rect2(c + Vector2(-80, -90), Vector2(160, 90)), Color("6b4f3a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-90, -90), c + Vector2(90, -90), c + Vector2(60, -125), c + Vector2(-60, -125)]), Color("8a6a4f"))
	draw_rect(Rect2(c + Vector2(-30, -60), Vector2(60, 60)), Color("2a1f17"))
	# drill rig tower: taller per level, spinning gear
	var top := c + Vector2(110, -90 - lv * 45)
	draw_line(c + Vector2(95, 0), top, Color("c9a227"), 8.0)
	draw_line(c + Vector2(125, 0), top, Color("c9a227"), 8.0)
	var a := _time * 2.0
	for k in 6:
		var d := Vector2(cos(a + k * TAU / 6), sin(a + k * TAU / 6))
		draw_line(top, top + d * 26, Pal.WARN, 8.0)
	draw_circle(top, 14, Color("ffd166"))
	if lv >= 3:
		draw_circle(c + Vector2(-50, -110), 10, Pal.WARN)


func _lab(c: Vector2, lv: int) -> void:
	if lv == 0:
		_blueprint(c, Vector2(180, 130))
		return
	var r := 70.0 + lv * 10.0
	draw_circle(c, r, Color("9ad1d4"), true)
	draw_rect(Rect2(c + Vector2(-r, 0), Vector2(r * 2, r)), Color("4a2e45"))
	draw_arc(c, r, PI, TAU, 40, Color("e0fbfc"), 5.0, true)
	for i in lv:
		draw_circle(c + Vector2(-r * 0.5 + i * r * 0.5, -r * 0.45), 9, Color(Pal.ACCENT, 0.6 + 0.4 * sin(_time * 4.0 + i)))
	# dish antenna
	var base := c + Vector2(0, -r)
	draw_line(base, base + Vector2(0, -40), Color("d9e2ec"), 6.0)
	var dish := base + Vector2(0, -48)
	var ang := sin(_time * 0.7) * 0.6
	draw_arc(dish, 30 + lv * 6, PI + ang - 1.0, PI + ang + 1.0, 20, Color("d9e2ec"), 8.0, true)
	if lv >= 2:
		var beam := Color(Pal.ACCENT, 0.18 + 0.1 * sin(_time * 5.0))
		draw_colored_polygon(PackedVector2Array([dish, dish + Vector2(-80, -170).rotated(ang), dish + Vector2(80, -170).rotated(ang)]), beam)
