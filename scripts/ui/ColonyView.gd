class_name ColonyView
extends Control

## The colony map (GDD v3 §4): a habitat dome in the middle, walkways out to the plots around
## it (Colony.PLOTS). A building stands on its plot once its star milestone unlocks it; a
## decoration appears when its cosmetic milestone is reached; plots still to come show a dashed
## outline and the stars they need. Every plot is a tap target (plot_tapped), which the colony
## screen turns into a building card, and which the onboarding spotlight can point at.
## The drawing is placeholder art until the colony sprites are made.

signal plot_tapped(i: int)

const GROUND := Color("40275e")
const GROUND_HI := Color("5a3a80")
const WALK := Color("8a6aa8")

var levels := [0, 0, 0]
var star := 0
var _time := 0.0
var _pop := {}       # plot index -> remaining celebration time (s)
var _buttons := []   # one invisible Button per plot
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(0, 760)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = ThemeDB.fallback_font
	for i in Colony.PLOTS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func(): plot_tapped.emit(i))
		add_child(b)
		_buttons.append(b)
	resized.connect(_layout)


func set_state(l: Array, s: int) -> void:
	levels = l.duplicate()
	star = s
	queue_redraw()


func celebrate(i: int) -> void:
	if i >= 0:
		_pop[i] = 1.2


func plot_center(i: int) -> Vector2:
	var p: Vector2 = Colony.PLOTS[i].pos
	return Vector2(size.x * p.x, size.y * p.y)


func plot_global(i: int) -> Vector2:
	return get_global_transform_with_canvas() * plot_center(i)


func plot_button(i: int) -> Button:
	return _buttons[i] if i >= 0 and i < _buttons.size() else null


func building_global(b: int) -> Vector2:
	return plot_global(Colony.building_plot(b))


func _plot_size() -> float:
	return minf(size.x * 0.34, size.y * 0.24)


func _layout() -> void:
	var s := _plot_size()
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		btn.position = plot_center(i) - Vector2(s, s) * 0.5
		btn.size = Vector2(s, s)


func _process(delta: float) -> void:
	_time += delta
	for k in _pop.keys():
		_pop[k] -= delta
		if _pop[k] <= 0.0:
			_pop.erase(k)
	queue_redraw()


## What stands on plot i right now: "built", "due" (unlocked building not built yet), "locked".
func plot_state(i: int) -> String:
	var plot: Dictionary = Colony.PLOTS[i]
	if plot.has("building"):
		var b: int = plot.building
		if levels[b] > 0:
			return "built"
		return "due" if star >= Economy.STAR_UNLOCK[b] else "locked"
	return "built" if star >= Colony.plot_stars(i) else "locked"


func _draw() -> void:
	var w := size.x
	var h := size.y
	var s := _plot_size()
	# planet ground: a soft plateau, lighter toward the middle
	var c := Vector2(w * 0.5, h * 0.48)
	for k in 6:
		var t := k / 5.0
		var rx := w * (0.50 - 0.07 * t)
		var ry := h * (0.47 - 0.06 * t)
		draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx, GROUND.lerp(GROUND_HI, t), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
	# walkways from the dome to every filled plot
	var dome := Vector2(w * Colony.DOME.x, h * Colony.DOME.y)
	for i in Colony.PLOTS.size():
		if plot_state(i) == "built":
			draw_line(dome, plot_center(i), WALK.darkened(0.35), s * 0.16, true)
			draw_line(dome, plot_center(i), WALK, s * 0.11, true)
	_dome(dome, s)
	for i in Colony.PLOTS.size():
		_plot(i, s)


func _plot(i: int, s: float) -> void:
	var c := plot_center(i)
	var plot: Dictionary = Colony.PLOTS[i]
	var st := plot_state(i)
	var pop: float = _pop.get(i, 0.0)
	if pop > 0.0:
		draw_arc(c, s * (0.4 + (1.2 - pop) * 0.6), 0, TAU, 48, Color(Pal.GOOD, pop / 1.2), 8.0, true)
	if st == "locked":
		_dashed_plot(c, s * 0.62, Color(1, 1, 1, 0.35))
		_label(c + Vector2(0, s * 0.06), "%d★" % Colony.plot_stars(i), Pal.FS, Pal.STAR)
		return
	if st == "due":
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		_dashed_plot(c, s * 0.62, Color(Pal.GOOD, 0.6 + 0.4 * pulse))
		_label(c + Vector2(0, s * 0.06), "BUILD", Pal.FS, Pal.GOOD)
		return
	# built: placeholder building / decoration, base at the bottom of the plot
	var base := c + Vector2(0, s * 0.30)
	var k := s / 260.0
	draw_set_transform(base, 0.0, Vector2(k, k))
	match plot.id:
		"power": _power(Vector2.ZERO, levels[0])
		"workshop": _workshop(Vector2.ZERO, levels[1])
		"lab": _lab(Vector2.ZERO, levels[2])
		"pad": _pad(Vector2.ZERO)
		"greenhouse": _greenhouse(Vector2.ZERO)
		"antenna": _antenna(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	if plot.has("building"):
		var bc := c + Vector2(s * 0.36, s * 0.28)
		draw_circle(bc, s * 0.11, Pal.OUTLINE, true, -1.0, true)
		draw_circle(bc, s * 0.095, Pal.PANEL_HI, true, -1.0, true)
		_label(bc + Vector2(0, Pal.FS_SMALL * 0.36), str(levels[plot.building]), Pal.FS_SMALL, Pal.TEXT)


func _label(p: Vector2, t: String, fs: int, col: Color) -> void:
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := p - Vector2(tw * 0.5, 0)
	draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
	draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _dashed_plot(c: Vector2, half: float, col: Color) -> void:
	var r := Rect2(c - Vector2(half, half * 0.62), Vector2(half * 2, half * 1.24))
	draw_rect(r, Color(col, col.a * 0.15))
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in 4:
		var a: Vector2 = pts[e]
		var b: Vector2 = pts[(e + 1) % 4]
		var n := int(a.distance_to(b) / 18.0)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 4.0, true)


func _dome(c: Vector2, s: float) -> void:
	var r := s * 0.42
	draw_circle(c + Vector2(0, r * 0.25), r * 1.05, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-r * 1.05, r * 0.05), Vector2(r * 2.1, r * 0.3)), Color("6d7894"))
	draw_circle(c, r, Color(0.62, 0.88, 1.0, 0.55), true, -1.0, true)
	draw_arc(c, r, PI, TAU, 40, Color("e0fbfc"), 5.0, true)
	draw_arc(c + Vector2(-r * 0.25, -r * 0.2), r * 0.55, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.7), 5.0, true)
	for i in 3:
		draw_circle(c + Vector2((i - 1) * r * 0.45, r * 0.1), r * 0.08, Color(Pal.WARN, 0.6 + 0.4 * sin(_time * 3.0 + i)), true, -1.0, true)


func _pad(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(-110, -10), c + Vector2(110, -10), c + Vector2(85, -70), c + Vector2(-85, -70)])
	draw_colored_polygon(pts, Color("6d7894"))
	draw_arc(c + Vector2(0, -40), 34, 0, TAU, 32, Pal.WARN, 6.0, true)
	draw_rect(Rect2(c + Vector2(-26, -110), Vector2(52, 48)), Color("e9f6ff"))
	draw_circle(c + Vector2(-10, -88), 7, Pal.ACCENT, true, -1.0, true)
	draw_circle(c + Vector2(10, -88), 7, Pal.ACCENT, true, -1.0, true)


func _greenhouse(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-100, -30), Vector2(200, 30)), Color("6d7894"))
	var half := PackedVector2Array()
	for k in 25:
		var a := PI + PI * k / 24.0
		half.append(c + Vector2(0, -30) + Vector2(cos(a), sin(a)) * 90)
	draw_colored_polygon(half, Color(0.55, 1.0, 0.65, 0.45))
	draw_arc(c + Vector2(0, -30), 90, PI, TAU, 40, Color("e0fbfc"), 5.0, true)
	for k in 4:
		draw_circle(c + Vector2(-54 + k * 36, -55), 16, Color("3fbf6a"), true, -1.0, true)


func _antenna(c: Vector2) -> void:
	draw_line(c, c + Vector2(0, -170), Color("d9e2ec"), 10.0, true)
	draw_line(c + Vector2(-50, 0), c + Vector2(0, -110), Color("8892a6"), 6.0, true)
	draw_line(c + Vector2(50, 0), c + Vector2(0, -110), Color("8892a6"), 6.0, true)
	var ang := sin(_time * 0.8) * 0.5
	draw_arc(c + Vector2(0, -180), 50, PI + ang - 1.0, PI + ang + 1.0, 20, Color("d9e2ec"), 10.0, true)
	draw_circle(c + Vector2(0, -200), 9, Color(Pal.BAD, 0.5 + 0.5 * sin(_time * 5.0)), true, -1.0, true)


func _power(c: Vector2, lv: int) -> void:
	# reactor block + one solar panel per level
	draw_rect(Rect2(c + Vector2(-60, -100), Vector2(120, 100)), Color("3f4e6b"))
	draw_rect(Rect2(c + Vector2(-60, -100), Vector2(120, 14)), Color("5f7396"))
	var glow := 0.6 + 0.4 * sin(_time * 3.0)
	draw_circle(c + Vector2(0, -50), 22 + lv * 2, Color(Pal.GOOD, glow), true, -1.0, true)
	for i in lv:
		var base := Vector2(c.x - 120, c.y) if i == 0 else (Vector2(c.x + 120, c.y) if i == 1 else Vector2(c.x, c.y - 100))
		draw_line(base, base + Vector2(0, -50), Color("8892a6"), 6.0)
		var panel := PackedVector2Array([base + Vector2(-46, -50), base + Vector2(46, -50), base + Vector2(34, -80), base + Vector2(-34, -80)])
		draw_colored_polygon(panel, Color("2b6cb0"))
		draw_polyline(panel + PackedVector2Array([panel[0]]), Color("90cdf4"), 3.0)


func _workshop(c: Vector2, lv: int) -> void:
	draw_rect(Rect2(c + Vector2(-80, -90), Vector2(160, 90)), Color("6b4f3a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-90, -90), c + Vector2(90, -90), c + Vector2(60, -125), c + Vector2(-60, -125)]), Color("8a6a4f"))
	draw_rect(Rect2(c + Vector2(-30, -60), Vector2(60, 60)), Color("2a1f17"))
	# drill rig tower: taller per level, spinning gear
	var top := c + Vector2(110, -90 - lv * 35)
	draw_line(c + Vector2(95, 0), top, Color("c9a227"), 8.0)
	draw_line(c + Vector2(125, 0), top, Color("c9a227"), 8.0)
	var a := _time * 2.0
	for k in 6:
		var d := Vector2(cos(a + k * TAU / 6), sin(a + k * TAU / 6))
		draw_line(top, top + d * 26, Pal.WARN, 8.0)
	draw_circle(top, 14, Color("ffd166"), true, -1.0, true)


func _lab(c: Vector2, lv: int) -> void:
	var r := 60.0 + lv * 8.0
	draw_circle(c, r, Color("9ad1d4"), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-r, 0), Vector2(r * 2, r)), GROUND_HI)
	draw_arc(c, r, PI, TAU, 40, Color("e0fbfc"), 5.0, true)
	for i in lv:
		draw_circle(c + Vector2(-r * 0.5 + i * r * 0.5, -r * 0.45), 9, Color(Pal.ACCENT, 0.6 + 0.4 * sin(_time * 4.0 + i)), true, -1.0, true)
	var base := c + Vector2(0, -r)
	draw_line(base, base + Vector2(0, -40), Color("d9e2ec"), 6.0)
	var dish := base + Vector2(0, -48)
	var ang := sin(_time * 0.7) * 0.6
	draw_arc(dish, 30 + lv * 6, PI + ang - 1.0, PI + ang + 1.0, 20, Color("d9e2ec"), 8.0, true)
