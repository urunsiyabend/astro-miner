class_name BoardView
extends Control

## Draws a board snapshot and animates the step list returned by Board.try_move().
## Rules never live here: the view only replays what the Board already decided.

signal move_requested(dir: Vector2i)
signal snap_changed(snap: Dictionary)
signal fx(kind: String, data: Dictionary)
signal settled
signal booster_target(target: int)
signal path_requested(dirs: Array)  # a path drawn from the robot (path_max > 1)
signal swap_requested(cell: int, dir: Vector2i)  # classic prototype: swap a gem with a neighbour  # a cell (the Laser: a DIRS index) picked for the armed booster

const WARP_COL := Color("ff6bd8")
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
var armed := -1   # Economy.Booster waiting for its target, or -1
var classic := false  # the classic prototype: no robot, a swipe on a gem swaps it
## Drawn paths: hold the robot and draw up to path_max steps. While the finger is down the
## board shows the swaps live (a preview snap); lifting it sends the path as one move.
var path_max := 1
var pads := {}       # launch pad cell -> target cell
var belts: Array = []  # conveyor loops of cells
var tunnels: Array = []  # [a, dir out of a, b, dir out of b]
var _finger := Vector2.ZERO  # where the drawing finger is (local)
var _belt_from := {}
var _path_groups: Array = []  # [{cells, ore, special (-1 none), at}]: what the release would match
var _label_font: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")  # during a belt step: cell -> the cell its token came from
const PAD_COL := Color("ffb347")
const BELT_COL := Color("9fe7ff")
var _drawing := false
var _path_dirs: Array = []
var _path_cells: Array = []   # robot cell first, then every cell the path visits
var _path_real: Dictionary = {}  # the snap before the path, restored if it is cancelled
var _path_t := 0.0
var _path_rp := Vector2.ZERO   # where the held robot is drawn: it glides after the path's end
var _path_lift := 0.0          # 0..1: the robot picked up off the board while drawing
var _slide := {}               # cell -> [offset it slides in from, t]: gems the robot swaps past
var _path_match := {}          # cells that would match if the finger lifted now
var _pip_pop := -1.0           # t of the last pip filling (its pop)
var _path_deny := 0.0          # 1 -> 0: the pips shake when the path is full
const PATH_NOTES := [0, 2, 4, 7, 9, 12, 14, 16]  # the drawing climbs a major pentatonic
var gravity := false  # falling gems: no veins, so no vein pips
var portals: Array = []  # [[source, destination]] cells: drawn as a glowing pair of rings
var _sel := -1        # classic: the gem tapped first (tap it, then a neighbour)
var _touch_cell := -1
var _fall_from := {}  # during a fall step: cell -> the cell its gem fell from
var _fall_drop := {}  # during a fall step: new cell -> rows it drops in from above
var _reject := {"a": -1, "b": -1, "t": 0.0}  # a swap that made no line wobbles back
# --- juice (docs/research/match3-combo-juice.md) ---
const FALL_G := 85.0          # gravity in rows/s²: pieces gather speed as they drop
const FALL_STAGGER := 0.022   # s between pieces starting to fall, bottom first, up a column
const CHAIN_NOTES := [0, 4, 7, 12, 16, 19, 24]  # semitones: each cascade climbs a major chord
var _match_to := {}   # matched cell -> where its group pulls together (centre of the group)
var _fall_delay := {} # falling cell -> s before it starts to fall
var _fall_time := {}  # falling cell -> s its drop takes
var _land := {}       # cell -> 1..0 landing squash after a drop
var _tok_squash := Vector2.ONE  # non-uniform scale for the next gem drawn (landing squash)
var _chain := 0       # cascades in the current turn
var _trauma := 0.0    # screen shake: added by blasts, shake = trauma²
var _whiteout := 0.0  # a full-board flash after a big blast
var _hold := 0.0      # hit-stop: the step clock waits this long
var _armed_t := 0.0

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
var _frame: Control  # the jelly board frame's shader quad, rendered into _frame_vp
## The frame shader is expensive (an exact distance to the whole outline, per pixel), so it is
## rendered ONCE into this viewport whenever the board's shape or size changes, and the board
## draws the resulting texture (_frame_img) every frame instead of the shader.
var _frame_vp: SubViewport
var _frame_img: TextureRect
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
		_frame_vp = SubViewport.new()
		_frame_vp.transparent_bg = true
		_frame_vp.disable_3d = true
		_frame_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_frame_vp.add_child(_frame)
		add_child(_frame_vp)
		_frame_img = TextureRect.new()
		_frame_img.show_behind_parent = true
		_frame_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_img.texture = _frame_vp.get_texture()
		_frame_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_frame_img)
	resized.connect(_layout)
	_layout()


func show_snap(s: Dictionary) -> void:
	snap = s
	_queue.clear()
	_cur = {}
	snap_changed.emit(snap)
	_layout()  # a dig sets its own board size


func is_drawing() -> bool:
	return _drawing


func is_busy() -> bool:
	return not _cur.is_empty() or not _queue.is_empty()


func play_steps(steps: Array) -> void:
	for s in steps:
		_queue.append(s)
	if _cur.is_empty():
		_next_step()


## A new player turn: the cascade count starts over (the chord climbs again from the root).
func new_turn() -> void:
	_chain = 0


func add_trauma(t: float) -> void:
	_trauma = minf(1.0, _trauma + t)


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
	if _cur.type == "move" and _cur.get("path", false):
		# a drawn path's steps were already shown live while it was drawn
		_apply(_cur.snap)
		_next_step()
		return
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
			# the gems swell, then pull together into the middle of their line and pop there
			_dur = 0.24 * fast
			_match_to.clear()
			for g in _cur.groups:
				var mid := Vector2.ZERO
				for c in g.cells:
					mid += cell_center(c)
					_flash[c] = 1.0
				mid /= float(g.cells.size())
				for c in g.cells:
					_match_to[c] = mid
			_chain += 1
			var note: int = CHAIN_NOTES[mini(_chain - 1, CHAIN_NOTES.size() - 1)]
			Sfx.play("match", pow(2.0, note / 12.0))
			if _chain in [3, 5, 7, 9]:
				fx.emit("chain", {"n": _chain, "pos": cell_global(_cur.groups[0].cells[0])})
		"blast":
			_dur = 0.24
			_shake = 0.4
			add_trauma(0.45)
			_whiteout = 0.6
			_hold = 0.05
			var r: float = (_cur.radius + 0.5) * cell
			_rings.append({"c": cell_center(_cur.center), "r0": cell * 0.3, "r1": r * 1.3,
					"t": 0.0, "dur": 0.35, "color": Pal.CHARGE})
			Sfx.play("blast")
			fx.emit("blast", {"pos": cell_global(_cur.center)})
		"pulse":
			_dur = 0.3
			var pc := cell_center(snap.robot) if snap.robot >= 0 else origin + Vector2(cell * Board.W, pitch * Board.H) * 0.5
			_rings.append({"c": pc, "r0": cell * 0.5, "r1": cell * 6.0,
					"t": 0.0, "dur": 0.45, "color": Pal.ACCENT})
			Sfx.play("pulse")
		"fall":
			_fall_from.clear()
			_fall_drop.clear()
			var far := 1
			for m in _cur.moves:
				_fall_from[m[1]] = m[0]
				far = maxi(far, Board.pos(m[1]).y - Board.pos(m[0]).y)
			for sp in _cur.spawns:
				_fall_drop[sp[0]] = sp[1]
				far = maxi(far, sp[1])
			for wp in _cur.get("warps", []):
				_fall_drop[wp[1]] = 1  # out of the portal: it drops in from just above
			if not _cur.robot.is_empty():
				far = maxi(far, Board.pos(_cur.robot[1]).y - Board.pos(_cur.robot[0]).y)
			if not _cur.get("warps", []).is_empty():
				Sfx.play("warp", 1.2)
			_fall_delay.clear()
			_fall_time.clear()
			var cols := {}  # x -> [[dest y, cell, rows]]
			for m in _cur.moves:
				var dd: int = Board.pos(m[1]).y - Board.pos(m[0]).y
				cols[Board.pos(m[1]).x] = cols.get(Board.pos(m[1]).x, []) + [[Board.pos(m[1]).y, m[1], maxi(1, dd)]]
			for sp in _cur.spawns:
				cols[Board.pos(sp[0]).x] = cols.get(Board.pos(sp[0]).x, []) + [[Board.pos(sp[0]).y, sp[0], maxi(1, sp[1])]]
			for wp in _cur.get("warps", []):
				cols[Board.pos(wp[1]).x] = cols.get(Board.pos(wp[1]).x, []) + [[Board.pos(wp[1]).y, wp[1], 1]]
			var end := 0.05
			for x in cols:
				var list: Array = cols[x]
				list.sort_custom(func(a, b): return a[0] > b[0])  # bottom first
				for k in list.size():
					var cc: int = list[k][1]
					_fall_delay[cc] = k * FALL_STAGGER
					_fall_time[cc] = sqrt(2.0 * float(list[k][2]) / FALL_G)
					end = maxf(end, _fall_delay[cc] + _fall_time[cc])
			if not _cur.robot.is_empty():
				var rd: int = maxi(1, Board.pos(_cur.robot[1]).y - Board.pos(_cur.robot[0]).y)
				end = maxf(end, sqrt(2.0 * float(rd) / FALL_G))
			_dur = end
		"swap":
			_dur = 0.14
			Sfx.play("swap", randf_range(0.95, 1.05))
		"launch":
			# up and over in an arc to the pad's target; a special goes off where it lands
			var dist := cell_center(_cur.from).distance_to(cell_center(_cur.to))
			_dur = clampf(0.28 + dist / (cell * 14.0), 0.32, 0.6)
			_rings.append({"c": cell_center(_cur.from), "r0": cell * 0.25, "r1": cell * 1.1,
					"t": 0.0, "dur": 0.3, "color": PAD_COL})
			add_trauma(0.12)
			Sfx.play("warp", 1.25)
			Sfx.play("zap", 1.4)
		"belt":
			_dur = 0.24
			_belt_from.clear()
			for m in _cur.moves:
				_belt_from[m[1]] = m[0]
			Sfx.play("step", 0.7)
			Sfx.play("swap", 0.6)
		"special":
			_dur = 0.42
			_shake = 0.3
			add_trauma(0.5)
			_whiteout = 0.7
			_hold = 0.06
			for c in _cur.hit:
				_flash[c] = 1.0
			for c in _cur.turned:
				_flash[c] = 1.0
			var col: Color = SPECIAL_COL[_cur.kind]
			match _cur.kind:
				Board.Special.QUAKE:
					_rings.append({"c": cell_center(_cur.at), "r0": cell * 0.3, "r1": cell * 2.6, "t": 0.0, "dur": 0.45, "color": col})
					_rings.append({"c": cell_center(_cur.at), "r0": cell * 0.2, "r1": cell * 2.2, "t": -0.08, "dur": 0.45, "color": col})
					Sfx.play("quake")
				Board.Special.GEODE:
					_rings.append({"c": cell_center(_cur.at), "r0": cell * 0.2, "r1": cell * 1.6, "t": 0.0, "dur": 0.4, "color": Pal.ORE[_cur.ore]})
					Sfx.play("prism", 1.15)
				Board.Special.DRILL:
					Sfx.play("zap")
				Board.Special.PRISM:
					Sfx.play("prism")
				_:
					Sfx.play("blast")
		"bomb":
			_dur = 0.3  # the bomb drops onto its cell; the blast step that follows does the rest
			Sfx.play("bombdrop")
		"warp":
			_dur = 0.2  # phase 0: the robot spins away; phase 1: it pops out at the target
			_rings.append({"c": cell_center(_cur.from), "r0": cell * 0.7, "r1": cell * 0.1,
					"t": 0.0, "dur": 0.2, "color": WARP_COL})
			Sfx.play("warp")
		"laser":
			_dur = 0.42
			_shake = 0.5
			for c in _cur.hit:
				_flash[c] = 1.0
			Sfx.play("laser")
		"magnet":
			_dur = 0.5
			for c in _cur.cells:
				_flash[c] = 1.0
			_rings.append({"c": cell_center(snap.robot), "r0": cell * 3.0, "r1": cell * 0.4,
					"t": 0.0, "dur": 0.5, "color": Color("7fe8ff")})
			Sfx.play("magnet")
		_:
			_dur = 0.01


func _finish_phase() -> void:
	match _cur.type:
		"move":
			if _cur.pickup == K.CRYSTAL:
				Sfx.play("pickup")
				fx.emit("pickup", {"pos": cell_global(_cur.to), "res": Board.RES_CRYSTAL})
			elif _cur.pickup == K.CELL:
				Sfx.play("cell")
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
					var mid: Vector2 = _match_to.get(g.cells[0], cell_center(g.cells[0]))
					for c in g.cells:
						pts.append(get_global_transform_with_canvas() * mid)
					fx.emit("extract", {"points": pts, "ore": g.ore, "chain": _chain, "pop": true})
				_match_to.clear()
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
				if not _cur.charges.is_empty():
					Sfx.play("forge")
				_flash.clear()
				_apply(_cur.snap)
				_phase = 1
				_t = 0.0
				_dur = 0.12
			else:
				_next_step()
		"blast":
			_emit_extract(_cur.cells)  # what the blast took flies to its goal like a match's
			for c in _cur.cells:
				_flash[c] = 0.6
			for c in _cur.surfaced:
				_rise[c] = 0.0
			_reveal_fx(_cur.revealed)
			fx.emit("blast_done", {"cells": _cur.cells.map(func(c): return cell_global(c))})
			_apply(_cur.snap)
			_next_step()
		"special":
			_emit_extract(_cur.hit)
			for r in _cur.cracked:
				_jolt[r] = 1.0
				fx.emit("debris", {"pos": cell_global(r), "color": Pal.ROCK[1]})
			_reveal_fx(_cur.revealed)
			fx.emit("blast_done", {"cells": [cell_global(_cur.at)]})
			_flash.clear()
			_apply(_cur.snap)
			_next_step()
		"fall":
			if not _fall_from.is_empty() or not _fall_drop.is_empty():
				Sfx.play("land", randf_range(0.95, 1.1))
			for c in _cur.collected:
				var res: int = Board.RES_CRYSTAL if snap.token[c] == K.CRYSTAL else -1
				if res >= 0:
					Sfx.play("pickup")
					fx.emit("pickup", {"pos": cell_global(c), "res": res})
				else:
					Sfx.play("cell")
					fx.emit("energy", {"pos": cell_global(c), "amount": 0})
			_fall_from.clear()
			_fall_drop.clear()
			_apply(_cur.snap)
			_next_step()
		"warp":
			if _phase == 0:
				_apply(_cur.snap)
				_rings.append({"c": cell_center(_cur.to), "r0": cell * 0.2, "r1": cell * 1.3,
						"t": 0.0, "dur": 0.35, "color": WARP_COL})
				fx.emit("blast_done", {"cells": [cell_global(_cur.to)]})
				if _cur.pickup == K.CRYSTAL:
					Sfx.play("pickup")
					fx.emit("pickup", {"pos": cell_global(_cur.to), "res": Board.RES_CRYSTAL})
				_phase = 1
				_t = 0.0
				_dur = 0.22
			else:
				_next_step()
		"laser":
			_emit_extract(_cur.hit)
			for r in _cur.cracked:
				_jolt[r] = 1.0
				fx.emit("debris", {"pos": cell_global(r), "color": Pal.ROCK[1]})
			_reveal_fx(_cur.revealed)
			for c in _cur.surfaced:
				_rise[c] = 0.0
			_apply(_cur.snap)
			_next_step()
		"magnet":
			_emit_extract(_cur.cells, snap.robot)
			for c in _cur.surfaced:
				_rise[c] = 0.0
			_flash.clear()
			_apply(_cur.snap)
			_next_step()
		"launch":
			_rings.append({"c": cell_center(_cur.to), "r0": cell * 0.2, "r1": cell * 1.4,
					"t": 0.0, "dur": 0.32, "color": PAD_COL})
			_land[_cur.to] = 1.0
			fx.emit("blast_done", {"cells": [cell_global(_cur.to)]})
			Sfx.play("land", 0.8)
			if _cur.robot:
				add_trauma(0.15)
			_apply(_cur.snap)
			_next_step()
		"belt":
			_belt_from.clear()
			_apply(_cur.snap)
			_next_step()
		_:
			_apply(_cur.snap)
			_next_step()


## Ore taken by a booster flies to the HUD like a match's, grouped by kind (read off the
## board as it was before the step). `from`: start them all at one cell instead (the Magnet).
func _emit_extract(cells: Array, from := -1) -> void:
	var by := {}
	for c in cells:
		if snap.token[c] != K.ORE:
			if snap.token[c] == K.CRYSTAL:
				fx.emit("pickup", {"pos": cell_global(c), "res": Board.RES_CRYSTAL})
			continue
		var k: int = snap.ore[c]
		if not by.has(k):
			by[k] = []
		by[k].append(cell_global(c if from < 0 else from))
	for k in by:
		fx.emit("extract", {"points": by[k], "ore": k})


## A treasure chest sits where a rock would: it bobs a little and glints now and then; a
## match next to it (or a blast) bursts it open.
func _draw_chest(i: int, r: Rect2) -> void:
	var tex := Art.tex("res://assets/ui/treasure.png")
	var c := r.get_center()
	var ph := float(i) * 1.7
	var bob := sin(_time * 2.4 + ph) * cell * 0.015
	var glow := 0.5 + 0.5 * sin(_time * 3.0 + ph)
	draw_circle(c + Vector2(0, cell * 0.04), cell * (0.4 + 0.03 * glow), Color(1.0, 0.82, 0.3, 0.16 + 0.1 * glow), true, -1.0, true)
	var s := cell * 0.86
	if tex != null:
		_draw_lifted(tex, Rect2(c + Vector2(0, bob) - Vector2(s, s) * 0.5, Vector2(s, s)))
	else:
		_round_rect(Rect2(c - Vector2(s, s) * 0.35, Vector2(s, s) * 0.7), Pal.COIN, 10)
	# a glint sweeping across every few seconds
	var gt := fmod(_time + ph, 3.2)
	if gt < 0.35:
		var k := gt / 0.35
		var p := c + Vector2(lerpf(-0.3, 0.3, k), lerpf(-0.18, 0.1, k)) * cell
		var a := sin(k * PI)
		var pts := PackedVector2Array()
		for m in 8:
			var ang := m * PI / 4.0
			var rr := cell * 0.1 * a if m % 2 == 0 else cell * 0.025 * a
			pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, Color(1, 1, 0.92, 0.9 * a))


func _reveal_fx(cells: Array) -> void:
	if cells.is_empty():
		return
	Sfx.play("reveal")
	for c in cells:
		if snap.buried[c] == Board.Buried.TREASURE:
			fx.emit("treasure", {"pos": cell_global(c)})
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
	_path_t += delta
	_path_lift = move_toward(_path_lift, 1.0 if _drawing else 0.0, delta / (0.09 if _drawing else 0.14))
	# drawing pulls the player in: the board leans a touch closer and the music steps back
	pivot_offset = size * 0.5
	scale = Vector2.ONE * (1.0 + 0.025 * _ease(_path_lift))
	if _drawing:
		Sfx.duck(5.0)
	if not snap.is_empty() and snap.robot >= 0:
		_path_rp = _path_rp.lerp(cell_center(snap.robot), 1.0 - exp(-delta * 28.0))
	for k in _slide.keys():
		_slide[k][1] += delta / 0.11
		if _slide[k][1] >= 1.0:
			_slide.erase(k)
	if _pip_pop >= 0.0:
		_pip_pop += delta / 0.22
		if _pip_pop >= 1.0:
			_pip_pop = -1.0
	_path_deny = maxf(0.0, _path_deny - delta / 0.3)
	if _hold > 0.0:
		_hold -= delta  # hit-stop: the board holds its breath, the rest of the screen runs on
	elif not _cur.is_empty():
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
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	_whiteout = maxf(0.0, _whiteout - delta / 0.14)
	var landed_any := false
	for k in _land.keys():
		if _land[k] >= 1.0:
			landed_any = true
		_land[k] -= delta / 0.26
		if _land[k] <= 0.0:
			_land.erase(k)
	if landed_any:
		Sfx.play("step", randf_range(0.8, 1.0))
	_armed_t += delta
	_glow_t += delta
	if _bump.t > 0.0:
		_bump.t = maxf(0.0, _bump.t - delta / 0.18)
	if _reject.t > 0.0:
		_reject.t = maxf(0.0, _reject.t - delta / 0.3)
	queue_redraw()


# --- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if armed >= 0:
		_armed_input(event)
		return
	if classic:
		_classic_input(event)
		return
	if _path_input(event):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_busy() or not input_enabled:
				# a touch that starts while the board is still moving does nothing, even if it is
				# still held when the board settles
				_touching = false
				accept_event()
				return
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


## Drawn paths: a touch that starts on the robot draws; anything else is a swipe or tap.
## Returns true when the event was taken.
func _path_input(event: InputEvent) -> bool:
	if path_max <= 1 or snap.is_empty() or snap.robot < 0:
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if not input_enabled or is_busy():
				return false
			var rc := cell_center(snap.robot)
			if event.position.distance_to(rc) > cell * 0.7:
				return false
			_drawing = true
			_path_real = snap
			_path_dirs = []
			_path_cells = [snap.robot]
			_path_t = 0.0
			_path_rp = rc
			_finger = event.position
			_path_match.clear()
			_path_groups.clear()
			_slide.clear()
			Sfx.play("tap", 1.5)
			if OS.has_feature("mobile"):
				Input.vibrate_handheld(12)
			accept_event()
			return true
		if _drawing:
			_drawing = false
			_finish_path()
			accept_event()
			return true
	elif event is InputEventScreenDrag and _drawing:
		_finger = event.position
		_path_extend(_cell_at(event.position))
		accept_event()
		return true
	return false


## Walk the path toward the cell under the finger, one cell at a time (a fast finger skips
## cells); going back onto the previous cell takes the last step back.
func _path_extend(target: Vector2i) -> void:
	for guard in 8:
		var last: int = _path_cells[-1]
		var lp := Board.pos(last)
		if target == lp:
			return
		var dv := target - lp
		var step := Vector2i(signi(dv.x), 0) if absi(dv.x) >= absi(dv.y) else Vector2i(0, signi(dv.y))
		var np := lp + step
		if not Board.inside(np):
			return
		var ni := Board.idx(np)
		if _path_cells.size() >= 2 and ni == _path_cells[-2]:
			# back one step: the gem slides back where it was, the note steps down
			var undone: int = _path_cells.pop_back()
			_path_dirs.pop_back()
			_slide[undone] = [cell_center(ni) - cell_center(undone), 0.0]
			_preview()
			Sfx.play("note", pow(2.0, PATH_NOTES[_path_dirs.size()] / 12.0) * 0.5)
			Sfx.play("swap", 0.85)
			continue
		if _path_real.terrain[ni] != T.GROUND:
			return
		if _path_dirs.size() >= path_max:
			if _path_deny <= 0.0:
				_path_deny = 1.0
				Sfx.play("bump", 1.3)
			return
		_path_cells.append(ni)
		_path_dirs.append(step)
		# the gem the robot steps onto slides into the cell it just left
		_slide[last] = [cell_center(ni) - cell_center(last), 0.0]
		_pip_pop = 0.0
		_preview()
		Sfx.play("note", pow(2.0, PATH_NOTES[mini(_path_dirs.size(), PATH_NOTES.size() - 1)] / 12.0) * 0.5)
		Sfx.play("swap", 1.0 + 0.06 * _path_dirs.size())
		fx.emit("path_step", {"pos": cell_global(ni), "n": _path_dirs.size()})
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(8)


## The board as it will stand once the path is walked (swaps only; matching waits for release).
func _preview() -> void:
	var p := _path_real.duplicate()
	var tk: PackedInt32Array = PackedInt32Array(_path_real.token)
	var orr: PackedInt32Array = PackedInt32Array(_path_real.ore)
	var sp: PackedInt32Array = PackedInt32Array(_path_real.spec)
	var cur: int = _path_real.robot
	var pivot := -1
	for k in range(1, _path_cells.size()):
		var ti: int = _path_cells[k]
		var carried := tk[ti] == K.ORE or (tk[ti] == K.CHARGE and sp[ti] != Board.Special.BLAST)
		if carried:
			tk[cur] = tk[ti]
			orr[cur] = orr[ti]
			sp[cur] = sp[ti]
			if tk[cur] == K.ORE:
				pivot = cur
		tk[ti] = K.NONE
		cur = ti
	p.token = tk
	p.ore = orr
	p.spec = sp
	p.robot = cur
	snap = p
	# what would match if the finger lifted now: those gems bounce and glow, and a new line
	# chimes as it forms
	var probe := Board.new()
	probe.terrain = PackedInt32Array(_path_real.terrain)
	probe.token = tk
	probe.ore = orr
	var before := _path_match.size()
	var specials_before := _path_groups.filter(func(g): return g.special >= 0).size()
	_path_match.clear()
	_path_groups.clear()
	for g in probe.find_groups():
		var mid := Vector2.ZERO
		for c in g.cells:
			_path_match[c] = true
			mid += cell_center(c)
		var special := -1
		var at: int = g.cells[0]
		if g.cells.size() >= 4:
			special = probe._special_for(g.cells)
			at = pivot if g.cells.has(pivot) else probe._central(g.cells)
		_path_groups.append({"cells": g.cells, "ore": g.ore, "special": special, "at": at,
				"mid": mid / float(g.cells.size())})
	var specials_now := _path_groups.filter(func(g): return g.special >= 0).size()
	if specials_now > specials_before:
		Sfx.play("forge", 1.2)
	elif _path_match.size() > before:
		Sfx.play("reveal", 1.3 + 0.05 * _path_match.size())
	queue_redraw()


func _finish_path() -> void:
	_path_match.clear()
	_path_groups.clear()
	if _path_dirs.size() <= 1:
		snap = _path_real
		queue_redraw()
		if _path_dirs.size() == 1:
			_request(_path_dirs[0])
		return
	Sfx.play("land", 1.2)
	_rings.append({"c": cell_center(snap.robot), "r0": cell * 0.3, "r1": cell * 1.2,
			"t": 0.0, "dur": 0.26, "color": Color("7fe8ff")})
	add_trauma(0.1)
	path_requested.emit(_path_dirs.duplicate())


## The drawn path was not taken (the dig is busy or over): put the board back.
func cancel_path() -> void:
	_drawing = false
	_path_match.clear()
	_path_groups.clear()
	if not _path_real.is_empty():
		snap = _path_real
		queue_redraw()


func _tap(p: Vector2) -> void:
	if snap.is_empty():
		return
	var c := Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / pitch))
	var r := Board.pos(snap.robot)
	var d := c - r
	if absi(d.x) + absi(d.y) == 1:
		_request(d)


## While a booster is armed the board picks its target instead of moving the robot: a tap
## names a cell; the Laser takes a swipe (or a tap in line with the robot) as its direction.
func _armed_input(event: InputEvent) -> void:
	accept_event()
	if not input_enabled or snap.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = true
			_swiped = false
			_touch_start = event.position
		elif _touching:
			_touching = false
			if not _swiped:
				var c := _cell_at(event.position)
				if not Board.inside(c):
					return
				if armed == Economy.Booster.LASER:
					var d := c - Board.pos(snap.robot)
					if d != Vector2i.ZERO and (d.x == 0 or d.y == 0):
						booster_target.emit(Board.DIRS.find(Vector2i(signi(d.x), signi(d.y))))
				else:
					booster_target.emit(Board.idx(c))
	elif event is InputEventScreenDrag and _touching and not _swiped and armed == Economy.Booster.LASER:
		var d: Vector2 = event.position - _touch_start
		if d.length() > maxf(36.0, cell * 0.28):
			_swiped = true
			var v := Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(d.y)))
			booster_target.emit(Board.DIRS.find(v))


## Classic: swipe a gem toward a neighbour to swap them, or tap one gem and then a neighbour.
func _classic_input(event: InputEvent) -> void:
	accept_event()
	if snap.is_empty() or not input_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = true
			_swiped = false
			_touch_start = event.position
			var c0 := _cell_at(event.position)
			_touch_cell = Board.idx(c0) if Board.inside(c0) else -1
		elif _touching:
			_touching = false
			if _swiped:
				return
			var c := _cell_at(event.position)
			if not Board.inside(c):
				_sel = -1
				return
			var ci := Board.idx(c)
			if _sel >= 0 and ci != _sel:
				var d := c - Board.pos(_sel)
				if absi(d.x) + absi(d.y) == 1:
					var from := _sel
					_sel = -1
					swap_requested.emit(from, d)
					return
			_sel = -1 if _sel == ci else ci
	elif event is InputEventScreenDrag and _touching and not _swiped and _touch_cell >= 0:
		var dv: Vector2 = event.position - _touch_start
		if dv.length() > maxf(36.0, cell * 0.28):
			_swiped = true
			_sel = -1
			var d2 := Vector2i(signi(int(dv.x)), 0) if absf(dv.x) > absf(dv.y) else Vector2i(0, signi(int(dv.y)))
			swap_requested.emit(_touch_cell, d2)


## A classic swap that made no line: the two gems lean in and back.
func reject_swap(a: int, b: int) -> void:
	_reject = {"a": a, "b": b, "t": 1.0}
	Sfx.play("bump")


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / pitch))


func _request(dir: Vector2i) -> void:
	if input_enabled:
		move_requested.emit(dir)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	if snap.is_empty() or cell < 16.0:
		return
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_shake * 10.0 + _trauma * _trauma * 16.0)
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
	_draw_elements()
	_draw_move_hints(moving_to)
	var glowing := not glow.is_empty() and _cur.is_empty() and not _drawing
	if glowing:
		for k in glow.size():
			_draw_glow_halo(glow[k], k)
	var falling: bool = not _cur.is_empty() and _cur.type == "fall"
	var swapping: bool = not _cur.is_empty() and _cur.type == "swap"
	var tok: PackedInt32Array = _cur.snap.token if falling else snap.token
	var kinds: PackedInt32Array = _cur.snap.ore if falling else snap.ore
	var specs: PackedInt32Array = (_cur.snap if falling else snap).get("spec", PackedInt32Array())
	if specs.is_empty():
		specs.resize(Board.W * Board.H)
	for i in Board.W * Board.H:
		if snap.terrain[i] != T.GROUND:
			continue
		if falling and (_fall_from.has(i) or _fall_drop.has(i)):
			# gems drop with gravity, each on its own clock (bottom first, a beat apart), and
			# squash when they land
			var lt := clampf((_t * _dur - float(_fall_delay.get(i, 0.0))) / maxf(0.01, float(_fall_time.get(i, 0.1))), 0.0, 1.0)
			if lt >= 1.0 and not _land.has(i):
				_land[i] = 1.0
			var fp: Vector2 = cell_center(_fall_from[i]) if _fall_from.has(i) else cell_center(i) - Vector2(0, pitch * _fall_drop[i])
			var at2 := fp.lerp(cell_center(i), lt * lt)
			var grow := 1.0
			if not _fall_from.has(i):
				# a new gem enters through the top of its run: it grows in as it crosses the edge
				# (there is nothing above the board to fall from)
				var edge: float = cell_center(i).y - pitch * (float(_fall_drop[i]) - 0.5)
				grow = clampf((at2.y - edge + pitch * 0.5) / pitch, 0.0, 1.0)
				if grow <= 0.0:
					continue
			_tok_squash = _squash_of(i)
			_draw_token(at2, tok[i], kinds[i], _depth_scale(i) * (0.5 + 0.5 * grow), 0.0, specs[i])
			_tok_squash = Vector2.ONE
			continue
		if swapping and (i == _cur.a or i == _cur.b):
			var other: int = _cur.b if i == _cur.a else _cur.a
			_draw_token(cell_center(i).lerp(cell_center(other), _ease(_t)), tok[i], kinds[i], _depth_scale(i) * (1.0 + 0.12 * sin(PI * _t)), 0.0, specs[i])
			continue
		if i == moving_to:
			if _cur.swap:
				var from_p := cell_center(moving_to).lerp(cell_center(moving_from), mt)
				var dsc := lerpf(_depth_scale(moving_to), _depth_scale(moving_from), mt)
				_draw_token(from_p, snap.token[i], snap.ore[i], dsc, 0.0, specs[i])
			else:
				_draw_token(cell_center(i), snap.token[i], snap.ore[i], (1.0 - mt) * _depth_scale(i), 0.0)
			continue
		var sc := _depth_scale(i)
		if not _cur.is_empty() and _cur.type == "belt" and _belt_from.has(i):
			_draw_token(cell_center(_belt_from[i]).lerp(cell_center(i), _ease(_t)), tok[i], kinds[i], sc, 0.0, specs[i])
			continue
		if not _cur.is_empty() and _cur.type == "launch" and not _cur.robot and i == _cur.to:
			var lp := _arc(cell_center(_cur.from), cell_center(i), _t)
			draw_circle(lp, cell * 0.42, Color(PAD_COL, 0.25))
			_draw_token(lp, tok[i], kinds[i], sc * (1.0 + 0.35 * sin(PI * _t)), 0.3 * sin(PI * _t), specs[i])
			continue
		if _rise.has(i):
			sc = _back_out(_rise[i])
		var fl: float = _flash.get(i, 0.0)
		var at := cell_center(i)
		if not _cur.is_empty() and _cur.type == "match" and _phase == 0 and _match_to.has(i):
			# swell for the first third, then rush into the group's middle, shrinking
			var sw := clampf(_t / 0.35, 0.0, 1.0)
			var pull := clampf((_t - 0.3) / 0.7, 0.0, 1.0)
			pull = pull * pull
			at = at.lerp(_match_to[i], pull * 0.9)
			sc *= (1.0 + 0.16 * sin(PI * 0.5 * sw)) * (1.0 - 0.6 * pull)
			fl = 0.35 + 0.65 * pull
		if not _cur.is_empty() and _cur.type == "magnet" and _cur.cells.has(i):
			var k := _ease(clampf(_t * 1.25, 0.0, 1.0))
			at = at.lerp(cell_center(snap.robot), k)
			sc *= 1.0 - 0.45 * k
		if glowing and glow.has(i):
			var hop := _glow_hop(glow.find(i))
			at.y -= cell * 0.1 * hop
			sc *= 1.0 + 0.12 * hop
		if _reject.t > 0.0 and (i == _reject.a or i == _reject.b):
			var other2: int = _reject.b if i == _reject.a else _reject.a
			at = at.lerp(cell_center(other2), 0.35 * sin(PI * (1.0 - _reject.t)))
		if i == _sel:
			sc *= 1.08 + 0.04 * sin(_time * 10.0)
		if _slide.has(i):
			var st: float = _slide[i][1]
			at += (_slide[i][0] as Vector2) * (1.0 - _ease(st))
			at.y -= cell * 0.16 * sin(PI * st)
			sc *= 1.0 + 0.18 * sin(PI * st)
		if _drawing and _path_match.has(i):
			var hop2 := absf(sin(_time * 11.0 + float(i) * 0.7))
			at.y -= cell * 0.07 * hop2
			sc *= 1.06 + 0.04 * hop2
			fl = maxf(fl, 0.22 + 0.12 * hop2)
		_tok_squash = _squash_of(i)
		_draw_token(at, tok[i], kinds[i], sc, fl, specs[i])
		_tok_squash = Vector2.ONE
	var hot := {}
	for p in pads:
		if snap.robot == p or (snap.token[p] == K.CHARGE or snap.token[p] == K.CRYSTAL or snap.token[p] == K.CELL):
			hot[p] = true
	if _drawing or _path_lift > 0.0:
		_draw_outcome(tok, kinds, specs)
	_draw_pad_paths(hot)
	if snap.robot < 0:
		_draw_booster_fx()
		_draw_overlays(glowing)
		draw_set_transform(Vector2.ZERO)
		return
	# robot
	var rp := cell_center(snap.robot)
	var rsc := _depth_scale(snap.robot)
	if moving_to != -1 and _cur.get("portal", false):
		# through a portal: the robot pops out of the far end
		rp = cell_center(moving_to)
		rsc = _depth_scale(moving_to) * _back_out(mt)
	elif moving_to != -1:
		rp = cell_center(moving_from).lerp(cell_center(moving_to), mt)
		# the robot visibly steps down into a pit or climbs out of it
		rsc = lerpf(_depth_scale(moving_from), _depth_scale(moving_to), mt)
	elif not _cur.is_empty() and _cur.type == "drill":
		var tgt := cell_center(_cur.cell)
		rp = rp.lerp(tgt, 0.28 * sin(PI * _t))
	if _bump.t > 0.0:
		rp += _bump.dir * cell * 0.12 * sin(PI * _bump.t)
	if not _cur.is_empty() and _cur.type == "warp":
		rsc *= (1.0 - _ease(_t)) if _phase == 0 else _back_out(_t)
	if not _cur.is_empty() and _cur.type == "fall" and not _cur.robot.is_empty():
		# the robot drops with the gems when what was under it is cleared (through a portal it
		# drops out of the other end)
		var from_c: Vector2 = cell_center(_cur.robot[0])
		if _cur.get("warps", []).has(_cur.robot):
			from_c = cell_center(_cur.robot[1]) - Vector2(0, pitch)
		rp = from_c.lerp(cell_center(_cur.robot[1]), _t * _t)
	if not _cur.is_empty() and _cur.type == "belt" and not _cur.robot.is_empty():
		rp = cell_center(_cur.robot[0]).lerp(cell_center(_cur.robot[1]), _ease(_t))
	if not _cur.is_empty() and _cur.type == "launch" and _cur.robot:
		rp = _arc(cell_center(_cur.from), cell_center(_cur.to), _t)
		rsc *= 1.0 + 0.3 * sin(PI * _t)
	if _drawing or _path_lift > 0.0:
		if _drawing:
			_draw_path()
		var lift := _back_out(_path_lift) if _drawing else _path_lift
		if _drawing:
			# held: the robot strains toward the finger, like something picked up
			var pull := (_finger - _path_rp).limit_length(cell * 0.32)
			rp = _path_rp + pull
		# a soft shadow stays on the board while the robot is held up
		draw_circle(rp + Vector2(0, cell * 0.28), cell * 0.3 * (1.0 - 0.25 * lift), Color(0.05, 0.0, 0.12, 0.28 * lift))
		rp.y -= cell * 0.16 * lift
		rsc *= 1.0 + 0.14 * lift
		rp.x += sin(_time * 18.0) * cell * 0.012 * lift
	_draw_robot(rp, rsc)
	_draw_booster_fx()
	_draw_overlays(glowing)
	draw_set_transform(Vector2.ZERO)


## The path being drawn: a glowing trail through the cells it visits, and pips over the robot
## for the steps left.
func _draw_path() -> void:
	# the trail warms up as the steps run out: cyan, gold, then pink on the last one
	var fill := float(_path_dirs.size()) / maxf(1.0, float(path_max))
	var col := Color("7fe8ff").lerp(Color("ffd96b"), clampf(fill * 1.6, 0.0, 1.0))
	if fill >= 1.0:
		col = Color("ff8ef0")
	var pts := PackedVector2Array()
	for c in _path_cells:
		pts.append(cell_center(c))
	pts[-1] = _path_rp  # the head follows the gliding robot
	if pts.size() > 1:
		var pulse := 1.0 + 0.08 * sin(_time * 9.0)
		draw_polyline(pts, Color(col, 0.18), cell * 0.5 * pulse, true)
		draw_polyline(pts, Color(col, 0.55), cell * 0.2, true)
		draw_polyline(pts, Color(1, 1, 1, 0.95), cell * 0.06, true)
		# energy flowing along the trail toward the robot
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k - 1].distance_to(pts[k])
		var spacing := cell * 0.42
		var s := fmod(_path_t * cell * 2.6, spacing)
		while s < total:
			var p := _along(pts, s)
			draw_circle(p, cell * 0.055, Color(1, 1, 1, 0.9))
			draw_circle(p, cell * 0.1, Color(col, 0.35))
			s += spacing
		for k in range(1, pts.size() - 1):
			draw_circle(pts[k], cell * 0.1, Color(col, 0.9))
			draw_circle(pts[k], cell * 0.05, Color.WHITE)
	# start ring where the robot was picked up
	draw_arc(pts[0], cell * (0.36 + 0.03 * sin(_time * 6.0)), 0.0, TAU, 32, Color(col, 0.7), cell * 0.04, true)
	# pips over the robot: the steps left; the newest pops, a full path shakes them
	var rc := _path_rp - Vector2(0, cell * 0.16 * _back_out(_path_lift))
	var shake := sin(_time * 70.0) * cell * 0.05 * _path_deny
	for k in path_max:
		var x := (k - (path_max - 1) * 0.5) * cell * 0.2 + shake
		var at := rc + Vector2(x, -cell * 0.7)
		var used := k < _path_dirs.size()
		var r := cell * 0.06
		if used and k == _path_dirs.size() - 1 and _pip_pop >= 0.0:
			r *= 1.0 + 0.8 * sin(PI * _pip_pop)
		draw_circle(at, r * 1.4, Color(0.1, 0.03, 0.2, 0.7))
		draw_circle(at, r, Color(1, 1, 1, 0.25) if used else col)


## While a path is drawn: the board dims, and what the release would do stands out. Each line
## that would match glows in its colour with a +N, a line that would make a special shows the
## special waiting where it will appear, and two or more lines call out the combo.
func _draw_outcome(tok: PackedInt32Array, kinds: PackedInt32Array, specs: PackedInt32Array) -> void:
	var k := _path_lift
	for i in Board.W * Board.H:
		if snap.terrain[i] != T.BEDROCK:
			var o := cell_origin(Board.pos(i))
			draw_rect(Rect2(o, Vector2(cell, pitch)), Color(0.04, 0.0, 0.1, 0.38 * k), true)
	for g in _path_groups:
		var col: Color = Pal.ORE[g.ore] if g.ore < Pal.ORE.size() else Color.WHITE
		# a glowing band linking the line's gems
		for c in g.cells:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = Board.pos(c) + d
				if Board.inside(nb) and g.cells.has(Board.idx(nb)):
					draw_line(cell_center(c), cell_center(Board.idx(nb)), Color(col, 0.55 * k), cell * 0.62, true)
		for c in g.cells:
			draw_circle(cell_center(c), cell * (0.46 + 0.03 * sin(_time * 9.0)), Color(col.lightened(0.3), 0.45 * k))
		for c in g.cells:
			var hop := absf(sin(_time * 11.0 + float(c) * 0.7))
			var at := cell_center(c) - Vector2(0, cell * 0.07 * hop)
			_draw_token(at, tok[c], kinds[c], _depth_scale(c) * (1.08 + 0.05 * hop), 0.25 + 0.15 * hop, specs[c])
		if g.special >= 0:
			var sp_at := cell_center(g.at) - Vector2(0, cell * 0.62)
			var pulse := 1.0 + 0.12 * sin(_time * 8.0)
			draw_circle(sp_at, cell * 0.3 * pulse, Color(1, 1, 1, 0.85 * k))
			_draw_special(sp_at, g.special, g.ore, 0.5 * pulse)
		var n: int = g.cells.size()
		var txt := "+%d" % n
		var fs := int(cell * (0.38 + 0.04 * n))
		var tp: Vector2 = g.mid + Vector2(0, -cell * 0.5)
		var tw := _label_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_label_font, tp - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(cell * 0.1), Color(0.15, 0.03, 0.25, k))
		draw_string(_label_font, tp - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, k))
	if _path_groups.size() >= 2:
		var ctxt := "x%d COMBO!" % _path_groups.size()
		var cfs := int(cell * 0.6 * (1.0 + 0.05 * sin(_time * 10.0)))
		var cw := _label_font.get_string_size(ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		var cp := origin + Vector2(cell * Board.W * 0.5 - cw * 0.5, -cell * 0.15)
		draw_string_outline(_label_font, cp, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, int(cell * 0.14), Color(0.2, 0.02, 0.3, k))
		draw_string(_label_font, cp, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color("ffe27a"))


## A launch's flight from a to b: up and over, higher for longer throws.
func _arc(a: Vector2, b: Vector2, t: float) -> Vector2:
	var h := cell * 0.8 + a.distance_to(b) * 0.3
	var e := _ease(t)
	return a.lerp(b, e) - Vector2(0, h * 4.0 * e * (1.0 - e))


## Movement elements on the ground, under the gems: conveyor chevrons that flow, launch pads,
## the dotted flight to each pad's target, and the tunnel gates at the board's edge.
func _draw_elements() -> void:
	for loop in belts:
		var n: int = loop.size()
		for k in n:
			var a := cell_center(loop[k])
			var b := cell_center(loop[(k + 1) % n])
			var d := (b - a).normalized()
			var side := Vector2(-d.y, d.x)
			draw_line(a, b, Color(0.06, 0.1, 0.2, 0.55), cell * 0.78, true)
			draw_line(a + side * cell * 0.39, b + side * cell * 0.39, Color(BELT_COL, 0.35), cell * 0.03, true)
			draw_line(a - side * cell * 0.39, b - side * cell * 0.39, Color(BELT_COL, 0.35), cell * 0.03, true)
			for j in 2:
				var f := fmod(_time * 1.6 + j * 0.5, 1.0)
				var c := a + d * cell * (f - 0.5) * 0.9
				var al := sin(PI * f) * 0.75
				draw_polyline(PackedVector2Array([c - d * cell * 0.1 + side * cell * 0.16, c + d * cell * 0.06, c - d * cell * 0.1 - side * cell * 0.16]),
						Color(BELT_COL, al), cell * 0.05, true)
	for p in pads:
		var c := cell_center(p)
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(c, cell * 0.44, Color(PAD_COL, 0.22 + 0.1 * pulse))
		draw_arc(c, cell * 0.42, 0.0, TAU, 40, Color(PAD_COL, 0.9), cell * 0.05, true)
		draw_arc(c, cell * (0.26 + 0.06 * pulse), 0.0, TAU, 32, Color(1, 0.95, 0.8, 0.6), cell * 0.03, true)
	for t in tunnels:
		for e in [[t[0], t[1]], [t[2], t[3]]]:
			var c := cell_center(e[0]) + Vector2(e[1]) * cell * 0.5
			var ang := Vector2(e[1]).angle()
			draw_arc(c, cell * 0.36, ang - PI * 0.5, ang + PI * 0.5, 20, Color(WARP_COL, 0.85), cell * 0.08, true)
			draw_arc(c, cell * 0.24, ang - PI * 0.5, ang + PI * 0.5, 16, Color(1, 1, 1, 0.4 + 0.3 * sin(_time * 5.0)), cell * 0.04, true)


## Over the gems: each pad's flight path, dotted, and the target it hits.
func _draw_pad_paths(hot: Dictionary) -> void:
	for p in pads:
		var a := cell_center(p)
		var b := cell_center(pads[p])
		var on := hot.has(p)
		# the pad itself, over its gem: a bright ring with chevrons pointing along the throw
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_arc(a, cell * 0.47, 0.0, TAU, 40, Color(PAD_COL, 0.95), cell * 0.07, true)
		var up := (_arc(a, b, 0.06) - a).normalized()
		var sd := Vector2(-up.y, up.x)
		for j in 2:
			var c0 := a + up * cell * (0.5 + 0.12 * j + 0.06 * pulse)
			draw_polyline(PackedVector2Array([c0 - up * cell * 0.1 + sd * cell * 0.14, c0, c0 - up * cell * 0.1 - sd * cell * 0.14]),
					Color(PAD_COL, 0.9 - 0.3 * j), cell * 0.06, true)
		var col := Color(PAD_COL, 1.0 if on else 0.75)
		var n := 16
		for k in n:
			var f := (float(k) + fmod(_time * (3.0 if on else 1.2), 1.0)) / n
			draw_circle(_arc(a, b, f), cell * (0.08 if on else 0.055), Color(0.1, 0.02, 0.2, 0.5))
			draw_circle(_arc(a, b, f), cell * (0.06 if on else 0.04), col)
		var r := cell * (0.4 + (0.06 * sin(_time * 10.0) if on else 0.0))
		draw_arc(b, r, 0.0, TAU, 32, col, cell * (0.06 if on else 0.035), true)
		draw_line(b - Vector2(r * 0.6, 0), b + Vector2(r * 0.6, 0), col, cell * 0.03, true)
		draw_line(b - Vector2(0, r * 0.6), b + Vector2(0, r * 0.6), col, cell * 0.03, true)


## The point `s` px along a polyline.
func _along(pts: PackedVector2Array, s: float) -> Vector2:
	for k in range(1, pts.size()):
		var l := pts[k - 1].distance_to(pts[k])
		if s <= l:
			return pts[k - 1].lerp(pts[k], s / maxf(0.001, l))
		s -= l
	return pts[-1]


## Over everything on the board: the idle-hint sparks, Mira's focus frames, the pulse rings.
func _draw_overlays(glowing: bool) -> void:
	_draw_portals()
	if _whiteout > 0.0:
		# a big blast washes the board white for a blink
		draw_rect(Rect2(origin - Vector2(cell, cell) * 0.2, Vector2(cell * Board.W, pitch * Board.H) + Vector2(cell, cell) * 0.4),
				Color(1.0, 0.97, 0.9, 0.42 * _whiteout))
	if glowing:
		for k in glow.size():
			_draw_glow_sparks(glow[k], k)
	for f in focus:
		var fc: Vector2i = f
		if not Board.inside(fc):
			continue
		_tile_outline(Board.idx(fc), Color(Pal.WARN, 0.9), cell * 0.012 + cell * 0.018 * (0.5 + 0.5 * sin(_time * 6.0)))
	if _sel >= 0:
		_tile_outline(_sel, Color(1, 1, 1, 0.85), cell * 0.03)
	for r in _rings:
		if r.t < 0.0:
			continue
		var k: float = r.t / r.dur
		var col: Color = r.color
		col.a = 1.0 - k
		draw_arc(r.c, lerpf(r.r0, r.r1, _ease(k)), 0, TAU, 48, col, 8.0 * (1.0 - k) + 2.0, true)


## A portal: a magenta mouth under its source cell, a cyan one over its destination, both
## swirling; what falls into the first drops out of the second.
func _draw_portals() -> void:
	for pp in portals:
		for end in 2:
			var i: int = pp[end]
			var r := _rect(i, 0)
			var c := Vector2(r.get_center().x, r.end.y if end == 0 else r.position.y)
			var col := Color("ff6bd8") if end == 0 else Color("7fe8ff")
			var w := r.size.x * 0.42
			draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, w * 1.1, Color(col, 0.22), true, -1.0, true)
			for k in 3:
				var ph := fmod(_time * 0.9 + k / 3.0, 1.0)
				draw_arc(Vector2.ZERO, w * (0.35 + 0.75 * ph), 0, TAU, 36, Color(col, 0.9 * (1.0 - ph)), 5.0, true)
			draw_arc(Vector2.ZERO, w, 0, TAU, 40, col, 6.0, true)
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


## The armed booster's targets, and the booster steps' own drawing (the falling bomb, the beam).
func _draw_booster_fx() -> void:
	if armed >= 0 and _cur.is_empty():
		var pulse := 0.5 + 0.5 * sin(_armed_t * 7.0)
		if armed == Economy.Booster.LASER:
			var rp := cell_center(snap.robot)
			for d in Board.DIRS:
				var q: Vector2i = Board.pos(snap.robot) + d
				if Board.inside(q) and snap.terrain[Board.idx(q)] != T.BEDROCK:
					var c := cell_center(Board.idx(q))
					_chevron(c + Vector2(d) * cell * 0.12 * pulse, Vector2(d), Color(Color("7fe8ff"), 0.6 + 0.4 * pulse))
			draw_arc(rp, cell * (0.55 + 0.06 * pulse), 0, TAU, 40, Color(Color("7fe8ff"), 0.8), 4.0, true)
		else:
			for i in Board.W * Board.H:
				var ok := false
				match armed:
					Economy.Booster.BOMB: ok = snap.terrain[i] != T.BEDROCK
					Economy.Booster.WARP: ok = snap.terrain[i] == T.GROUND and i != snap.robot
					Economy.Booster.MAGNET: ok = snap.terrain[i] == T.GROUND and snap.token[i] == K.ORE
				if ok:
					_tile_outline(i, Color(1, 1, 1, 0.12 + 0.18 * pulse), cell * 0.02)
	if _cur.is_empty():
		return
	match _cur.type:
		"special":
			var col2: Color = SPECIAL_COL[_cur.kind]
			var k2 := sin(PI * _t)
			for ray in _cur.rays:
				var a2 := cell_center(ray[0])
				var b2 := cell_center(ray[1])
				if ray[1] == ray[0]:
					continue
				draw_line(a2, b2, Color(col2, 0.35 * k2), cell * 0.5 * k2, true)
				draw_line(a2, b2, Color(col2, 0.9 * k2), cell * 0.22 * k2, true)
				draw_line(a2, b2, Color(1, 1, 1, k2), cell * 0.07 * k2, true)
			if _cur.kind == Board.Special.GEODE:
				for c3 in _cur.turned:
					var p3 := cell_center(c3)
					draw_line(cell_center(_cur.at), p3, Color(Pal.ORE[_cur.ore], 0.8 * k2), cell * 0.08, true)
		"bomb":
			var tex := Art.tex("res://assets/ui/boosters/bomb.png")
			var k := _ease(_t)
			var c := cell_center(_cur.center) - Vector2(0, cell * 2.2 * (1.0 - k))
			var w := cell * lerpf(1.6, 0.95, k)
			draw_texture_rect(tex, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false)
		"laser":
			if _cur.cells.is_empty():
				return
			var a := cell_center(_cur.from)
			var b := cell_center(_cur.cells[-1]) + Vector2(Board.DIRS[_cur.dir]) * cell * 0.5
			var k := sin(PI * _t)
			var col := Color("7fe8ff")
			draw_line(a, b, Color(col, 0.35 * k), cell * 0.62 * k, true)
			draw_line(a, b, Color(col, 0.9 * k), cell * 0.3 * k, true)
			draw_line(a, b, Color(1, 1, 1, k), cell * 0.1 * k, true)
			draw_circle(a, cell * 0.32 * k, Color(1, 1, 1, 0.9 * k), true, -1.0, true)
		"magnet":
			var tex := Art.tex("res://assets/ui/boosters/magnet.png")
			var w := cell * (1.0 + 0.15 * sin(_t * 20.0))
			var c := cell_center(snap.robot) - Vector2(0, cell * 0.9)
			draw_texture_rect(tex, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false)


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
	if res > 0 and not gravity:
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
	if snap.buried[i] == Board.Buried.TREASURE:
		_draw_chest(i, r)
		return
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
	if t == T.GROUND and res > 0 and not gravity:
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
			var gem := Art.ore(Board.RES_CRYSTAL) if _art else null
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
	if moving_to != -1 or is_busy() or snap.robot < 0:
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


func _draw_token(c: Vector2, tk: int, kind: int, sc: float, flash: float, sp := 0) -> void:
	if tk == K.NONE or sc <= 0.01:
		return
	if tk == K.CHARGE and (sp != Board.Special.BLAST or Art.tex("res://assets/ui/specials/blast.png") != null):
		_draw_special(c, sp, kind, sc)
		if flash > 0.0:
			draw_circle(c, cell * 0.43 * sc, Color(1, 1, 1, 0.55 * flash))
		return
	var s := cell * 0.33 * sc
	var art := Art.ore(kind) if tk == K.ORE and _art else null
	if art != null:
		var size := cell * ORE_SIZE * sc
		var sz := Vector2(size, size) * _tok_squash
		if flash > 0.0:
			# a match lights the gem from behind: a soft halo, the gem itself stays crisp
			var hc: Color = Pal.ORE[kind].lightened(0.5)
			draw_circle(c, s * 1.55, Color(hc, 0.18 * flash), true, -1.0, true)
			draw_circle(c, s * 1.25, Color(1, 1, 1, 0.32 * flash), true, -1.0, true)
		# squash from the bottom: a landing gem flattens onto its cell, it doesn't shrink upward
		_draw_lifted(art, Rect2(c + Vector2(-sz.x * 0.5, size * 0.5 - sz.y), sz))
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
			var gem := Art.ore(Board.RES_CRYSTAL) if _art else null
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


## A moved-special gem: its own colour's gem, a halo in the special's colour and an emblem
## that says what it does (a drill bit, an X of light, a cracked geode, rings).
const SPECIAL_COL := [Color("ff4f6d"), Color("ffb347"), Color("e8f6ff"), Color("c88bff"), Color("7fe8ff")]
const SPECIAL_ART := ["blast", "drill", "prism", "geode", "quake"]


func _draw_special(c: Vector2, sp: int, kind: int, sc: float) -> void:
	var s := cell * 0.33 * sc
	var col: Color = SPECIAL_COL[sp]
	if sp == Board.Special.GEODE:
		col = Pal.ORE[kind]  # a geode glows in the colour it will turn its neighbours
	var pul := 0.5 + 0.5 * sin(_time * 7.0 + c.x * 0.05)
	draw_circle(c, s * 1.45, Color(col, 0.18 + 0.16 * pul), true, -1.0, true)
	# a special is an object of its own, never drawn on a gem: a coloured gem would ask to be
	# matched, and specials go off when MOVED (Royal Match's power-ups read the same way)
	var tex := Art.tex("res://assets/ui/specials/%s.png" % SPECIAL_ART[sp])
	if tex != null:
		var size := cell * 0.86 * sc * (1.0 + 0.05 * pul)
		_draw_lifted(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)))
		return
	var w := maxf(3.0, s * 0.15)
	var dark := Color(0.08, 0.02, 0.16, 0.9)
	# no art yet: an emblem disc, dark face with the special's colour as its rim
	var r := s * 1.0
	draw_circle(c + Vector2(0, s * 0.06), r * 1.12, Color(0, 0, 0, 0.35), true, -1.0, true)
	draw_circle(c, r * 1.12, col, true, -1.0, true)
	draw_circle(c, r, dark, true, -1.0, true)
	match sp:
		Board.Special.DRILL:
			# a drill bit pointing up: a cone with two grooves
			var tip := c + Vector2(0, -r * 0.8)
			var bl := c + Vector2(-r * 0.5, r * 0.45)
			var br := c + Vector2(r * 0.5, r * 0.45)
			draw_colored_polygon(PackedVector2Array([tip, br, bl]), col)
			draw_line(c + Vector2(-r * 0.36, r * 0.05), c + Vector2(r * 0.2, -r * 0.22), dark, w * 0.7, true)
			draw_line(c + Vector2(-r * 0.2, r * 0.32), c + Vector2(r * 0.36, r * 0.05), dark, w * 0.7, true)
			draw_rect(Rect2(c + Vector2(-r * 0.22, r * 0.45), Vector2(r * 0.44, r * 0.3)), col.darkened(0.25))
		Board.Special.PRISM:
			for k in 4:
				var a2 := PI * 0.25 + k * PI * 0.5
				draw_line(c, c + Vector2(cos(a2), sin(a2)) * r * (0.82 + 0.12 * pul), col, w * 1.2, true)
			draw_circle(c, r * 0.24, Color.WHITE, true, -1.0, true)
		Board.Special.GEODE:
			# a cracked gem: a small diamond of its colour with light breaking out
			var gc: Color = Pal.ORE[kind].lightened(0.2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.6, 0), c + Vector2(0, r * 0.7), c + Vector2(-r * 0.6, 0)]), gc)
			draw_line(c + Vector2(-r * 0.15, -r * 0.5), c + Vector2(r * 0.1, 0), dark, w * 0.6, true)
			draw_line(c + Vector2(r * 0.1, 0), c + Vector2(-r * 0.1, r * 0.45), dark, w * 0.6, true)
			draw_arc(c, r * 0.95, 0, TAU, 32, Color(gc, 0.5 + 0.5 * pul), w * 0.6, true)
		Board.Special.QUAKE:
			for k in 2:
				var ph := fmod(_time * 1.2 + k * 0.5, 1.0)
				draw_arc(c, r * (0.25 + 0.7 * ph), 0, TAU, 32, Color(col, 1.0 - ph), w * 0.9, true)
			draw_circle(c, r * 0.22, col, true, -1.0, true)

## A landed gem's squash: flat and wide on impact, springing back tall, settling (~0.25 s).
func _squash_of(i: int) -> Vector2:
	if not _land.has(i):
		return Vector2.ONE
	var u: float = 1.0 - _land[i]
	var w := exp(-u * 6.0) * cos(u * 17.0)
	return Vector2(1.0 + 0.13 * w, 1.0 - 0.13 * w)


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
	_frame.position = Vector2.ZERO
	_frame.size = size + Vector2(over, over) * 2.0
	_frame_vp.size = Vector2i(ceili(_frame.size.x), ceili(_frame.size.y))
	_frame_img.position = -Vector2(over, over)
	_frame_img.size = Vector2(_frame_vp.size)
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
	# render it once (the next frame), then keep showing that texture
	_frame_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


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
