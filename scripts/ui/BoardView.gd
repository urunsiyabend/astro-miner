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
## Painted blocks (Art): a square top face and a layered earth band below it. Rows sit
## `pitch` apart (a bit more than `cell`) so each row shows a strip of its band.
const GAP := 0.0            # px between neighbouring blocks (the cell art carries its own margin)
const ROCK_SIZE := 1.0      # rock sprite canvas / cell (the rock body is ~80% of its canvas)
const ORE_SIZE := 0.80      # ore sprite canvas / cell

var snap: Dictionary = {}
var scanner := false
var drill := false
var cell := 130.0
var pitch := 130.0          # distance between rows (cell + visible band with the painted art)
var origin := Vector2.ZERO
var hint_dir := -1
var focus: Array = []   # cells Mira is talking about; drawn as pulsing frames
## Gems of a match within reach, shown after the player has been idle a while: they hop one
## after another with a halo and sparkles (set with set_glow, cleared on the next move).
var glow: Array = []
var _glow_t := 0.0
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
var _ob := StyleBoxFlat.new()  # outlines (tile highlights)
var _frame: Control  # the jelly board frame, drawn behind the board
var _art := false  # painted blocks available (Art.has_tiles)
var _band := 0.0   # full earth band height / tile width


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_sb.anti_aliasing = true
	# painted cells/gems are drawn ~3x smaller than their source: sample the mipmaps so their
	# edges don't shimmer (the textures import with mipmaps on)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art = Art.has_tiles()
	if _art:
		var t := Art.tile("soil_a")
		_band = float(t.get_height()) / t.get_width() - 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _art:
		_frame = Control.new()
		_frame.show_behind_parent = true
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = preload("res://scripts/ui/jelly_board.gdshader")
		m.set_shader_parameter("rim_color", Pal.BOARD_RIM)
		m.set_shader_parameter("outline_color", Pal.BOARD_LINE)
		m.set_shader_parameter("earth_hi", Pal.BOARD_EARTH_HI)
		m.set_shader_parameter("earth", Pal.BOARD_EARTH)
		m.set_shader_parameter("gloss", 0.45)
		m.set_shader_parameter("inner_shadow", 0.4)
		m.set_shader_parameter("drop", 0.3)
		_frame.material = m
		_frame.draw.connect(func(): _frame.draw_rect(Rect2(Vector2.ZERO, _frame.size), Color.WHITE))
		add_child(_frame)
	resized.connect(_layout)
	_layout()


func show_snap(s: Dictionary) -> void:
	snap = s
	_queue.clear()
	_cur = {}
	snap_changed.emit(snap)
	_update_frame()
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
	# with painted blocks the board is H rows of `pitch` plus the last row's full earth band
	var rows_h := Board.H * (1.0 + Art.BAND_VISIBLE) + _band if _art else float(Board.H)
	# leave room around the board for its frame (rim + shadow, ~0.3 cell in all)
	var frame := 0.3 if _art else 0.0
	cell = floorf(minf(size.x / (Board.W + frame), size.y / (rows_h + frame)))
	pitch = roundf(cell * (1.0 + Art.BAND_VISIBLE)) if _art else cell
	var used := Vector2(cell * Board.W, pitch * Board.H + (cell * _band if _art else 0.0))
	origin = ((size - used) * 0.5).floor()
	_update_frame()
	queue_redraw()


## Top-left of a cell's top face. Every position on the board comes from here or cell_center.
func cell_origin(p: Vector2i) -> Vector2:
	return origin + Vector2(p.x * cell, p.y * pitch)


func cell_center(i: int) -> Vector2:
	return cell_origin(Board.pos(i)) + Vector2(cell, cell) * 0.5


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
	_glow_t += delta
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
	var c := Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / pitch))
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
	if not _art:
		draw_rect(Rect2(origin - Vector2(10, 10), Vector2(cell * Board.W, cell * Board.H) + Vector2(20, 20)), Pal.BEDROCK)
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
	var glowing := not glow.is_empty() and _cur.is_empty()
	if glowing:
		for k in glow.size():
			_draw_glow_halo(glow[k], k)
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
		var at := cell_center(i)
		if glowing and glow.has(i):
			var hop := _glow_hop(glow.find(i))
			at.y -= cell * 0.1 * hop
			sc *= 1.0 + 0.12 * hop
		_draw_token(at, snap.token[i], snap.ore[i], sc, fl)
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
	if glowing:
		for k in glow.size():
			_draw_glow_sparks(glow[k], k)
	for f in focus:
		var fc: Vector2i = f
		if not Board.inside(fc):
			continue
		_tile_outline(Board.idx(fc), Color(Pal.WARN, 0.9), cell * 0.012 + cell * 0.018 * (0.5 + 0.5 * sin(_time * 6.0)))
	for r in _rings:
		var k: float = r.t / r.dur
		var col: Color = r.color
		col.a = 1.0 - k
		draw_arc(r.c, lerpf(r.r0, r.r1, _ease(k)), 0, TAU, 48, col, 8.0 * (1.0 - k) + 2.0, true)
	draw_set_transform(Vector2.ZERO)


func set_glow(cells: Array) -> void:
	glow = cells
	_glow_t = 0.0


## 0..1 hop of the k-th glowing gem: they bounce in turn, then all rest a moment.
func _glow_hop(k: int) -> float:
	var t := fmod(maxf(0.0, _glow_t - 0.2), 1.5) - k * 0.11
	if t < 0.0 or t > 0.34:
		return 0.0
	var x := t / 0.34
	return sin(x * PI) * (1.0 - 0.35 * x)


func _glow_fade() -> float:
	return clampf(_glow_t / 0.4, 0.0, 1.0)


## Soft halo in the gem's own colour behind it, breathing, brighter while it hops.
func _draw_glow_halo(i: int, k: int) -> void:
	if snap.token[i] != K.ORE:
		return
	var c := cell_center(i)
	var col: Color = Pal.ORE[snap.ore[i]].lightened(0.35)
	var breathe := 0.5 + 0.5 * sin(_time * 4.0 + k)
	var a := _glow_fade() * (0.4 + 0.18 * breathe + 0.35 * _glow_hop(k))
	var r := cell * (0.42 + 0.04 * breathe)
	for n in 5:
		var f := 1.0 - n * 0.16
		draw_circle(c, r * (0.55 + 0.45 * f + 0.25 * (1.0 - f)), Color(col, a * 0.32 * f), true, -1.0, true)


## Two little four-point sparkles circling each glowing gem, twinkling.
func _draw_glow_sparks(i: int, k: int) -> void:
	var c := cell_center(i) - Vector2(0, cell * 0.1 * _glow_hop(k))
	for n in 2:
		var ang := _time * 1.6 + k * 2.1 + n * PI
		var p := c + Vector2(cos(ang), sin(ang) * 0.8) * cell * 0.38
		var tw := 0.5 + 0.5 * sin(_time * 7.0 + k * 1.7 + n * 2.0)
		var s := cell * (0.05 + 0.05 * tw)
		var col := Color(1, 1, 0.9, _glow_fade() * (0.45 + 0.55 * tw))
		var pts := PackedVector2Array()
		for m in 8:
			var a := m * PI / 4.0
			var rr := s if m % 2 == 0 else s * 0.28
			pts.append(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)


func _rect(i: int, inset := 3.0) -> Rect2:
	var o := cell_origin(Board.pos(i))
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
	if _art:
		_draw_tile(i, r)
		return
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
	if _art:
		var c0 := r.get_center()
		var tex := Art.rock(snap.hp0[i] if snap.has("hp0") else hpv, hpv)
		if tex != null:
			var s := (cell - GAP) * ROCK_SIZE
			_draw_lifted(tex, Rect2(c0 - Vector2(s, s) * 0.5, Vector2(s, s)))
		_draw_layer_pill(c0 + Vector2(0, -cell * 0.02), cell * 0.42, hpv)
		if scanner:
			_draw_buried(c0, snap.buried[i])
		return
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


## Painted ground: soil (two variants), a shallow dent one or two layers deep, a dry exhausted
## floor; rock cells get soil under their rock sprite; bedrock stays empty (floating island).
func _draw_tile(i: int, r: Rect2) -> void:
	var t: int = snap.terrain[i]
	if t == T.BEDROCK:
		return
	var name := "soil_a" if (i * 7 + i / Board.W) % 3 else "soil_b"
	var res: int = snap.reserve[i] if t == T.GROUND else 1
	if t == T.GROUND:
		var d: int = snap.depth[i]
		if res <= 0 and (d > 0 or snap.token[i] == K.NONE):
			name = "bare"
		elif d > 0:
			name = "dent1" if d == 1 else "dent2"
	var tex := Art.tile(name)
	var w := cell - GAP
	var top := Rect2(r.position + Vector2(GAP * 0.5, 0), Vector2(w, w))
	if _sink.has(i):  # the floor just dropped a layer: a quick dip
		top.position.y += 4.0 * sin(PI * _ease(_sink[i]))
	draw_texture_rect(tex, Rect2(top.position, Vector2(w, w * (1.0 + _band))), false)
	if t == T.GROUND and res > 0:
		var n := mini(res, 5)
		# vein pips: a small row inside the cell's lower edge, under the ore
		var step := cell * 0.085
		var dot := cell * 0.028
		var pill := Rect2(Vector2(top.get_center().x - (n * step + dot * 2.2) * 0.5, top.end.y - cell * 0.13),
				Vector2(n * step + dot * 2.2, dot * 3.0))
		_round_rect(pill, Color(0, 0, 0, 0.42), dot * 1.5)
		for k in n:
			draw_circle(Vector2(pill.position.x + dot * 1.1 + step * 0.5 + k * step, pill.get_center().y), dot, Pal.VEIN, true, -1.0, true)


func _draw_layer_pill(c: Vector2, rad: float, hpv: int) -> void:
	var pill := Rect2(Vector2(c.x - 12 - hpv * 9, c.y - rad * 0.95), Vector2(24 + hpv * 18 - 6, 22))
	_round_rect(pill, Color(0, 0, 0, 0.55), 11)
	for k in hpv:
		draw_circle(Vector2(pill.position.x + 15 + k * 18, pill.get_center().y), 7, Pal.TEXT)


static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + by)
	return out


func _draw_buried(c: Vector2, b: int) -> void:
	var s := cell * 0.2
	match b:
		Board.Buried.CRYSTAL:
			var gem := Art.ore(3) if _art else null
			if gem != null:
				draw_texture_rect(gem, Rect2(c + Vector2(0, 6) - Vector2(s, s) * 1.3, Vector2(s, s) * 2.6), false, Color(1, 1, 1, 0.85))
			else:
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
				_tile_outline(ni, col, 0.0)
			_chevron(cell_center(snap.robot) + Vector2(d) * Vector2(cell, pitch) * 0.5, Vector2(d), col)
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
	var art := Art.ore(kind) if tk == K.ORE and _art else null
	if art != null:
		var size := cell * ORE_SIZE * sc
		_draw_lifted(art, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)))
		if flash > 0.0:
			draw_circle(c, s * 1.3, Color(1, 1, 1, 0.55 * flash))
		return
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
			var gem := Art.ore(3) if _art else null
			if gem != null:
				draw_texture_rect(gem, Rect2(c - Vector2(s, s) * 1.6, Vector2(s, s) * 3.2), false)
			else:
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


## A highlight that wraps a cell's tile exactly: a rounded frame on the tile's own outline
## (the cell art is ~97.5% of the cell, corner radius ~20%), with a soft glow outside it.
## `grow` pushes the frame outward (used for the pulsing focus frame).
func _tile_outline(i: int, col: Color, grow: float) -> void:
	# StyleBoxFlat draws its border inside the rect: grow by the width so the frame's inner
	# edge sits on the tile's edge and the frame wraps the tile from outside
	var w := maxf(3.0, cell * 0.045)
	var r := _rect(i, 0).grow(-cell * 0.0125 + grow + w)
	var rad := cell * 0.2 + grow + w
	_ob.draw_center = false
	_ob.anti_aliasing = true
	_ob.set_corner_radius_all(int(rad + w))
	_ob.border_color = Color(col, col.a * 0.35)
	_ob.set_border_width_all(int(w * 2.0))
	draw_style_box(_ob, r.grow(w))
	_ob.set_corner_radius_all(int(rad))
	_ob.border_color = col
	_ob.set_border_width_all(int(w))
	draw_style_box(_ob, r)


## A sprite lifted off the board: its own silhouette as a soft dark shadow just below it.
func _draw_lifted(tex: Texture2D, r: Rect2) -> void:
	var lift := r.size.y * 0.035
	for k in 3:
		var spread := r.size.x * 0.005 * k
		draw_texture_rect(tex, Rect2(r.position + Vector2(-spread, lift - spread * 0.5), r.size + Vector2(spread, spread) * 2.0), false, Color(0.12, 0.04, 0.02, 0.16))
	draw_texture_rect(tex, r, false)


## The board frame hugs the playfield's real shape (every cell but bedrock), like the hero,
## with the same jelly look as the HUD (jelly_board.gdshader): a child node drawn behind the
## board. The shape is computed as ONE outline: the boundary of the union of the cells is traced
## into closed loops, pushed outward by the frame width, and every corner is replaced by an arc
## (convex corners rounded outward, concave corners with an inner "C" fillet). The loops go to
## the shader as line segments, which takes the exact signed distance to them.
## Proportions (one cell = 1): rim 0.08, dark line ~0.022, lip 0.03, corner radius 0.22.
func _update_frame() -> void:
	if _frame == null or snap.is_empty() or cell < 16.0:
		return
	# the frame node overhangs the view a little so the rim and shadow are never clipped
	var over := cell * 0.5
	_frame.position = -Vector2(over, over)
	_frame.size = size + Vector2(over, over) * 2.0
	var lip := cell * 0.03
	var line := maxf(2.5, cell * 0.022)
	var rim := cell * 0.08
	var g := lip + line + rim
	var convex_r := cell * 0.22 + g
	var concave_r := cell * 0.22
	var to_px := func(v: Vector2) -> Vector2:
		return origin + Vector2(v.x * cell, v.y * pitch) + Vector2(over, over)
	var segs := PackedVector4Array()
	for loop in _outline_loops():
		var pts := _rounded_offset(loop, to_px, g, convex_r, concave_r)
		for k in pts.size():
			var a2: Vector2 = pts[k]
			var b2: Vector2 = pts[(k + 1) % pts.size()]
			segs.append(Vector4(a2.x, a2.y, b2.x, b2.y))
	if segs.size() > 256:
		push_warning("board outline has %d segments, the shader takes 256" % segs.size())
		segs.resize(256)
	var area := Rect2(origin, Vector2(cell * Board.W, pitch * Board.H))
	var m := _frame.material as ShaderMaterial
	m.set_shader_parameter("size", _frame.size)
	m.set_shader_parameter("seg_count", segs.size())
	m.set_shader_parameter("segs", segs)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("outline", line)
	m.set_shader_parameter("drop_offset", Vector2(0, rim * 0.6))
	m.set_shader_parameter("light_center", area.get_center() + Vector2(0, -area.size.y * 0.18) + Vector2(over, over))
	m.set_shader_parameter("light_reach", area.size.length() * 0.55)
	_frame.queue_redraw()


## Closed boundary loops of the union of the playfield cells, in grid units, as corner vertices
## (collinear points dropped). Edges run clockwise on screen (y down), so the board is always on
## their right. Where two cells touch only at a corner, the walk turns right, keeping them apart.
func _outline_loops() -> Array:
	var out_edges := {}   # start vertex -> Array of end vertices
	for i in Board.W * Board.H:
		if snap.terrain[i] == T.BEDROCK:
			continue
		var p := Board.pos(i)
		var tl := Vector2i(p.x, p.y)
		var tr := Vector2i(p.x + 1, p.y)
		var br := Vector2i(p.x + 1, p.y + 1)
		var bl := Vector2i(p.x, p.y + 1)
		var sides := [[Vector2i(0, -1), tl, tr], [Vector2i(1, 0), tr, br], [Vector2i(0, 1), br, bl], [Vector2i(-1, 0), bl, tl]]
		for sd in sides:
			if not _in_board(p + sd[0]):
				if not out_edges.has(sd[1]):
					out_edges[sd[1]] = []
				out_edges[sd[1]].append(sd[2])
	var loops := []
	while not out_edges.is_empty():
		var start: Vector2i = out_edges.keys()[0]
		var verts: Array[Vector2i] = [start]
		var prev_dir := Vector2i.ZERO
		var cur := start
		while true:
			var ends: Array = out_edges[cur]
			var pick := 0
			if ends.size() > 1 and prev_dir != Vector2i.ZERO:
				# prefer turning right (clockwise), then straight, then left
				var best := -9
				for k in ends.size():
					var dd: Vector2i = ends[k] - cur
					var turn := prev_dir.x * dd.y - prev_dir.y * dd.x
					var score := 2 if turn > 0 else (1 if turn == 0 else 0)
					if score > best:
						best = score
						pick = k
			var nxt: Vector2i = ends[pick]
			ends.remove_at(pick)
			if ends.is_empty():
				out_edges.erase(cur)
			prev_dir = nxt - cur
			cur = nxt
			if cur == start:
				break
			verts.append(cur)
		# drop collinear vertices
		var corners := []
		var n := verts.size()
		for k in n:
			var a: Vector2i = verts[(k - 1 + n) % n]
			var b: Vector2i = verts[k]
			var c: Vector2i = verts[(k + 1) % n]
			var d1 := b - a
			var d2 := c - b
			if d1.x * d2.y - d1.y * d2.x != 0:
				corners.append(Vector2(b))
		if corners.size() >= 3:
			loops.append(corners)
	return loops


## One loop pushed outward by `g` pixels with every corner replaced by an arc, as a polyline in
## pixels. Convex corners (right turns on a clockwise loop) get radius `rc`, concave ones `rf`.
func _rounded_offset(loop: Array, to_px: Callable, g: float, rc: float, rf: float) -> PackedVector2Array:
	var n := loop.size()
	var pv := []   # corner points in pixels, already offset
	var dirs := []  # unit direction of the edge leaving each corner
	for k in n:
		var a: Vector2 = to_px.call(loop[(k - 1 + n) % n])
		var b: Vector2 = to_px.call(loop[k])
		var c: Vector2 = to_px.call(loop[(k + 1) % n])
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var o1 := Vector2(d1.y, -d1.x)   # outward normal (board is on the right)
		var o2 := Vector2(d2.y, -d2.x)
		pv.append(b + (o1 + o2) * g)
		dirs.append(d2)
	var out := PackedVector2Array()
	for k in n:
		var v: Vector2 = pv[k]
		var vp: Vector2 = pv[(k - 1 + n) % n]
		var vn: Vector2 = pv[(k + 1) % n]
		var d1: Vector2 = dirs[(k - 1 + n) % n]
		var d2: Vector2 = dirs[k]
		var convex := d1.x * d2.y - d1.y * d2.x > 0.0
		var r := rc if convex else rf
		r = minf(r, minf(v.distance_to(vp), v.distance_to(vn)) * 0.5)
		var t1 := v - d1 * r
		var t2 := v + d2 * r
		# arc centre: inward of the first edge for a convex corner, outward for a concave one
		var nrm := Vector2(-d1.y, d1.x) if convex else Vector2(d1.y, -d1.x)
		var ctr := t1 + nrm * r
		var a1 := (t1 - ctr).angle()
		var a2 := (t2 - ctr).angle()
		var da := wrapf(a2 - a1, -PI, PI)
		var steps := 8
		for s2 in steps + 1:
			var a := a1 + da * float(s2) / steps
			out.append(ctr + Vector2(cos(a), sin(a)) * r)
	return out


func _in_board(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Board.W or p.y >= Board.H:
		return false
	return snap.terrain[Board.idx(p)] != T.BEDROCK


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
