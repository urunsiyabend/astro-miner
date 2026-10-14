class_name BoardView
extends Control

## Draws a board snapshot and animates the step list returned by Board.try_move().
## Rules never live here: the view only replays what the Board already decided.

signal move_requested(dir: Vector2i)
signal snap_changed(snap: Dictionary)
signal fx(kind: String, data: Dictionary)
signal settled

const T := Board.Terrain
const K := Board.Token
const MAX_PIT := 4          # deepest level drawn; deeper pits look the same
const PIT_STEP := 0.09      # wall width per dug layer, as a fraction of a cell
const ROCK_STEP := 0.07     # height of one rock layer, as a fraction of a cell

var snap: Dictionary = {}
var scanner := false
var drill := false
var cell := 130.0
var origin := Vector2.ZERO
var hint_dir := -1
var focus: Array = []   # cells Mira is talking about; drawn as pulsing frames
var input_enabled := true

var _queue: Array = []
var _cur: Dictionary = {}
var _t := 0.0
var _dur := 0.0
var _phase := 0
var _time := 0.0
var _shake := 0.0
var _flash := {}   # cell -> 1..0
var _rise := {}    # cell -> 0..1
var _jolt := {}    # rock cell -> 1..0
var _sink := {}    # ground cell whose floor just dropped a layer -> 0..1
var _rings := []   # {c: Vector2, r0, r1, t, dur, color}
var _bump := {"cell": -1, "t": 0.0, "dir": Vector2.ZERO}
var _face := Vector2(0, 1)
var _touch_start := Vector2.ZERO
var _touching := false
var _swiped := false
var _font: Font
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_sb.anti_aliasing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func show_snap(s: Dictionary) -> void:
	snap = s
	_queue.clear()
	_cur = {}
	snap_changed.emit(snap)
	queue_redraw()


func is_busy() -> bool:
	return not _cur.is_empty() or not _queue.is_empty()


func play_steps(steps: Array) -> void:
	for s in steps:
		_queue.append(s)
	if _cur.is_empty():
		_next_step()


func bump(dir: Vector2i) -> void:
	if snap.is_empty():
		return
	_bump = {"cell": snap.robot, "t": 1.0, "dir": Vector2(dir)}
	Sfx.play("bump")


func _layout() -> void:
	cell = floorf(minf(size.x / Board.W, size.y / Board.H))
	origin = ((size - Vector2(cell * Board.W, cell * Board.H)) * 0.5).floor()
	queue_redraw()


func cell_center(i: int) -> Vector2:
	var p := Board.pos(i)
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell


func cell_global(i: int) -> Vector2:
	return get_global_transform_with_canvas() * cell_center(i)


# --- step playback ---------------------------------------------------------

func _next_step() -> void:
	if _queue.is_empty():
		_cur = {}
		settled.emit()
		return
	_cur = _queue.pop_front()
	_t = 0.0
	_phase = 0
	var fast := 0.8 if _queue.size() > 2 else 1.0
	match _cur.type:
		"move":
			_dur = 0.1 * fast
			_face = Vector2(Board.pos(_cur.to) - Board.pos(_cur.from))
			Sfx.play("swap" if _cur.swap else "step", randf_range(0.95, 1.05))
		"drill":
			_dur = 0.16
			_face = Vector2(Board.pos(_cur.cell) - Board.pos(snap.robot))
			Sfx.play("drill")
		"match":
			_dur = 0.16 * fast
			for g in _cur.groups:
				for c in g.cells:
					_flash[c] = 1.0
			var pitch: float = 1.0 + 0.12 * (1 if _cur.cascade else 0) + 0.06 * _cur.groups.size()
			Sfx.play("match", pitch)
		"blast":
			_dur = 0.24
			_shake = 1.0
			var r: float = (_cur.radius + 0.5) * cell
			_rings.append({"c": cell_center(_cur.center), "r0": cell * 0.3, "r1": r * 1.3,
					"t": 0.0, "dur": 0.35, "color": Pal.CHARGE})
			Sfx.play("blast")
			fx.emit("blast", {"pos": cell_global(_cur.center)})
		"pulse":
			_dur = 0.3
			_rings.append({"c": cell_center(snap.robot), "r0": cell * 0.5, "r1": cell * 6.0,
					"t": 0.0, "dur": 0.45, "color": Pal.ACCENT})
			Sfx.play("pulse")
		_:
			_dur = 0.01


func _finish_phase() -> void:
	match _cur.type:
		"move":
			if _cur.pickup == K.CRYSTAL:
				Sfx.play("pickup")
				fx.emit("pickup", {"pos": cell_global(_cur.to), "res": 3})
			elif _cur.pickup == K.CELL:
				Sfx.play("pickup", 0.8)
				fx.emit("energy", {"pos": cell_global(_cur.to), "amount": 0})
			_apply(_cur.snap)
			_next_step()
		"drill":
			_jolt[_cur.cell] = 1.0
			fx.emit("debris", {"pos": cell_global(_cur.cell), "color": Pal.ROCK[1]})
			_reveal_fx(_cur.revealed)
			_apply(_cur.snap)
			_next_step()
		"match":
			if _phase == 0:
				for g in _cur.groups:
					var pts := []
					for c in g.cells:
						pts.append(cell_global(c))
					fx.emit("extract", {"points": pts, "ore": g.ore})
				if _cur.energy > 0:
					fx.emit("energy", {"pos": cell_global(snap.robot), "amount": _cur.energy})
				for r in _cur.cracked:
					_jolt[r] = 1.0
					fx.emit("debris", {"pos": cell_global(r), "color": Pal.ROCK[1]})
				if not _cur.cracked.is_empty():
					Sfx.play("crack", randf_range(0.9, 1.1))
				_reveal_fx(_cur.revealed)
				for c in _cur.surfaced:
					_rise[c] = 0.0
				for c in _cur.charges:
					_rise[c] = 0.0
				_flash.clear()
				_apply(_cur.snap)
				_phase = 1
				_t = 0.0
				_dur = 0.12
			else:
				_next_step()
		"blast":
			for c in _cur.cells:
				_flash[c] = 0.6
			for c in _cur.surfaced:
				_rise[c] = 0.0
			_reveal_fx(_cur.revealed)
			fx.emit("blast_done", {"cells": _cur.cells.map(func(c): return cell_global(c))})
			_apply(_cur.snap)
			_next_step()
		_:
			_apply(_cur.snap)
			_next_step()


func _reveal_fx(cells: Array) -> void:
	if cells.is_empty():
		return
	Sfx.play("reveal")
	for c in cells:
		_rise[c] = 0.0
		_rings.append({"c": cell_center(c), "r0": cell * 0.2, "r1": cell * 0.9,
				"t": 0.0, "dur": 0.4, "color": Pal.TEXT})
		fx.emit("reveal", {"pos": cell_global(c)})


func _apply(s: Dictionary) -> void:
	if snap.has("depth") and s.has("depth"):
		for i in Board.W * Board.H:
			if s.depth[i] > snap.depth[i]:
				_sink[i] = 0.0
	snap = s
	snap_changed.emit(snap)


func _process(delta: float) -> void:
	_time += delta
	if not _cur.is_empty():
		_t += delta / maxf(0.001, _dur)
		if _t >= 1.0:
			_t = 1.0
			_finish_phase()
	for k in _rise.keys():
		_rise[k] += delta / 0.16
		if _rise[k] >= 1.0:
			_rise.erase(k)
	for k in _sink.keys():
		_sink[k] += delta / 0.22
		if _sink[k] >= 1.0:
			_sink.erase(k)
	for k in _jolt.keys():
		_jolt[k] -= delta / 0.25
		if _jolt[k] <= 0.0:
			_jolt.erase(k)
	if _cur.is_empty() or _cur.type != "match":
		for k in _flash.keys():
			_flash[k] -= delta / 0.2
			if _flash[k] <= 0.0:
				_flash.erase(k)
	for r in _rings:
		r.t += delta
	_rings = _rings.filter(func(r): return r.t < r.dur)
	_shake = maxf(0.0, _shake - delta * 4.0)
	if _bump.t > 0.0:
		_bump.t = maxf(0.0, _bump.t - delta / 0.18)
	queue_redraw()


# --- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = true
			_swiped = false
			_touch_start = event.position
		elif _touching:
			_touching = false
			if not _swiped:
				_tap(event.position)
		accept_event()
	elif event is InputEventScreenDrag and _touching and not _swiped:
		var d: Vector2 = event.position - _touch_start
		if d.length() > maxf(36.0, cell * 0.28):
			_swiped = true
			if absf(d.x) > absf(d.y):
				_request(Vector2i(signi(int(d.x)), 0))
			else:
				_request(Vector2i(0, signi(int(d.y))))
		accept_event()


func _tap(p: Vector2) -> void:
	if snap.is_empty():
		return
	var c := Vector2i(((p - origin) / cell).floor())
	var r := Board.pos(snap.robot)
	var d := c - r
	if absi(d.x) + absi(d.y) == 1:
		_request(d)


func _request(dir: Vector2i) -> void:
	if input_enabled:
		move_requested.emit(dir)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if snap.is_empty() or cell < 16.0:
		return
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 10.0
	draw_set_transform(off)
	var frame := Rect2(origin - Vector2(10, 10), Vector2(cell * Board.W, cell * Board.H) + Vector2(20, 20))
	draw_rect(frame, Pal.BEDROCK)
	var moving_to := -1
	var moving_from := -1
	var mt := 0.0
	if not _cur.is_empty() and _cur.type == "move":
		moving_to = _cur.to
		moving_from = _cur.from
		mt = _ease(_t)
	# ground first (pits included), then raised rock on top so its shadow falls on the ground
	for i in Board.W * Board.H:
		_draw_ground(i)
	for i in Board.W * Board.H:
		if snap.terrain[i] == T.ROCK:
			_draw_rock(i)
	_draw_move_hints(moving_to)
	for i in Board.W * Board.H:
		if snap.terrain[i] != T.GROUND:
			continue
		if i == moving_to:
			if _cur.swap:
				var from_p := cell_center(moving_to).lerp(cell_center(moving_from), mt)
				var dsc := lerpf(_depth_scale(moving_to), _depth_scale(moving_from), mt)
				_draw_token(from_p, snap.token[i], snap.ore[i], dsc, 0.0)
			else:
				_draw_token(cell_center(i), snap.token[i], snap.ore[i], (1.0 - mt) * _depth_scale(i), 0.0)
			continue
		var sc := _depth_scale(i)
		if _rise.has(i):
			sc = _back_out(_rise[i])
		var fl: float = _flash.get(i, 0.0)
		if fl > 0.0 and not _cur.is_empty() and _cur.type == "match" and _phase == 0:
			sc *= 1.0 + 0.18 * _t
		_draw_token(cell_center(i), snap.token[i], snap.ore[i], sc, fl)
	# robot
	var rp := cell_center(snap.robot)
	var rsc := _depth_scale(snap.robot)
	if moving_to != -1:
		rp = cell_center(moving_from).lerp(cell_center(moving_to), mt)
		# the robot visibly steps down into a pit or climbs out of it
		rsc = lerpf(_depth_scale(moving_from), _depth_scale(moving_to), mt)
	elif not _cur.is_empty() and _cur.type == "drill":
		var tgt := cell_center(_cur.cell)
		rp = rp.lerp(tgt, 0.28 * sin(PI * _t))
	if _bump.t > 0.0:
		rp += _bump.dir * cell * 0.12 * sin(PI * _bump.t)
	_draw_robot(rp, rsc)
	for f in focus:
		var fc: Vector2i = f
		if not Board.inside(fc):
			continue
		var fr := _rect(Board.idx(fc), -2.0 - 4.0 * (0.5 + 0.5 * sin(_time * 6.0)))
		draw_rect(fr, Color(Pal.WARN, 0.85), false, 7.0)
	for r in _rings:
		var k: float = r.t / r.dur
		var col: Color = r.color
		col.a = 1.0 - k
		draw_arc(r.c, lerpf(r.r0, r.r1, _ease(k)), 0, TAU, 48, col, 8.0 * (1.0 - k) + 2.0, true)
	draw_set_transform(Vector2.ZERO)


func _rect(i: int, inset := 3.0) -> Rect2:
	var p := Board.pos(i)
	var o := origin + Vector2(p) * cell
	if _jolt.has(i):
		o += Vector2(sin(_time * 70.0), cos(_time * 55.0)) * 6.0 * _jolt[i]
	return Rect2(o + Vector2(inset, inset), Vector2(cell - inset * 2, cell - inset * 2))


## Things sitting in a pit are drawn a little smaller, as if seen from further away.
func _depth_scale(i: int) -> float:
	if not snap.has("depth"):
		return 1.0
	return 1.0 - 0.05 * mini(snap.depth[i], MAX_PIT)


## Dug level of a cell for drawing: 0 for the surface, rock, bedrock and outside the board.
func _level(p: Vector2i) -> int:
	if not Board.inside(p) or not snap.has("depth"):
		return 0
	var i := Board.idx(p)
	if snap.terrain[i] != T.GROUND:
		return 0
	return mini(snap.depth[i], MAX_PIT)


func _draw_ground(i: int) -> void:
	var r := _rect(i, 0)
	if snap.terrain[i] == T.BEDROCK:
		draw_rect(r, Pal.BEDROCK)
		for k in 3:
			var a := r.position + Vector2(r.size.x * (0.2 + k * 0.3), r.size.y)
			draw_line(a, a + Vector2(r.size.x * 0.3, -r.size.y) * 0.9, Color(1, 1, 1, 0.04), 3.0)
		return
	draw_rect(r, Pal.ground_level(0))
	if snap.terrain[i] != T.GROUND:
		return
	# Pit: one stepped bench per dug layer, like an open-pit mine seen from above. A side
	# only gets a wall where the neighbour is shallower, so neighbouring pits merge into one
	# hole and depth differences read as cliffs. Light comes from the top of the screen:
	# north walls are in shadow, south walls are lit.
	var p := Board.pos(i)
	var d := _level(p)
	var nb := [_level(p + Vector2i(0, -1)), _level(p + Vector2i(1, 0)),
			_level(p + Vector2i(0, 1)), _level(p + Vector2i(-1, 0))]  # N E S W
	var step := cell * PIT_STEP
	var prev := r
	for k in range(1, d + 1):
		var w := step
		if k == d and _sink.has(i):
			w *= _ease(_sink[i])
		var ins := [w if nb[0] < k else 0.0, w if nb[1] < k else 0.0,
				w if nb[2] < k else 0.0, w if nb[3] < k else 0.0]
		var cur := Rect2(prev.position + Vector2(ins[3], ins[0]),
				prev.size - Vector2(ins[1] + ins[3], ins[0] + ins[2]))
		_wall(prev, cur, ins, Pal.ground_level(k - 1))
		draw_rect(cur, Pal.ground_level(k))
		# the north wall casts a soft shadow onto the floor below it
		if ins[0] > 0.0:
			draw_rect(Rect2(cur.position, Vector2(cur.size.x, step * 0.5)), Color(0, 0, 0, 0.18))
		prev = cur
	var res: int = snap.reserve[i]
	if res <= 0 and (snap.depth[i] > 0 or snap.token[i] == K.NONE):
		# vein exhausted: bare, cracked floor instead of just a darker shade
		var f := prev.grow(-cell * 0.06)
		draw_rect(f, Pal.FLOOR_BARE)
		var c := f.get_center()
		for k in 3:
			var a := float(i * 7 + k * 53) * 0.61
			var p0 := c + Vector2(cos(a), sin(a)) * f.size.x * 0.12
			var p1 := c + Vector2(cos(a + 0.4), sin(a + 0.4)) * f.size.x * 0.42
			draw_line(p0, p1, Color(0, 0, 0, 0.35), 3.0, true)
	# grid seam so cells stay readable inside a merged pit
	draw_rect(r.grow(-1), Color(0, 0, 0, 0.16), false, 2.0)
	# ore layers left under the floor: warm pips on a dark pill (same language as rock)
	if res > 0:
		var n := mini(res, 5)
		var pill := Rect2(Vector2(r.get_center().x - (n * 16 + 10) * 0.5, r.end.y - 22), Vector2(n * 16 + 10, 18))
		_round_rect(pill, Color(0, 0, 0, 0.5), 9)
		for k in n:
			draw_circle(Vector2(pill.position.x + 13 + k * 16, pill.get_center().y), 5.5, Pal.VEIN)


## Four wall bands between an outer and an inner rect; ins = [N, E, S, W] widths.
func _wall(o: Rect2, n: Rect2, ins: Array, base: Color) -> void:
	var otl := o.position
	var otr := Vector2(o.end.x, o.position.y)
	var obr := o.end
	var obl := Vector2(o.position.x, o.end.y)
	var itl := n.position
	var itr := Vector2(n.end.x, n.position.y)
	var ibr := n.end
	var ibl := Vector2(n.position.x, n.end.y)
	if ins[3] > 0.5:
		draw_colored_polygon(PackedVector2Array([otl, itl, ibl, obl]), base.darkened(0.3))
	if ins[1] > 0.5:
		draw_colored_polygon(PackedVector2Array([itr, otr, obr, ibr]), base.darkened(0.15))
	if ins[0] > 0.5:
		draw_colored_polygon(PackedVector2Array([otl, otr, itr, itl]), base.darkened(0.55))
	if ins[2] > 0.5:
		draw_colored_polygon(PackedVector2Array([ibl, ibr, obr, obl]), base.lightened(0.12))


## Rock stands above the ground: one stacked slab per layer, a cast shadow to the south,
## and the layer pill on its top face.
func _draw_rock(i: int) -> void:
	var r := _rect(i, 0)
	var hpv: int = snap.hp[i]
	var col: Color = Pal.ROCK[clampi(hpv, 1, 3)]
	var face := col.darkened(0.45)
	var hstep := cell * ROCK_STEP
	var base := r.get_center() + Vector2(0, cell * 0.07)
	var rad := cell * 0.42
	var shape := PackedVector2Array()
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var wob := 0.9 + 0.08 * sin(i * 3.7 + k * 1.9)
		shape.append(Vector2(cos(a), sin(a)) * rad * wob)
	# cast shadow, longer for taller rock
	draw_colored_polygon(_moved(shape, base + Vector2(hstep * 0.4, hstep * (0.6 + hpv * 0.5))), Color(0, 0, 0, 0.32))
	# side: one slab per remaining layer, with a seam between slabs
	for k in hpv:
		var slab := _moved(shape, base - Vector2(0, hstep * k))
		draw_colored_polygon(slab, face)
		var seam := slab.duplicate()
		seam.append(seam[0])
		draw_polyline(seam, face.darkened(0.35), 2.0, true)
	var c := base - Vector2(0, hstep * hpv)
	var top := _moved(shape, c)
	draw_colored_polygon(top, col)
	var rim := top.duplicate()
	rim.append(rim[0])
	draw_polyline(rim, col.lightened(0.25), 4.0, true)
	# crack lines: more layers removed = more cracks
	for k in 3 - hpv + 1:
		var a := float(i * 13 + k * 47) * 0.37
		var p0 := c + Vector2(cos(a), sin(a)) * rad * 0.1
		var p1 := c + Vector2(cos(a + 0.5), sin(a + 0.5)) * rad * 0.55
		var p2 := c + Vector2(cos(a + 0.2), sin(a + 0.2)) * rad * 0.85
		draw_polyline(PackedVector2Array([p0, p1, p2]), col.darkened(0.45), 4.0, true)
	# layer counter: a dark pill with one bright pip per remaining layer
	var pill := Rect2(Vector2(c.x - 12 - hpv * 9, c.y - rad * 0.95), Vector2(24 + hpv * 18 - 6, 22))
	_round_rect(pill, Color(0, 0, 0, 0.55), 11)
	for k in hpv:
		draw_circle(Vector2(pill.position.x + 15 + k * 18, pill.get_center().y), 7, Pal.TEXT)
	if scanner:
		_draw_buried(c, snap.buried[i])


static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + by)
	return out


func _draw_buried(c: Vector2, b: int) -> void:
	var s := cell * 0.2
	match b:
		Board.Buried.CRYSTAL:
			_gem(c + Vector2(0, 6), s, Color(Pal.CRYSTAL, 0.85))
		Board.Buried.CELL:
			_battery(c + Vector2(0, 6), s, Color(Pal.CELL, 0.85))
		Board.Buried.EMPTY:
			draw_arc(c + Vector2(0, 6), s * 0.7, 0, TAU, 20, Color(1, 1, 1, 0.35), 3.0)
		_:
			draw_circle(c + Vector2(0, 6), s * 0.35, Color(1, 1, 1, 0.3))


func _draw_move_hints(moving_to: int) -> void:
	if moving_to != -1 or is_busy():
		return
	var rp := Board.pos(snap.robot)
	for di in 4:
		var d: Vector2i = Board.DIRS[di]
		var n := rp + d
		if not Board.inside(n):
			continue
		var ni := Board.idx(n)
		var tt: int = snap.terrain[ni]
		var hinted := di == hint_dir
		if tt == T.GROUND:
			var col := Color(1, 1, 1, 0.16)
			if hinted:
				col = Color(Pal.WARN, 0.55 + 0.4 * sin(_time * 8.0))
				draw_rect(_rect(ni, 4), col, false, 6.0)
			_chevron(cell_center(snap.robot) + Vector2(d) * cell * 0.5, Vector2(d), col)
		elif tt == T.ROCK and drill:
			var c := cell_center(ni) - Vector2(d) * cell * 0.36
			draw_circle(c, 13, Color(Pal.WARN, 0.85))
			draw_line(c - Vector2(d) * 8, c + Vector2(d) * 10, Pal.BG, 5.0)


func _chevron(c: Vector2, d: Vector2, col: Color) -> void:
	var side := Vector2(-d.y, d.x)
	var tip := c + d * 12
	draw_polyline(PackedVector2Array([tip - d * 14 + side * 14, tip, tip - d * 14 - side * 14]), col, 6.0, true)


func _draw_token(c: Vector2, tk: int, kind: int, sc: float, flash: float) -> void:
	if tk == K.NONE or sc <= 0.01:
		return
	var s := cell * 0.33 * sc
	match tk:
		K.ORE:
			var col: Color = Pal.ORE[kind]
			var dark: Color = Pal.ORE_DARK[kind]
			match kind:
				0:  # ferrite: square
					var r := Rect2(c - Vector2(s, s), Vector2(s, s) * 2)
					_round_rect(r.grow(4), dark, 12)
					_round_rect(r, col, 10)
					_round_rect(Rect2(r.position + Vector2(8, 8), Vector2(s * 0.7, s * 0.45)), col.lightened(0.35), 6)
				1:  # cryo: circle
					draw_circle(c, s * 1.08 + 4, dark)
					draw_circle(c, s * 1.08, col)
					draw_circle(c + Vector2(-s * 0.35, -s * 0.35), s * 0.32, col.lightened(0.45))
				_:  # lumen: triangle
					var p := PackedVector2Array([c + Vector2(0, -s * 1.25), c + Vector2(s * 1.2, s * 0.9), c + Vector2(-s * 1.2, s * 0.9)])
					var po := PackedVector2Array([c + Vector2(0, -s * 1.25 - 7), c + Vector2(s * 1.2 + 7, s * 0.9 + 4), c + Vector2(-s * 1.2 - 7, s * 0.9 + 4)])
					draw_colored_polygon(po, dark)
					draw_colored_polygon(p, col)
					draw_circle(c + Vector2(0, -s * 0.2), s * 0.25, col.lightened(0.5))
		K.CRYSTAL:
			var glow := 0.5 + 0.5 * sin(_time * 4.0 + c.x)
			draw_circle(c, s * 1.5, Color(Pal.CRYSTAL, 0.18 + 0.12 * glow))
			_gem(c, s * 1.2, Pal.CRYSTAL)
		K.CELL:
			draw_circle(c, s * 1.4, Color(Pal.CELL, 0.15))
			_battery(c, s, Pal.CELL)
		K.CHARGE:
			var pul := 0.5 + 0.5 * sin(_time * 9.0)
			draw_circle(c, s * 1.15, Color(Pal.CHARGE, 0.25 + 0.25 * pul))
			draw_arc(c, s, 0, TAU, 32, Pal.CHARGE, 8.0, true)
			draw_circle(c, s * 0.45, Pal.CHARGE.lightened(0.3 * pul))
	if flash > 0.0:
		draw_circle(c, s * 1.3, Color(1, 1, 1, 0.55 * flash))


func _gem(c: Vector2, s: float, col: Color) -> void:
	var p := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.8, -s * 0.2)])
	draw_colored_polygon(p, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.2), c + Vector2(0, -s * 0.05)]), col.lightened(0.4))
	p.append(p[0])
	draw_polyline(p, Pal.CRYSTAL_DARK, 3.0, true)


func _battery(c: Vector2, s: float, col: Color) -> void:
	var r := Rect2(c - Vector2(s * 0.65, s), Vector2(s * 1.3, s * 2))
	_round_rect(r, col.darkened(0.5), 8)
	_round_rect(r.grow(-6), col, 6)
	draw_rect(Rect2(c + Vector2(-s * 0.3, -s - 8), Vector2(s * 0.6, 8)), col.darkened(0.5))
	draw_line(c + Vector2(0, -s * 0.45), c + Vector2(-s * 0.25, s * 0.1), Pal.BG, 5.0)
	draw_line(c + Vector2(-s * 0.25, s * 0.1), c + Vector2(s * 0.25, -s * 0.05), Pal.BG, 5.0)
	draw_line(c + Vector2(s * 0.25, -s * 0.05), c + Vector2(0, s * 0.5), Pal.BG, 5.0)


func _draw_robot(c: Vector2, scale := 1.0) -> void:
	var s := cell * 0.4 * scale
	var low: bool = snap.energy <= 5
	draw_circle(c + Vector2(0, s * 0.95), s * 0.8, Color(0, 0, 0, 0.3))
	var body := Rect2(c - Vector2(s, s * 0.9), Vector2(s * 2, s * 1.8))
	_round_rect(body.grow(5), Pal.ROBOT_DARK, 22)
	_round_rect(body, Pal.ROBOT, 20)
	# antenna
	draw_line(c + Vector2(0, -s * 0.9), c + Vector2(0, -s * 1.3), Pal.ROBOT_DARK, 6.0)
	var blink := Pal.BAD if low and fmod(_time, 0.6) < 0.3 else Pal.ACCENT
	draw_circle(c + Vector2(0, -s * 1.35), 8, blink)
	# visor + eyes look toward last move
	var visor := Rect2(c + Vector2(-s * 0.78, -s * 0.55), Vector2(s * 1.56, s * 0.75))
	_round_rect(visor, Color("1b2638"), 14)
	var look := _face.normalized() * s * 0.12
	draw_circle(c + Vector2(-s * 0.35, -s * 0.18) + look, s * 0.15, Pal.ACCENT)
	draw_circle(c + Vector2(s * 0.35, -s * 0.18) + look, s * 0.15, Pal.ACCENT)
	# energy readout on the chest (Six Match puts the counter on the character)
	var txt := str(snap.energy)
	var fs := int(cell * 0.3 * scale)
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(_font, c + Vector2(-w * 0.5, s * 0.72), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Pal.BAD if low else Color("1b2638"))


func _round_rect(r: Rect2, col: Color, radius: float) -> void:
	# StyleBoxFlat.draw() emits its commands immediately, so one instance can be reused.
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(radius))
	draw_style_box(_sb, r)


static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func _back_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
