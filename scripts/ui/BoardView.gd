class_name BoardView
extends Control

## Draws a board snapshot and animates the step list returned by Board.try_move().
## Rules never live here: the view only replays what the Board already decided, and while a
## path is drawn it shows what the Board says the path will do (Board.preview_path).

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
const MAX_CELL := 132.0      # px (of the 1080-wide layout): the largest a cell may get
const GAP := 0.0            # px between neighbouring blocks (the cell art carries its own margin)
const ROCK_SIZE := 1.2      # rock sprite canvas / cell (the body is ~80% of it): rock fills its tile, bigger than a gem
## Rock by layers left (Royal Match's boxes): every match peels one, so thick rock is dark and
## turns lighter as it is worn down; the crack state (Art.rock) shows how much is gone.
const ROCK_TINT := [Color(1, 1, 1), Color(0.62, 0.58, 0.78), Color(0.38, 0.34, 0.5)]
const ORE_SIZE := 0.94      # ore sprite canvas / cell (the gem is ~80% of its canvas)

var snap: Dictionary = {}
var scanner := false
var drill := false
var cell := 130.0
var pitch := 130.0          # distance between rows (cell + visible band with the painted art)
var origin := Vector2.ZERO
var hint_dir := -1
var focus: Array = []   # cells Mira is talking about; drawn as pulsing frames
## A guided move (a lesson): the cells it goes through, the robot's first. A hand draws it over
## and over, the rest of the board dims, and a path can only follow it. [] when free play.
var guide: Array = []
var _guide_t := 0.0
const HAND_TIP := Vector2(0.22, 0.0)  # the fingertip in hand.png, as a share of its size
## Gems of a match within reach, shown after the player has been idle a while: they hop one
## after another with a halo and sparkles (set with set_glow, cleared on the next move).
var glow: Array = []
var _glow_t := 0.0
var input_enabled := true
var armed := -1   # Economy.Booster waiting for its target, or -1
var classic := false  # the classic prototype: no robot, a swipe on a gem swaps it
## Drawn paths: hold the robot and draw up to path_max steps. While the finger is down the
## board shows the swaps live (a preview snap); lifting it sends the path as one move.
var path_max := 1     # steps a drawn path may take on this dig (a lesson may hold it to 1)
var drag_input := false  # moves are drawn from anywhere (Settings: Path on); else a swipe on the board
var board: Board  # the dig's board, read only: asked where a path may go and what it will do
var pads := {}       # launch pad cell -> target cell
var belts: Array = []  # conveyor loops of cells
var teleports := {}   # teleporter cell -> its twin
var docks := {}       # cells where an energy core is delivered
const OBS_DIR := "res://assets/obstacles/"
const CORE_COL := Color("5ff2c8")
var _obs_jolt := {}   # obstacle index -> 1..0: it shudders when hit
var web_tex_override: Texture2D  # dev only (DevShot ASTRO_WEBTEX): try a web design in game
var _puffs: Array = []  # torn webs: [{c: Vector2, t: 0..1, spin}] silk bursting off the cell
var _bursts: Array = []  # broken rock: [{c: Vector2, t: 0..1, spin, flip}] stone flying apart
var _fly := 1.0       # a step with drones: the share of it they spend flying (what they carry goes off after)
var _obs_glow := {}   # obstacle index -> 1..0: the flash of finishing (a generator switching on)
const TELE_COLS := [Color("5ff2ff"), Color("ff6bd8"), Color("b6ff5c"), Color("ffd24a")]
var _path_tele := -1  # while drawing: the twin the robot would come out of, or -1
var _tele_arm := 0.0  # 1 -> 0: the flash when a path comes to rest on a teleporter
var _path_specials := {}  # while drawing: dragged special's cell -> [where it goes off, way it fires]
var _path_combo := {}     # while drawing: the power-ups the path merges ({at, from, kinds, name}), or {}
var _spec_angle := {}     # cell -> the angle a dragged Drill is drawn at (it turns to aim)
var _tok_rot := 0.0       # rotation for the next special drawn (_draw_special)
var _draw_off := Vector2.ZERO
var _finger := Vector2.ZERO  # where the drawing finger aims (local)
var _lean := Vector2.ZERO    # the held robot's lean toward its next step (local, smoothed)
var _belt_from := {}  # during a belt step: cell -> the cell its token came from
var _belt_run := 0.0    # 0..1: how hard the belt is running (only while it moves)
var _belt_phase := 0.0  # where the chevrons are along each cell
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
var _fall_route := {} # during a fall step: cell -> the route (points) its piece takes there
var _fall_len := {}   # cell -> the route's length in cells (a diagonal step counts as one)
var _fall_entry := {} # new gem's cell -> the y (px) of the top edge of the run it enters through
var _reject := {"a": -1, "b": -1, "t": 0.0}  # a swap that made no line wobbles back
# --- juice (docs/research/match3-combo-juice.md) ---
# falls (docs/research/match3-fluid-falls.md, Unity's Gem Hunter Match): each piece runs its own
# route at once, speeding up from FALL_V0 to FALL_VMAX cells/s, then lands with a squash and a hop
const FALL_V0 := 4.0          # cells/s a piece starts falling at
const FALL_A := 16.0          # cells/s² it gathers speed
const FALL_VMAX := 11.0       # cells/s top speed (1 cell ~0.18 s, 3 ~0.45 s, 8 ~0.85 s)
const FALL_STAGGER := 0.025   # s between pieces starting to fall, bottom first, up a column
# a landing never stops a gem dead: its speed runs on into a damped spring that squashes it
# flat (its bottom stays on the floor), springs it back up a little tall, and settles it
const LAND_TIME := 0.36       # s a landing lasts (the spring is still by then)
const LAND_W := 30.0          # rad/s: the spring's stiffness (a slow, soft ~0.2 s wobble)
const LAND_DAMP := 0.45       # its damping: one gentle wobble, then still
const LAND_MAX := 0.08        # squash of a drop at top speed (a short one less): slight
const GEM_HALF := 0.47        # half a gem's height in cells (ORE_SIZE / 2): where its bottom is
const CHAIN_NOTES := [0, 4, 7, 12, 16, 19, 24]  # semitones: each cascade climbs a major chord
var _match_to := {}   # matched cell -> where its group pulls together (centre of the group)
var _fall_delay := {} # falling cell -> s before it starts to fall
var _fall_time := {}  # falling cell -> s its drop takes
var _land := {}       # cell -> 1..0 landing squash after a drop
var _land_k := {}     # cell -> cells/s it landed at (a short drop bounces less)
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
	cell = minf(cell, MAX_CELL)  # a tablet (or a small 7-wide board) doesn't blow the board up
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
			_fall_route.clear()
			_fall_len.clear()
			_fall_entry.clear()
			_fall_delay.clear()
			_fall_time.clear()
			var paths: Dictionary = _cur.get("paths", {})
			for c in paths:
				var pts := PackedVector2Array()
				var length := 0.0
				for k in paths[c].size():
					var g: Vector2 = paths[c][k]
					pts.append(origin + Vector2(g.x * cell, g.y * pitch) + Vector2(cell, cell) * 0.5)
					if k > 0:
						var d: Vector2 = (g - paths[c][k - 1]).abs()
						length += maxf(d.x, d.y)
				_fall_route[c] = pts
				_fall_len[c] = maxf(length, 0.01)
			for sp in _cur.spawns:
				_fall_entry[sp[0]] = cell_origin(Vector2i(0, sp[1])).y
			for wp in _cur.get("warps", []):
				# out of the portal: it drops in from just above
				_fall_route[wp[1]] = PackedVector2Array([cell_center(wp[1]) - Vector2(0, pitch), cell_center(wp[1])])
				_fall_len[wp[1]] = 1.0
			if not _cur.get("warps", []).is_empty():
				Sfx.play("warp", 1.2)
			# bottom first, a beat apart up the column it starts in, with a faint ripple across
			var cols := {}  # x -> [[start y, cell]]
			for c in _fall_route:
				var st: Vector2 = _fall_route[c][0]
				var x := int(round((st.x - origin.x - cell * 0.5) / cell))
				cols[x] = cols.get(x, []) + [[st.y, c]]
			var end := 0.05
			for x in cols:
				var list: Array = cols[x]
				list.sort_custom(func(p, q): return p[0] > q[0])
				for k in list.size():
					var cc: int = list[k][1]
					_fall_delay[cc] = k * FALL_STAGGER + 0.004 * float((x * 7) % 5)
					_fall_time[cc] = _fall_secs(_fall_len[cc])
					end = maxf(end, _fall_delay[cc] + _fall_time[cc])
			if not _cur.robot.is_empty():
				var rd: int = maxi(1, Board.pos(_cur.robot[1]).y - Board.pos(_cur.robot[0]).y)
				end = maxf(end, _fall_secs(rd))
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
		"teleport":
			# in through one, out of the other: shrink and spin away, pop out of the twin
			_dur = 0.42
			_rings.append({"c": cell_center(_cur.from), "r0": cell * 0.7, "r1": cell * 0.1,
					"t": 0.0, "dur": 0.2, "color": _tele_col(_cur.from)})
			Sfx.play("teleport")
			add_trauma(0.14)
			fx.emit("path_step", {"pos": cell_global(_cur.from), "n": 10})
		"belt":
			# a clear, separate shove per step: the belt revs, everything on it slides one cell
			_dur = 0.3
			_belt_from.clear()
			for m in _cur.moves:
				_belt_from[m[1]] = m[0]
			Sfx.play("step", 0.7)
			Sfx.play("swap", 0.6)
		"special":
			# the first power-up gets its moment; the ones it sets off rattle after it almost at once
			# (Royal Match's chains go off nearly together), each a little higher in pitch
			var link: int = _cur.get("link", 1)
			var combo: String = _cur.get("combo", "")
			var first := link == 1
			match _cur.kind:
				Board.Special.BLACKHOLE: _dur = 0.45
				Board.Special.NOVA: _dur = 0.32
				_: _dur = 0.28
			if not _cur.flights.is_empty():
				_dur = 0.6
			if combo != "":
				_dur = 0.5
			if not first:
				_dur = 0.12
			# drones fly first; a power-up one carries goes off only once it has landed
			_fly = 1.0
			var carrying := false
			for f in _cur.flights:
				carrying = carrying or int(f[2]) >= 0
			if not _cur.flights.is_empty():
				var flight := 0.6 if first else 0.45
				_dur = flight + (0.32 if carrying else 0.0)
				_fly = flight / _dur
			_shake = 0.3 if first else 0.15
			add_trauma(minf(1.0, (0.45 if first else 0.12) + (0.3 if combo != "" else 0.0)))
			if first:
				_whiteout = 0.6
				_hold = 0.05
			var landing := {}
			for f in _cur.flights:
				landing[f[1]] = true
			for c in _cur.hit:
				if not landing.has(c) and _cur.flights.all(func(f): return int(f[2]) < 0):
					_flash[c] = 1.0  # what a drone hits lights up when it lands, not before
			for c in _cur.turned:
				_flash[c] = 1.0
			var col: Color = SPECIAL_COL[_cur.kind]
			var at := cell_center(_cur.at)
			var up := pow(2.0, mini(link - 1, 8) / 12.0)
			match _cur.kind:
				Board.Special.NOVA:
					_rings.append({"c": at, "r0": cell * 0.3, "r1": cell * 3.0, "t": 0.0, "dur": 0.45, "color": col})
					_rings.append({"c": at, "r0": cell * 0.2, "r1": cell * 2.4, "t": -0.08, "dur": 0.45, "color": Color.WHITE})
					Sfx.play("blast", up)
				Board.Special.BLACKHOLE:
					_rings.append({"c": at, "r0": cell * 3.0, "r1": cell * 0.2, "t": 0.0, "dur": 0.6, "color": col})
					Sfx.play("magnet", up)
					Sfx.play("warp", 0.7 * up)
				Board.Special.PULSAR:
					Sfx.play("laser", up)
				Board.Special.DRONE:
					_rings.append({"c": at, "r0": cell * 0.2, "r1": cell * 1.3, "t": 0.0, "dur": 0.3, "color": col})
					Sfx.play("warp", 1.3 * up)
				_:
					Sfx.play("blast", up)
			if combo != "":
				Sfx.play("quake")
				fx.emit("callout", {"text": combo + "!", "big": combo == "BIG BANG"})
			elif link in [3, 5, 8]:
				fx.emit("callout", {"text": "CHAIN x%d" % link, "big": false})
		"bomb":
			_dur = 0.3  # the bomb drops onto its cell; the blast step that follows does the rest
			Sfx.play("bombdrop")
		"merge":
			# the power-ups a path dragged fly into the last one and fuse: the combo comes next
			_dur = 0.24
			Sfx.play("forge", 0.8)
			Sfx.play("telearm", 1.2)
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
				if _cur.cracked.any(func(r): return not _cur.revealed.has(r)):
					Sfx.play("rockcrack", randf_range(0.92, 1.08))  # a layer off, still standing
				_reveal_fx(_cur.revealed)
				for c in _cur.surfaced:
					_rise[c] = 0.0
				for c in _cur.charges:
					_rise[c] = 0.0
				if not _cur.charges.is_empty():
					Sfx.play("forge")
				_obstacle_fx(_cur)
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
			_obstacle_fx(_cur)
			fx.emit("blast_done", {"cells": _cur.cells.map(func(c): return cell_global(c))})
			_apply(_cur.snap)
			_next_step()
		"special":
			_emit_extract(_cur.hit)
			for f in _cur.flights:
				_rings.append({"c": cell_center(f[1]), "r0": cell * 0.2, "r1": cell * 1.2, "t": 0.0, "dur": 0.3, "color": SPECIAL_COL[Board.Special.DRONE]})
				fx.emit("blast_done", {"cells": [cell_global(f[1])]})
				Sfx.play("pickup", 1.3)
				add_trauma(0.12)
			for r in _cur.cracked:
				_jolt[r] = 1.0
				fx.emit("debris", {"pos": cell_global(r), "color": Pal.ROCK[1]})
			_reveal_fx(_cur.revealed)
			_obstacle_fx(_cur)
			fx.emit("blast_done", {"cells": [cell_global(_cur.at)]})
			_flash.clear()
			_apply(_cur.snap)
			_next_step()
		"fall":
			if not _fall_route.is_empty():
				Sfx.play("land", randf_range(0.95, 1.1))
			for c in _cur.collected:
				var res: int = Board.RES_CRYSTAL if snap.token[c] == K.CRYSTAL else -1
				if snap.token[c] == K.CORE:
					# delivered: the core sinks into the dock in a burst of light
					_rings.append({"c": cell_center(c), "r0": cell * 0.6, "r1": cell * 0.1, "t": 0.0, "dur": 0.3, "color": CORE_COL})
					_rings.append({"c": cell_center(c), "r0": cell * 0.3, "r1": cell * 1.8, "t": -0.1, "dur": 0.45, "color": Color.WHITE})
					fx.emit("path_step", {"pos": cell_global(c), "n": 14})
					add_trauma(0.25)
					Sfx.play("teleport", 0.9)
					Sfx.play("collect")
				elif res >= 0:
					Sfx.play("pickup")
					fx.emit("pickup", {"pos": cell_global(c), "res": res})
				else:
					Sfx.play("cell")
					fx.emit("energy", {"pos": cell_global(c), "amount": 0})
			_fall_route.clear()
			_fall_entry.clear()
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
			_obstacle_fx(_cur)
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
		"merge":
			_rings.append({"c": cell_center(_cur.to), "r0": cell * 1.4, "r1": cell * 0.2, "t": 0.0, "dur": 0.25, "color": Color.WHITE})
			add_trauma(0.35)
			_apply(_cur.snap)
			_next_step()
		"launch":
			_rings.append({"c": cell_center(_cur.to), "r0": cell * 0.2, "r1": cell * 1.4,
					"t": 0.0, "dur": 0.32, "color": PAD_COL})
			_land[_cur.to] = 1.0
			_land_k[_cur.to] = 8.0  # thrown: it comes down hard and bounces
			fx.emit("blast_done", {"cells": [cell_global(_cur.to)]})
			Sfx.play("land", 0.8)
			if _cur.robot:
				add_trauma(0.15)
			_apply(_cur.snap)
			_next_step()
		"belt":
			_belt_from.clear()
			Sfx.play("land", 0.7)
			for m in _cur.moves:
				_land[m[1]] = 0.6
			_apply(_cur.snap)
			_next_step()
		"teleport":
			_rings.append({"c": cell_center(_cur.to), "r0": cell * 0.2, "r1": cell * 1.3,
					"t": 0.0, "dur": 0.3, "color": _tele_col(_cur.to)})
			_rings.append({"c": cell_center(_cur.to), "r0": cell * 0.1, "r1": cell * 2.0,
					"t": -0.06, "dur": 0.4, "color": Color.WHITE})
			fx.emit("path_step", {"pos": cell_global(_cur.to), "n": 14})
			fx.emit("blast_done", {"cells": [cell_global(_cur.to)]})
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
	# rock breaks open: stone bursts apart in a puff of dust, with a crunchy shatter
	Sfx.play("rockbreak", 1.0 + 0.04 * mini(cells.size() - 1, 6))
	Sfx.play("reveal", 1.2)
	add_trauma(minf(0.25, 0.06 * cells.size()))
	for c in cells:
		_bursts.append({"c": cell_center(c), "t": 0.0, "spin": randf_range(-0.5, 0.5), "flip": randf() < 0.5})
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
	# the held robot leans only as the aim nears its next step, and smoothly, so a shaky thumb
	# never shakes it and it never leans back after a step
	var lean_to := Vector2.ZERO
	if _drawing and not snap.is_empty() and snap.robot >= 0:
		var off := (_finger - cell_center(snap.robot)) / (Vector2(cell, pitch) * DRAG_STEP)
		# from the first step's start, the lean shows the finger is felt at once; after a step the
		# aim rests ~0.4 behind the new cell, so the lean waits until it is past that
		var dz := 0.08 if _path_dirs.is_empty() else 0.4
		if off.length() > 0.001:
			lean_to = off.normalized() * smoothstep(dz, STEP_AT, off.length()) * cell * 0.2
	_lean = _lean.lerp(lean_to, 1.0 - exp(-delta * 20.0))
	for k in _slide.keys():
		_slide[k][1] += delta / 0.11
		if _slide[k][1] >= 1.0:
			_slide.erase(k)
	if _pip_pop >= 0.0:
		_pip_pop += delta / 0.22
		if _pip_pop >= 1.0:
			_pip_pop = -1.0
	_path_deny = maxf(0.0, _path_deny - delta / 0.3)
	_tele_arm = maxf(0.0, _tele_arm - delta / 0.35)
	_guide_t += delta
	var belting: bool = not _cur.is_empty() and _cur.type == "belt"
	_belt_run = move_toward(_belt_run, 1.0 if belting else 0.0, delta / (0.06 if belting else 0.3))
	_belt_phase = fmod(_belt_phase + delta * 3.4 * _belt_run, 1.0)
	for c in _spec_angle.keys():
		if not _path_specials.has(c):
			_spec_angle.erase(c)
	for c in _path_specials:
		var target_a := Vector2(_path_specials[c][1]).angle() + PI * 0.5
		_spec_angle[c] = lerp_angle(float(_spec_angle.get(c, 0.0)), target_a, 1.0 - exp(-delta * 16.0))
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
	for k in _obs_jolt.keys():
		_obs_jolt[k] -= delta / 0.3
		if _obs_jolt[k] <= 0.0:
			_obs_jolt.erase(k)
	for p in _puffs:
		p.t += delta / 0.38
	for b in _bursts:
		b.t += delta / 0.42
	_bursts = _bursts.filter(func(b): return b.t < 1.0)
	_puffs = _puffs.filter(func(p): return p.t < 1.0)
	for k in _obs_glow.keys():
		_obs_glow[k] -= delta / 0.6
		if _obs_glow[k] <= 0.0:
			_obs_glow.erase(k)
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
		_land[k] -= delta / LAND_TIME
		if _land[k] <= 0.0:
			_land.erase(k)
			_land_k.erase(k)
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
	if drag_input:
		accept_event()  # drawn paths: DigScreen takes the drag from anywhere (begin_drag)
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


## Drawn paths, from anywhere on the screen: the finger's travel since it went down is
## mapped onto the robot (DRAG_STEP cells of travel is a step), so the finger never hides the
## robot. A drag of one step is a one-step move (into rock: a drill bump); a tap does nothing.
## A flick (a quick swipe, lifted within FLICK_MS) is one step that way, however far it went.
## The mapping is steady on purpose, a small screen and a thumb wobble a lot: a step needs the
## aim well past the halfway mark (so a wobble at the edge can't step and undo), a diagonal
## finger waits until one axis clearly leads, each step pulls the aim back onto the line it
## runs along (so a slanted swipe doesn't drift into the next row), and walls are solid (a
## finger pushing into rock, the edge or a full path doesn't pile up travel there).
const DRAG_STEP := 1.1    # finger travel per step, in cells
const STEP_AT := 0.6      # how far past the last cell (in steps) the aim must go to step on
const STEP_LEAD := 0.25   # and by how much it must lead the other axis
const RAIL_PULL := 0.8    # the share of sideways drift each step takes back
const FLICK_MS := 220     # a touch lifted this soon after it went down is a flick...
const FLICK_MIN := 0.3    # ...if it travelled at least this far (cells)
var _drag_start := Vector2.ZERO  # where the finger went down (screen)
var _drag_t0 := 0
var _aim_bias := Vector2.ZERO  # travel (in steps) taken back by the rail pull and the walls
var _path_drill := false  # the path is a single bump into rock (the Drill)


func begin_drag(screen_pos: Vector2) -> bool:
	if not drag_input or snap.is_empty() or snap.robot < 0 or not input_enabled or is_busy() or armed >= 0:
		return false
	_drawing = true
	_drag_start = screen_pos
	_drag_t0 = Time.get_ticks_msec()
	_aim_bias = Vector2.ZERO
	_path_real = snap
	_path_dirs = []
	_path_cells = [snap.robot]
	_path_drill = false
	_path_t = 0.0
	_path_rp = cell_center(snap.robot)
	_finger = _path_rp
	_lean = Vector2.ZERO
	_path_match.clear()
	_path_groups.clear()
	Sfx.play("tap", 1.5)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(12)
	return true


func drag_to(screen_pos: Vector2) -> void:
	if not _drawing:
		return
	var unit := Vector2(cell, pitch)
	var start := Vector2(Board.pos(_path_real.robot))
	var travel := _cells_moved(screen_pos) / Vector2(1.0, pitch / cell) / DRAG_STEP
	for guard in 8:
		var aim := travel - _aim_bias
		var off := aim - (Vector2(Board.pos(_path_cells[-1])) - start)
		var ax := absf(off.x)
		var ay := absf(off.y)
		if maxf(ax, ay) < STEP_AT or absf(ax - ay) < STEP_LEAD:
			break
		var step := Vector2i(int(signf(off.x)), 0) if ax > ay else Vector2i(0, int(signf(off.y)))
		if _path_step(step):
			if step.x != 0:
				_aim_bias.y += off.y * RAIL_PULL
			else:
				_aim_bias.x += off.x * RAIL_PULL
			continue
		# blocked: hold the aim just short of the wall
		var hold := STEP_AT - 0.05
		if step.x != 0:
			_aim_bias.x += off.x - signf(off.x) * hold
		else:
			_aim_bias.y += off.y - signf(off.y) * hold
	# where the aim is, for the held robot's lean (_process)
	_finger = cell_center(_path_real.robot) + (travel - _aim_bias) * unit


func end_drag(screen_pos: Vector2) -> void:
	if not _drawing:
		return
	_drawing = false
	var moved := _cells_moved(screen_pos)
	if Time.get_ticks_msec() - _drag_t0 <= FLICK_MS and moved.length() >= FLICK_MIN:
		# a flick: one step the way it went, whatever the path had drawn on the way
		_path_drill = false
		_path_dirs = [Vector2i(int(signf(moved.x)), 0) if absf(moved.x) >= absf(moved.y) else Vector2i(0, int(signf(moved.y)))]
	_finish_path()


## The finger's travel since it went down, in cells. Measured on the screen and unscaled, so
## the board leaning in while drawing (its scale) doesn't move the aim.
func _cells_moved(screen_pos: Vector2) -> Vector2:
	var k := get_global_transform_with_canvas().get_scale().x / scale.x
	return (screen_pos - _drag_start) / (cell * k)


## Walk the path toward a cell, one cell at a time (DevShot draws paths with this).
func _path_extend(target: Vector2i) -> void:
	for guard in 8:
		var dv := target - Board.pos(_path_cells[-1])
		if dv == Vector2i.ZERO:
			return
		var step := Vector2i(signi(dv.x), 0) if absi(dv.x) >= absi(dv.y) else Vector2i(0, signi(dv.y))
		if not _path_step(step):
			return


## One step of the path from its end; going back onto the previous cell takes the last step
## back. False when the step can't be taken (the edge, rock, a full path).
func _path_step(step: Vector2i) -> bool:
	var last: int = _path_cells[-1]
	var ni := board.step_to(last, step)
	if ni < 0:
		return false
	if _path_cells.size() >= 2 and ni == _path_cells[-2]:
		# back one step: the gem slides back where it was, the note steps down
		var undone: int = _path_cells.pop_back()
		_path_dirs.pop_back()
		if _path_drill:
			_path_drill = false
			return true
		_slide[undone] = [cell_center(ni) - cell_center(undone), 0.0]
		_preview()
		Sfx.play("note", pow(2.0, PATH_NOTES[_path_dirs.size()] / 12.0) * 0.5)
		Sfx.play("swap", 0.85)
		return true
	if _path_drill:
		return false
	if _path_real.terrain[ni] == T.ROCK and _path_dirs.is_empty() and drill:
		# one step into rock with the Drill: a bump, nothing to preview
		_path_cells.append(ni)
		_path_dirs.append(step)
		_path_drill = true
		Sfx.play("tap", 0.8)
		return true
	if _path_dirs.size() >= path_max:
		if _path_deny <= 0.0:
			_path_deny = 1.0
			Sfx.play("bump", 1.3)
		return false
	if not guide.is_empty() and (_path_cells.size() >= guide.size() or guide[_path_cells.size()] != ni):
		return false  # a lesson: the path follows the hand
	if board.path_cells(_path_dirs + [step]).is_empty():
		return false  # the Board says no: a wall, rock, an obstacle, a caged gem
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
	return true


## The board as it will stand once the path is walked (swaps only; matching waits for release),
## and what the release will do, both from the Board (preview_path): the view adds only how it
## looks and sounds.
func _preview() -> void:
	var pv := {} if _path_drill else board.preview_path(_path_dirs)
	var was_tele := _path_tele
	if pv.is_empty():
		_path_combo = {}
	var before := _path_match.size()
	var specials_before := _path_groups.filter(func(g): return g.special >= 0).size()
	_path_specials.clear()
	_path_match.clear()
	_path_groups.clear()
	_path_tele = -1
	if pv.is_empty():
		snap = _path_real
		queue_redraw()
		return
	snap = pv.snap
	_path_specials = pv.specials
	if pv.combo.get("name", "") != _path_combo.get("name", ""):
		Sfx.play("telearm", 1.4)  # a combo just formed (or changed): it charges up
	_path_combo = pv.combo
	_path_tele = pv.twin
	if _path_tele >= 0 and was_tele != _path_tele:
		# the path just came to rest on a teleporter: it arms with a charge-up, a flash and a buzz
		_tele_arm = 1.0
		Sfx.play("telearm")
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(30)
	# what would match if the finger lifted now: those gems bounce and glow, and a new line
	# chimes as it forms
	for g in pv.groups:
		var mid := Vector2.ZERO
		for c in g.cells:
			_path_match[c] = true
			mid += cell_center(c)
		_path_groups.append(g.merged({"mid": mid / float(g.cells.size())}))
	var specials_now := _path_groups.filter(func(g): return g.special >= 0).size()
	if specials_now > specials_before:
		Sfx.play("forge", 1.2)
	elif _path_match.size() > before:
		Sfx.play("reveal", 1.3 + 0.05 * _path_match.size())
	queue_redraw()


func _finish_path() -> void:
	_path_tele = -1
	_path_specials.clear()
	_path_combo = {}
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
	_path_tele = -1
	_path_specials.clear()
	_path_combo = {}
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
	_draw_off = off
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
	_draw_obstacles(Obstacles.Layer.FLOOR)  # on the floor, under rock and gems
	for i in Board.W * Board.H:
		if snap.terrain[i] == T.ROCK:
			_draw_rock(i)
	_draw_docks()
	_draw_obstacles(Obstacles.Layer.PIECE)
	_draw_elements()
	_draw_move_hints(moving_to)
	var glowing := not glow.is_empty() and _cur.is_empty() and not _drawing
	if glowing:
		for k in glow.size():
			_draw_glow_halo(glow[k], k)
	var webbed := _floor_cells()
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
		if falling and _fall_route.has(i):
			# each piece runs its own route (straight down, round a corner of rock), on its own
			# clock (bottom first, a beat apart), stretching with speed, and squashes when it lands
			var ft := _t * _dur - float(_fall_delay.get(i, 0.0))
			var length: float = _fall_len[i]
			var fs := minf(_fall_dist(ft), length) if ft > 0.0 else 0.0
			if fs >= length and not _land.has(i):
				_land[i] = 1.0
				_land_k[i] = _fall_speed(_fall_time[i])
			var at2 := _route_at(_fall_route[i], fs)
			var grow := 1.0
			if _fall_entry.has(i):
				# a new gem enters through the top of its run: it grows in as it crosses the edge
				# (there is nothing above the board to fall from)
				grow = clampf((at2.y - float(_fall_entry[i]) + pitch * 0.5) / pitch, 0.0, 1.0)
				if grow <= 0.0:
					continue
			if fs < length:
				var v := _fall_speed(ft) / FALL_VMAX if ft > 0.0 else 0.0
				_tok_squash = Vector2(1.0 - 0.02 * v, 1.0 + 0.03 * v)
			else:
				_tok_squash = _squash_of(i)
				at2.y -= _hop_of(i)
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
		if not _cur.is_empty() and ((_cur.type == "special" and i == _cur.at) or (_cur.type == "merge" and _cur.from.has(i))):
			continue  # a power-up going off (or merging) is drawn by its effect, not in its cell
		if not _cur.is_empty() and _cur.type == "belt" and _belt_from.has(i):
			var bf: int = _belt_from[i]
			var gap := Board.pos(i) - Board.pos(bf)
			if absi(gap.x) + absi(gap.y) > 1:
				# round the end: into the exit gate, back out of the entry
				if _t < 0.5:
					var dout := cell_center(bf) - cell_center(belts_prev(bf))
					_draw_token(cell_center(bf) + dout * _ease(_t * 2.0) * 0.5, tok[i], kinds[i], sc * (1.0 - _ease(_t * 2.0)), 0.3, specs[i])
				else:
					var din := cell_center(i) - cell_center(belts_next(i))
					_draw_token(cell_center(i) + din * (1.0 - _ease((_t - 0.5) * 2.0)) * 0.5, tok[i], kinds[i], sc * _ease((_t - 0.5) * 2.0), 0.3, specs[i])
			else:
				_draw_token(cell_center(bf).lerp(cell_center(i), _ease(_t)), tok[i], kinds[i], sc, 0.0, specs[i])
			continue
		if not _cur.is_empty() and _cur.type == "teleport" and not _cur.robot and i == _cur.to:
			var tt := _t
			var at3 := cell_center(_cur.from) if tt < 0.5 else cell_center(i)
			var k3 := 1.0 - _ease(tt * 2.0) if tt < 0.5 else _back_out((tt - 0.5) * 2.0)
			_draw_token(at3, tok[i], kinds[i], sc * k3, 0.4, specs[i])
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
		if not _cur.is_empty() and _cur.type == "special" and _cur.sucked.has(i):
			# swallowed: spiralling into the black hole
			var k7 := _ease(clampf(_effect_t() * 1.2, 0.0, 1.0))
			var rel := cell_center(i) - cell_center(_cur.at)
			at = cell_center(_cur.at) + rel.rotated(k7 * 2.5) * (1.0 - k7)
			sc *= 1.0 - 0.8 * k7
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
		at.y -= _hop_of(i)
		_tok_rot = float(_spec_angle.get(i, 0.0)) if _drawing and tok[i] == K.CHARGE and specs[i] == Board.Special.PULSAR else 0.0
		if webbed.has(i) and tok[i] != K.NONE:
			# a gem on a web stands off it: a soft dark shadow under it
			draw_circle(at + Vector2(0, cell * 0.06), cell * 0.4 * sc, Color(0.1, 0.02, 0.2, 0.3), true, -1.0, true)
			draw_circle(at + Vector2(0, cell * 0.05), cell * 0.33 * sc, Color(0.1, 0.02, 0.2, 0.45), true, -1.0, true)
		_draw_token(at, tok[i], kinds[i], sc, fl, specs[i])
		_tok_rot = 0.0
		_tok_squash = Vector2.ONE
	_draw_obstacles(Obstacles.Layer.COVER)  # over the gems they lock
	_draw_dock_marks()
	var hot := {}
	for p in pads:
		if Board.pad_throws(snap.token[p]):
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
		var rows := maxf(1.0, (cell_center(_cur.robot[1]).y - from_c.y) / pitch)
		rp = from_c.lerp(cell_center(_cur.robot[1]), minf(1.0, _fall_dist(_t * _dur) / rows))
	if not _cur.is_empty() and _cur.type == "belt" and not _cur.robot.is_empty():
		rp = cell_center(_cur.robot[0]).lerp(cell_center(_cur.robot[1]), _ease(_t))
	if not _cur.is_empty() and _cur.type == "teleport" and _cur.robot:
		if _t < 0.5:
			rp = cell_center(_cur.from)
			rsc *= 1.0 - _ease(_t * 2.0)
		else:
			rsc *= _back_out((_t - 0.5) * 2.0)
	if not _cur.is_empty() and _cur.type == "launch" and _cur.robot:
		rp = _arc(cell_center(_cur.from), cell_center(_cur.to), _t)
		rsc *= 1.0 + 0.3 * sin(PI * _t)
	if _drawing and _path_tele >= 0:
		# where the robot will come out: a ghost on the twin, linked to the end of the path
		var tc := cell_center(_path_tele)
		var col2 := _tele_col(_path_tele)
		var a2 := cell_center(snap.robot)
		# a live beam between the pair, flickering, with charge running along it
		draw_line(a2, tc, Color(col2, 0.22 + 0.1 * sin(_time * 30.0)), cell * (0.34 + 0.25 * _tele_arm), true)
		draw_line(a2, tc, Color(1, 1, 1, 0.6), cell * 0.05, true)
		var n2 := 12
		for k2 in n2:
			var f2 := (float(k2) + fmod(_time * 3.5, 1.0)) / n2
			draw_circle(a2.lerp(tc, f2), cell * 0.06, Color(col2.lightened(0.4), 0.95))
		# the teleporter under the robot charges up: rings rushing inward, a flash on arming
		for j2 in 3:
			var f3 := fmod(_time * 2.2 + j2 / 3.0, 1.0)
			draw_arc(a2, cell * (0.9 - 0.55 * f3), 0.0, TAU, 32, Color(col2, f3 * 0.8), cell * 0.05, true)
		if _tele_arm > 0.0:
			draw_circle(a2, cell * (0.5 + 0.9 * (1.0 - _tele_arm)), Color(col2.lightened(0.5), 0.5 * _tele_arm))
			draw_circle(tc, cell * (0.5 + 0.9 * (1.0 - _tele_arm)), Color(col2.lightened(0.5), 0.5 * _tele_arm))
		draw_arc(tc, cell * (0.5 + 0.05 * sin(_time * 9.0)), 0.0, TAU, 32, Color(col2, 0.9), cell * 0.06, true)
		_draw_ghost_robot(tc, rsc, col2)
	if _drawing or _path_lift > 0.0:
		if _drawing:
			_draw_path()
			for c in _path_specials:
				_draw_special_aim(c)  # over the trail, so an armed special is never hidden
		var lift := _back_out(_path_lift) if _drawing else _path_lift
		if _drawing:
			# held: the robot strains toward its next step, like something picked up
			rp = _path_rp + _lean
		# a soft shadow stays on the board while the robot is held up
		draw_circle(rp + Vector2(0, cell * 0.28), cell * 0.3 * (1.0 - 0.25 * lift), Color(0.05, 0.0, 0.12, 0.28 * lift))
		rp.y -= cell * 0.16 * lift
		rsc *= 1.0 + 0.14 * lift
		if _drawing and _path_tele >= 0:
			# armed: the robot hums with the charge, glowing in the pair's colour
			var tcol := _tele_col(_path_tele)
			draw_circle(rp, cell * (0.55 + 0.05 * sin(_time * 24.0)), Color(tcol, 0.3))
			rsc *= 1.0 + 0.03 * sin(_time * 8.0)
	_draw_robot(rp, rsc)
	_draw_booster_fx()
	_draw_overlays(glowing)
	_draw_guide()
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
		# a soft ribbon of light: corners rounded off, thin at the tail and swelling toward the
		# robot, drawn as overlapping discs so every end and joint is round
		var curve := _smooth_path(pts)
		var total := 0.0
		for k in range(1, curve.size()):
			total += curve[k - 1].distance_to(curve[k])
		var pulse := 1.0 + 0.08 * sin(_time * 9.0)
		var step := cell * 0.045
		for layer in 3:
			var d := 0.0
			while d <= total:
				var f := d / maxf(1.0, total)  # 0 at the tail, 1 at the robot
				var w := lerpf(0.45, 1.0, f)
				var p := _along(curve, d)
				match layer:
					0: draw_circle(p, cell * 0.28 * w * pulse, Color(col, 0.07), true, -1.0, true)
					1: draw_circle(p, cell * 0.14 * w, Color(col, 0.45), true, -1.0, true)
					2: draw_circle(p, cell * 0.05 * w, Color(1, 1, 1, 0.9), true, -1.0, true)
				d += step
		# energy flowing along it toward the robot
		var spacing := cell * 0.42
		var s := fmod(_path_t * cell * 2.6, spacing)
		while s < total:
			var p := _along(curve, s)
			draw_circle(p, cell * 0.06, Color(1, 1, 1, 0.9), true, -1.0, true)
			draw_circle(p, cell * 0.12, Color(col, 0.3), true, -1.0, true)
			s += spacing
		# the head: a glow under the held robot
		draw_circle(pts[-1], cell * 0.34 * pulse, Color(col, 0.16), true, -1.0, true)
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


## The path's points with every corner rounded off (a quadratic curve through the corner), so
## the trail flows instead of bending at right angles.
func _smooth_path(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for k in range(1, pts.size() - 1):
		var a := pts[k - 1]
		var p := pts[k]
		var b := pts[k + 1]
		var r := minf(cell * 0.4, minf(a.distance_to(p), b.distance_to(p)) * 0.5)
		var s0 := p + (a - p).normalized() * r
		var s1 := p + (b - p).normalized() * r
		for j in 9:
			var t := j / 8.0
			out.append(s0.lerp(p, t).lerp(p.lerp(s1, t), t))
	out.append(pts[-1])
	return out


## While a path is drawn, what the release would do stands out (no dimming: the user found it
## unnecessary). Each line
## that would match glows in its colour with a +N, a line that would make a special shows the
## special waiting where it will appear, and two or more lines call out the combo.
func _draw_outcome(tok: PackedInt32Array, kinds: PackedInt32Array, specs: PackedInt32Array) -> void:
	var k := _path_lift
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
	if not _path_combo.is_empty():
		# power-ups the path merges: pulled toward the last one, the combo's name over it
		var to: Vector2 = cell_center(_path_combo.at)
		var pulse2 := 0.5 + 0.5 * sin(_time * 12.0)
		for fc in _path_combo.from:
			if fc != _path_combo.at:
				draw_line(cell_center(fc), to, Color(1, 0.9, 0.5, (0.5 + 0.4 * pulse2) * k), cell * (0.1 + 0.05 * pulse2), true)
		draw_circle(to, cell * (0.55 + 0.08 * pulse2), Color(1, 0.85, 0.4, 0.35 * k), true, -1.0, true)
		var ntxt: String = _path_combo.name
		var nfs := int(cell * (0.5 + 0.03 * pulse2))
		var nw := _label_font.get_string_size(ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var np := to + Vector2(-nw * 0.5, -cell * 0.75)
		np.x = clampf(np.x, origin.x, origin.x + cell * Board.W - nw)
		draw_string_outline(_label_font, np, ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, int(cell * 0.12), Color(0.25, 0.05, 0.1, k))
		draw_string(_label_font, np, ntxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color("ffe27a"))
	if _path_groups.size() >= 2:
		var ctxt := "x%d COMBO!" % _path_groups.size()
		var cfs := int(cell * 0.6 * (1.0 + 0.05 * sin(_time * 10.0)))
		var cw := _label_font.get_string_size(ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		var cp := origin + Vector2(cell * Board.W * 0.5 - cw * 0.5, -cell * 0.15)
		draw_string_outline(_label_font, cp, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, int(cell * 0.14), Color(0.2, 0.02, 0.3, k))
		draw_string(_label_font, cp, ctxt, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color("ffe27a"))


## Where a dragged special will go off and which way: [cell, direction]. Pushed onto a pad it
## goes off at the pad's target, heading along the throw; onto a teleporter, at the twin.
## The clock of what a power-up does: the step's own, or, with drones in it, the part after
## they land (what they carry goes off there, never while they are still flying).
func _effect_t() -> float:
	if _fly >= 1.0 or _cur.get("flights", []).is_empty():
		return _t
	return clampf((_t - _fly) / (1.0 - _fly), 0.0, 1.0) if _t > _fly else 0.0


## A dragged special, before release: it stands out of the dimmed board, armed. A Drill
## turns to the way it will fire, with a sparking tip; any special trembles and throbs in its
## glow. Sent through a pad or teleporter, a small ring marks where it will go off.
func _draw_special_aim(c: int) -> void:
	if snap.token[c] != K.CHARGE:
		return
	var kind: int = snap.spec[c]
	var aim: Array = _path_specials[c]  # [where it goes off, the way it fires, colour] (Board.preview_path)
	if aim.size() > 2 and int(aim[2]) >= 0:
		# a Black hole: every gem of the colour it will swallow shivers toward it
		var pul := 0.5 + 0.5 * sin(_time * 10.0)
		for i in Board.W * Board.H:
			if snap.token[i] == K.ORE and snap.ore[i] == int(aim[2]):
				var gc := cell_center(i)
				draw_arc(gc, cell * (0.44 + 0.04 * pul), 0.0, TAU, 28, Color(SPECIAL_COL[Board.Special.BLACKHOLE], 0.55 + 0.35 * pul), cell * 0.05, true)
				draw_line(gc, gc.lerp(cell_center(c), 0.18 + 0.06 * pul), Color(SPECIAL_COL[Board.Special.BLACKHOLE], 0.35), cell * 0.04, true)
	var col: Color = SPECIAL_COL[kind]
	var pulse := 0.5 + 0.5 * sin(_time * 14.0)
	if aim[0] != c:
		draw_arc(cell_center(aim[0]), cell * (0.4 + 0.05 * pulse), 0.0, TAU, 32, Color(col, 0.85), cell * 0.05, true)
	var at := cell_center(c) + Vector2(sin(_time * 53.0), cos(_time * 47.0)) * cell * 0.025
	draw_circle(at, cell * (0.5 + 0.08 * pulse), Color(col, 0.22 + 0.18 * pulse))
	_tok_rot = float(_spec_angle.get(c, 0.0)) if kind == Board.Special.PULSAR else 0.0
	_draw_token(at, K.CHARGE, snap.ore[c], _depth_scale(c) * (1.08 + 0.08 * pulse), 0.25 * pulse, kind)
	_tok_rot = 0.0
	if kind == Board.Special.PULSAR:
		# both tips, where the twin beams will come out: flickering sparks
		for side in [0.0, PI]:
			var ang: float = _spec_angle.get(c, 0.0) - PI * 0.5 + side
			var tip := at + Vector2(cos(ang), sin(ang)) * cell * 0.4
			draw_circle(tip, cell * (0.1 + 0.05 * pulse), Color(1, 1, 1, 0.9))
			draw_circle(tip, cell * (0.17 + 0.06 * pulse), Color(col, 0.35))
			for k in 3:
				var sa: float = ang + sin(_time * 23.0 + k * 2.1 + side) * 0.9
				var sl := cell * (0.12 + 0.1 * fmod(_time * 3.0 + k * 0.37, 1.0))
				draw_line(tip, tip + Vector2(cos(sa), sin(sa)) * sl, Color(col.lightened(0.5), 0.8), cell * 0.025, true)


## A launch's flight from a to b: up and over, higher for longer throws.
func _arc(a: Vector2, b: Vector2, t: float) -> Vector2:
	var h := cell * 0.8 + a.distance_to(b) * 0.3
	var e := _ease(t)
	return a.lerp(b, e) - Vector2(0, h * 4.0 * e * (1.0 - e))


## Movement elements on the ground, under the gems: conveyor chevrons that flow, launch pads,
## the dotted flight to each pad's target, and teleporters.
## Docks: where an energy core is delivered, a socket in the floor under whatever stands on it.
func _draw_docks() -> void:
	var tex := Art.tex(OBS_DIR + "dock.png")
	for d in docks:
		var c := cell_center(d)
		var pul := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(c, cell * (0.46 + 0.03 * pul), Color(CORE_COL, 0.12 + 0.1 * pul), true, -1.0, true)
		if tex != null:
			var ds := Vector2(cell, cell) * 0.98
			draw_texture_rect(tex, Rect2(c - ds * 0.5, ds), false)
		else:
			draw_arc(c, cell * 0.4, 0.0, TAU, 32, CORE_COL, cell * 0.06, true)


## A dock is covered by what stands on it, so it also gets a mark on the board's edge below it
## (Candy Crush's exit arrows): the socket, bobbing, with a light pulsing down into it.
func _draw_dock_marks() -> void:
	var tex := Art.tex(OBS_DIR + "dock.png")
	for d in docks:
		var c := cell_center(d) + Vector2(0, cell * 0.66 + cell * 0.04 * sin(_time * 4.0))
		var pul := fmod(_time * 1.6, 1.0)
		draw_circle(c, cell * (0.3 + 0.25 * pul), Color(CORE_COL, 0.45 * (1.0 - pul)), true, -1.0, true)
		if tex != null:
			var ds := Vector2(cell, cell * 0.85) * 0.82
			_draw_lifted(tex, Rect2(c - ds * 0.5, ds))
		else:
			_chevron(c, Vector2(0, 1), CORE_COL)


## Cells with a floor layer (a web) still on them, from the snapshot.
func _floor_cells() -> Dictionary:
	var out := {}
	for it in snap.get("obstacles", []):
		if int(it.left) > 0 and Obstacles.KINDS[it.kind].layer == Obstacles.Layer.FLOOR:
			for c in it.cells:
				out[c] = true
	return out


## Obstacles of one layer (Obstacles.Layer): pieces under the gems' layer, covers over the gems
## they lock. What each looks like follows its state in the snapshot (hits left), so the view
## never needs to know the rules.
func _draw_obstacles(layer: int) -> void:
	var list: Array = snap.get("obstacles", [])
	for id in list.size():
		var it: Dictionary = list[id]
		var rule: Dictionary = Obstacles.KINDS[it.kind]
		if rule.layer != layer or (it.left <= 0 and not rule.stays):
			continue
		var r := Rect2(cell_origin(Board.pos(it.cells[0])),
				Vector2(cell * rule.size.x, pitch * (rule.size.y - 1) + cell))
		var jolt: float = _obs_jolt.get(id, 0.0)
		match it.kind:
			"generator":
				_draw_generator(it, int(rule.need), r, jolt, float(_obs_glow.get(id, 0.0)))
			"web":
				# a cave web on the floor; a thick one shows its extra layer until it is hit
				# a webbed floor tile, painted like the soil tiles: it replaces the cell's top face (a
				# thick web is hazier until its first layer is gone); it shivers when hit
				var wt := Art.tex(OBS_DIR + ("web_thick.png" if int(it.left) >= 2 else "web.png"))
				if web_tex_override != null:
					wt = web_tex_override
				var w := cell - GAP
				var ws := Vector2(w, w) * (1.0 + 0.04 * sin(PI * jolt))
				var wc := r.position + Vector2(cell, cell) * 0.5
				if wt != null:
					draw_texture_rect(wt, Rect2(wc - ws * 0.5, ws), false)
					# a faint violet sheen: the webbed area reads as one patch under the gems
					_round_rect(Rect2(wc - ws * 0.46, ws * 0.92), Color("d9ccff", 0.16), cell * 0.16)
					# calm in the middle, where the gem sits: the strands show round the edges and
					# corners, framing the cell, never behind the gem
					var calm := Color("f2dcef") if int(it.left) >= 2 else Color("c9b7ef")
					draw_circle(wc, cell * 0.4, Color(calm, 0.4), true, -1.0, true)
					draw_circle(wc, cell * 0.32, Color(calm, 0.7), true, -1.0, true)
				else:
					draw_arc(wc, cell * 0.4, 0.0, TAU, 24, Color(1, 1, 1, 0.6), cell * 0.03, true)
			"cage":
				var tex := Art.tex(OBS_DIR + "cage.png")
				var cs := Vector2(cell, cell) * (1.0 + 0.1 * sin(PI * jolt))
				if tex != null:
					_draw_lifted(tex, Rect2(r.get_center() - cs * 0.5, cs))
				else:
					draw_rect(Rect2(r.get_center() - cs * 0.45, cs * 0.9), Color(0.3, 0.3, 0.36), false, cell * 0.08)


## A generator charges as matches land next to it: the dome fills with light and a row of lamps
## under it lights up one per hit; full, it switches on and hums.
func _draw_generator(it: Dictionary, need: int, r: Rect2, jolt: float, glow: float) -> void:
	var on: bool = it.left <= 0
	var c := r.get_center()
	var have: int = need - int(it.left)
	var pul := 0.5 + 0.5 * sin(_time * 4.0)
	if on:
		draw_circle(c, r.size.x * (0.52 + 0.03 * pul), Color(0.37, 0.95, 1.0, 0.16 + 0.12 * pul + 0.4 * glow), true, -1.0, true)
	var sz := r.size * 0.98 * (1.0 + 0.05 * sin(PI * jolt) + 0.12 * glow)
	var tex := Art.tex(OBS_DIR + ("generator_on.png" if on else "generator_off.png"))
	if tex != null:
		_draw_lifted(tex, Rect2(c - sz * 0.5, sz))
	else:
		_round_rect(Rect2(c - sz * 0.45, sz * 0.9), Color(0.75, 0.78, 0.85), cell * 0.12)
	if on:
		return
	# the dome lights up as it charges (and flickers as a hit lands)
	var k := float(have) / float(need)
	if have > 0:
		draw_circle(c - Vector2(0, sz.y * 0.02), sz.x * 0.27, Color(0.37, 0.95, 1.0, 0.18 + 0.4 * k + 0.3 * jolt), true, -1.0, true)
	# lamps: one per hit it needs, lit as they land
	var lw := sz.x * 0.62 / need
	var y := c.y + sz.y * 0.36
	var x0 := c.x - lw * need * 0.5
	_round_rect(Rect2(Vector2(x0 - lw * 0.2, y - lw * 0.42), Vector2(lw * (need + 0.4), lw * 0.84)), Color(0.05, 0.03, 0.1, 0.7), lw * 0.4)
	for j in need:
		var lc := Vector2(x0 + lw * (j + 0.5), y)
		if j < have:
			draw_circle(lc, lw * 0.4, Color(0.37, 0.95, 1.0, 0.35), true, -1.0, true)
			draw_circle(lc, lw * 0.26, Color("bffaff"), true, -1.0, true)
		else:
			draw_circle(lc, lw * 0.22, Color(0.35, 0.38, 0.5), true, -1.0, true)


## What a step did to obstacles (step.obstacles from Board._strike): every hit shudders the
## obstacle and sparks; a finish rings out (a generator switches on, a cage bursts).
func _obstacle_fx(step: Dictionary) -> void:
	for r in step.get("obstacles", []):
		_obs_jolt[r.id] = 1.0
		var c := Vector2.ZERO
		for cc in r.cells:
			c += cell_center(cc)
		c /= float(r.cells.size())
		var g := get_global_transform_with_canvas() * c
		match r.kind:
			"generator":
				var have: int = r.need - r.left
				fx.emit("path_step", {"pos": g, "n": 6 + have})
				if r.done:
					_obs_glow[r.id] = 1.0
					_rings.append({"c": c, "r0": cell * 0.4, "r1": cell * 2.6, "t": 0.0, "dur": 0.45, "color": Color("5ff2ff")})
					_rings.append({"c": c, "r0": cell * 0.2, "r1": cell * 2.0, "t": -0.08, "dur": 0.45, "color": Color.WHITE})
					add_trauma(0.3)
					_whiteout = maxf(_whiteout, 0.35)
					Sfx.play("teleport", 1.15)
					Sfx.play("collect")
				else:
					Sfx.play("cell", 0.9 + 0.08 * have)
			"web":
				# torn: a burst of silk off the cell, wisps flying, a soft pop
				_puffs.append({"c": c, "t": 0.0, "spin": randf_range(-0.6, 0.6)})
				fx.emit("debris", {"pos": g, "color": Color("e9e0ff")})
				_rings.append({"c": c, "r0": cell * 0.25, "r1": cell * 0.75, "t": 0.0, "dur": 0.25, "color": Color("f1ebff")})
				Sfx.play("tap", 1.35 if r.done else 1.1)
			"cage":
				fx.emit("debris", {"pos": g, "color": Color(0.45, 0.47, 0.55)})
				_rings.append({"c": c, "r0": cell * 0.3, "r1": cell * 0.9, "t": 0.0, "dur": 0.3, "color": Color(0.8, 0.82, 0.9)})
				Sfx.play("crack", 1.25)
				add_trauma(0.08)


func _draw_elements() -> void:
	for loop in belts:
		var n: int = loop.size()
		var ends := Board.pos(loop[0]) - Board.pos(loop[n - 1])
		var closed := absi(ends.x) + absi(ends.y) == 1
		for k in n:
			var a := cell_center(loop[k])
			var b: Vector2
			if closed or k < n - 1:
				b = cell_center(loop[(k + 1) % n])
			else:
				# a line's last cell points on, into its exit gate
				b = a + (a - cell_center(loop[k - 1])) * 0.5
			var d := (b - a).normalized()
			var side := Vector2(-d.y, d.x)
			# the belt is still between moves (static chevrons), and only runs, bright and fast,
			# while it actually moves: what moves, and when, reads off the belt itself
			var run := _belt_run
			draw_line(a, b, Color(0.06, 0.1, 0.2, 0.55), cell * 0.78, true)
			var rail := Color(BELT_COL, 0.35 + 0.55 * run)
			draw_line(a + side * cell * 0.39, b + side * cell * 0.39, rail, cell * (0.03 + 0.02 * run), true)
			draw_line(a - side * cell * 0.39, b - side * cell * 0.39, rail, cell * (0.03 + 0.02 * run), true)
			for j in 2:
				var f := fmod(_belt_phase + j * 0.5, 1.0)
				var c := a + d * cell * (f - 0.5) * 0.9
				var al := (0.35 + 0.6 * run) * (0.4 + 0.6 * sin(PI * f))
				draw_polyline(PackedVector2Array([c - d * cell * 0.1 + side * cell * 0.16, c + d * cell * 0.06, c - d * cell * 0.1 - side * cell * 0.16]),
						Color(BELT_COL.lightened(0.3 * run), al), cell * (0.05 + 0.02 * run), true)
		if not closed:
			# a line's two ends are a pair of gates: out at the end, back in at the start
			_draw_belt_gate(loop[n - 1], cell_center(loop[n - 1]) - cell_center(loop[n - 2]), true)
			_draw_belt_gate(loop[0], cell_center(loop[0]) - cell_center(loop[1]), false)
		_draw_belt_badge(loop)
	for p in pads:
		var c := cell_center(p)
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(c, cell * 0.44, Color(PAD_COL, 0.22 + 0.1 * pulse))
		draw_arc(c, cell * 0.42, 0.0, TAU, 40, Color(PAD_COL, 0.9), cell * 0.05, true)
		draw_arc(c, cell * (0.26 + 0.06 * pulse), 0.0, TAU, 32, Color(1, 0.95, 0.8, 0.6), cell * 0.03, true)
	for p in teleports:
		var c := cell_center(p)
		var col := _tele_col(p)
		draw_circle(c, cell * 0.46, Color(col, 0.22))
		for j in 3:
			var a0 := _time * 2.4 + j * TAU / 3.0
			draw_arc(c, cell * (0.3 + 0.08 * j), a0, a0 + PI * 0.9, 16, Color(col, 0.5 - 0.12 * j), cell * 0.05, true)


## The robot as it will appear somewhere else: a soft, pulsing silhouette in a colour.
func _draw_ghost_robot(c: Vector2, sc: float, col: Color) -> void:
	var s := cell * 0.4 * sc * (1.0 + 0.06 * sin(_time * 10.0))
	draw_circle(c, s * 1.5, Color(col, 0.18))
	var body := Rect2(c - Vector2(s, s * 0.9), Vector2(s * 2, s * 1.8))
	_round_rect(body, Color(col.lightened(0.5), 0.55), 20)
	var visor := Rect2(c + Vector2(-s * 0.78, -s * 0.55), Vector2(s * 1.56, s * 0.75))
	_round_rect(visor, Color(0.1, 0.15, 0.25, 0.6), 14)
	draw_circle(c + Vector2(-s * 0.35, -s * 0.18), s * 0.15, Color(1, 1, 1, 0.8))
	draw_circle(c + Vector2(s * 0.35, -s * 0.18), s * 0.15, Color(1, 1, 1, 0.8))


## Teleporter pairs share a colour (by the pair's lower cell).
func _tele_col(c: int) -> Color:
	var pairs := []
	for p in teleports:
		var lo := mini(p, teleports[p])
		if not pairs.has(lo):
			pairs.append(lo)
	pairs.sort()
	var lo2 := mini(c, teleports.get(c, c))
	return TELE_COLS[maxi(0, pairs.find(lo2)) % TELE_COLS.size()]


## The belt cell before / after c on its belt (c itself if it has none).
func belts_prev(c: int) -> int:
	for b in belts:
		var k: int = b.find(c)
		if k > 0:
			return b[k - 1]
	return c


func belts_next(c: int) -> int:
	for b in belts:
		var k: int = b.find(c)
		if k >= 0 and k < b.size() - 1:
			return b[k + 1]
	return c


## A belt gate at the outer edge of an end cell: a half ring the colour of the belt, the
## exit with its chevron pointing out, the entry with it pointing in.
func _draw_belt_gate(c: int, out_dir: Vector2, exit: bool) -> void:
	var d := out_dir.normalized()
	var at := cell_center(c) + d * cell * 0.46
	var ang := d.angle()
	var col := BELT_COL.lightened(0.2 + 0.4 * _belt_run)
	draw_arc(at, cell * 0.3, ang - PI * 0.5, ang + PI * 0.5, 16, Color(col, 0.95), cell * 0.07, true)
	draw_arc(at, cell * 0.18, ang - PI * 0.5, ang + PI * 0.5, 12, Color(col, 0.5), cell * 0.04, true)
	var side := Vector2(-d.y, d.x)
	var tip := at + d * cell * (0.12 if exit else -0.12)
	var back := tip - d * cell * (0.1 if exit else -0.1)
	draw_polyline(PackedVector2Array([back + side * cell * 0.09, tip, back - side * cell * 0.09]), Color(col, 0.95), cell * 0.04, true)


## How many steps the belt will run after this move: 1, plus one per gem a drawn path would
## match on it (the cap is Board.BELT_MAX). A small badge at the belt's start, ▶ and the
## count; it swells when a path would push the belt further.
func _draw_belt_badge(belt: Array) -> void:
	var steps := 1
	if _drawing:
		for g in _path_groups:
			for c in g.cells:
				if belt.has(c):
					steps += 1
	steps = mini(steps, Board.BELT_MAX)
	var a := cell_center(belt[0])
	var d := (cell_center(belt[1]) - a).normalized()
	var at := a - d * cell * 0.5 - Vector2(0, pitch * 0.42)
	var big := steps > 1
	var sc := 1.0 + (0.18 + 0.06 * sin(_time * 10.0) if big else 0.0)
	var w := cell * 0.62 * sc
	var h := cell * 0.34 * sc
	# keep it on the board: a belt that starts at the edge gets its badge over its first cell
	at.x = clampf(at.x, origin.x + w * 0.5, origin.x + cell * Board.W - w * 0.5)
	_round_rect(Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h)), Color(0.08, 0.12, 0.24, 0.92), int(h * 0.5))
	var col := Color("ffe27a") if big else BELT_COL
	var tri := at + Vector2(-w * 0.2, 0)
	var r := h * 0.28
	draw_colored_polygon(PackedVector2Array([tri + Vector2(-r * 0.6, -r), tri + Vector2(r, 0), tri + Vector2(-r * 0.6, r)]), col)
	var txt := str(steps)
	var fs := int(h * 0.82)
	var tw := _label_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_label_font, at + Vector2(w * 0.14 - tw * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Over the gems: each pad's flight path, dotted, and the target it hits.
func _draw_pad_paths(hot: Dictionary) -> void:
	# teleporters: a bright swirling rim over the gem, in the pair's colour
	for p in teleports:
		var c := cell_center(p)
		var col := _tele_col(p)
		draw_arc(c, cell * 0.47, 0.0, TAU, 40, Color(col, 0.95), cell * 0.06, true)
		for j in 4:
			var a0 := -_time * 3.0 + j * TAU / 4.0
			draw_arc(c, cell * 0.47, a0, a0 + 0.35, 6, Color.WHITE, cell * 0.08, true)
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
	var burst := Art.tex(OBS_DIR + "rock_burst.png")
	var dust := Art.tex(OBS_DIR + "rock_dust.png")
	for b in _bursts:
		var e: float = _ease(b.t)
		if dust != null:  # the dust cloud swells behind, slower, and lingers
			var ds := cell * (0.7 + 0.9 * e)
			draw_texture_rect(dust, Rect2(b.c - Vector2(ds, ds) * 0.5, Vector2(ds, ds)), false, Color(1, 1, 1, 0.75 * (1.0 - b.t)))
		if burst != null:
			var bs := cell * (0.75 + 1.0 * e)
			draw_set_transform(_draw_off + b.c, b.spin * e, Vector2(-1.0 if b.flip else 1.0, 1.0))
			draw_texture_rect(burst, Rect2(-Vector2(bs, bs) * 0.5, Vector2(bs, bs)), false, Color(1, 1, 1, 1.0 - b.t * b.t * b.t))
			draw_set_transform(_draw_off)
	var puff := Art.tex(OBS_DIR + "web_puff.png")
	if puff != null:
		for p in _puffs:
			var e: float = _ease(p.t)
			var ps := cell * (0.55 + 0.8 * e)
			draw_set_transform(_draw_off + p.c, p.spin * e)
			draw_texture_rect(puff, Rect2(-Vector2(ps, ps) * 0.5, Vector2(ps, ps)), false, Color(1, 1, 1, 1.0 - p.t * p.t))
			draw_set_transform(_draw_off)
	for r in _rings:
		if r.t < 0.0:
			continue
		var k: float = r.t / r.dur
		var col: Color = r.color
		col.a = 1.0 - k
		draw_arc(r.c, lerpf(r.r0, r.r1, _ease(k)), 0, TAU, 48, col, 8.0 * (1.0 - k) + 2.0, true)


## A guided move: the board dims except the cells the lesson is about, and a hand presses on
## the robot and draws the move, again and again, until the player does it.
func _draw_guide() -> void:
	if guide.is_empty() or _drawing or is_busy():
		_guide_t = 0.0
		return
	var lit := {}
	for c in guide:
		lit[c] = true
	for f in focus:
		lit[Board.idx(f)] = true
	var dim := clampf(_guide_t / 0.4, 0.0, 1.0) * 0.5
	for i in Board.W * Board.H:
		if not lit.has(i) and snap.terrain[i] != T.BEDROCK:
			draw_rect(Rect2(cell_origin(Board.pos(i)), Vector2(cell, pitch)), Color(0.04, 0.0, 0.1, dim))
	# one loop: appear, press, draw the move cell by cell, hold at the end, lift, rest
	var steps := guide.size() - 1
	var press := 0.45
	var per := 0.6  # s per cell
	var move := per * steps
	var hold := 0.35
	var lift := 0.35
	var loop := 0.4 + press + move + hold + lift
	var t := fmod(_guide_t, loop) - 0.4
	if t < 0.0:
		return
	var at := cell_center(guide[0])
	var down := 1.0
	var alpha := 1.0
	if t < press:
		down = 1.0 - 0.15 * sin(PI * 0.5 * t / press)  # the finger presses on the robot
		alpha = clampf(t / 0.12, 0.0, 1.0)
	elif t < press + move:
		var f := (t - press) / per
		var k := int(f)
		at = cell_center(guide[k]).lerp(cell_center(guide[mini(k + 1, steps)]), _ease(f - k))
		down = 0.85
	elif t < press + move + hold:
		at = cell_center(guide[steps])
		down = 0.85
	else:
		at = cell_center(guide[steps])
		var e := (t - press - move - hold) / lift
		down = 0.85 + 0.15 * e
		alpha = 1.0 - e
	# the trail it leaves: the move the player is to copy
	if t > press:
		var pts := PackedVector2Array([cell_center(guide[0])])
		var reached := clampf((t - press) / per, 0.0, float(steps))
		for k in int(reached):
			pts.append(cell_center(guide[k + 1]))
		if reached < steps:
			pts.append(at)
		if pts.size() >= 2:
			draw_polyline(pts, Color(1, 1, 1, 0.55 * alpha), cell * 0.16, true)
			draw_polyline(pts, Color(Pal.ACCENT, 0.9 * alpha), cell * 0.07, true)
	var tex := Art.tex("res://assets/ui/tutorial/hand.png")
	if tex == null:
		draw_circle(at, cell * 0.2, Color(1, 1, 1, 0.8 * alpha))
		return
	var hs := Vector2(tex.get_width(), tex.get_height()) * (cell * 1.45 / tex.get_height()) * down
	draw_circle(at, cell * 0.16 * (2.0 - down), Color(1, 1, 1, 0.35 * alpha))
	draw_texture_rect(tex, Rect2(at - hs * HAND_TIP + Vector2(0, cell * 0.05), hs), false, Color(1, 1, 1, alpha))


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
			var te := _effect_t()
			var tf := clampf(_t / _fly, 0.0, 1.0)  # the drones' own clock
			var k2 := sin(PI * te)
			for ray in _cur.rays:
				var a2 := cell_center(ray[0])
				var b2 := cell_center(ray[1])
				if ray[1] == ray[0]:
					continue
				draw_line(a2, b2, Color(col2, 0.35 * k2), cell * 0.5 * k2, true)
				draw_line(a2, b2, Color(col2, 0.9 * k2), cell * 0.22 * k2, true)
				draw_line(a2, b2, Color(1, 1, 1, k2), cell * 0.07 * k2, true)
			var at2 := cell_center(_cur.at)
			for c3 in _cur.turned:  # a black hole combo: a colour turning into power-ups
				draw_line(at2, cell_center(c3), Color(col2, 0.8 * k2), cell * 0.08, true)
			if not _cur.area.is_empty():
				# a nova's blast: the cells it reaches flash out from the middle
				for c4 in _cur.area:
					var dd := cell_center(c4).distance_to(at2) / (cell * 3.0)
					var a4 := clampf(1.0 - absf(te * 1.4 - dd), 0.0, 1.0) if te > 0.0 else 0.0
					draw_rect(Rect2(cell_origin(Board.pos(c4)), Vector2(cell, pitch)), Color(col2.lightened(0.4), 0.45 * a4))
			if _cur.kind == Board.Special.BLACKHOLE:
				var bh := Art.tex("res://assets/ui/specials/blackhole.png")
				var bs := cell * (1.0 + 1.2 * sin(PI * te))
				if bh != null:
					draw_set_transform(_draw_off + at2, _time * 6.0)
					draw_texture_rect(bh, Rect2(-Vector2(bs, bs) * 0.5, Vector2(bs, bs)), false)
					draw_set_transform(_draw_off)
			for f in _cur.flights:
				# a drone's flight: up, over and down onto its target, which it has locked on to
				if tf >= 1.0:
					continue  # landed: what it carried takes over
				var a5 := cell_center(f[0])
				var b5 := cell_center(f[1])
				var ret := Art.tex("res://assets/ui/specials/reticle.png")
				if ret != null:
					var rs := cell * (1.3 - 0.3 * _ease(tf))
					draw_set_transform(_draw_off + b5, _time * 2.0)
					draw_texture_rect(ret, Rect2(-Vector2(rs, rs) * 0.5, Vector2(rs, rs)), false, Color(1, 1, 1, 0.9))
					draw_set_transform(_draw_off)
				# lift off and hover (0-0.2), glide over in a soft curve leaving a trail (0.2-0.85),
				# then dive onto the target (0.85-1)
				var lift := clampf(tf / 0.2, 0.0, 1.0)
				var glide := clampf((tf - 0.2) / 0.65, 0.0, 1.0)
				var start := a5 - Vector2(0, cell * 0.45 * _ease(lift))
				var over := b5 - Vector2(0, cell * 0.45)
				var ctrl := (start + over) * 0.5 - Vector2(0, cell * 0.6 + start.distance_to(over) * 0.2)
				var g := glide * glide * (3.0 - 2.0 * glide)  # smoothstep: eases in and out
				var fp := start.lerp(ctrl, g).lerp(ctrl.lerp(over, g), g)
				if tf > 0.85:
					fp = over.lerp(b5, _ease((tf - 0.85) / 0.15))
				for k8 in 6:  # the trail: where it was a moment ago
					var tb := clampf(glide - 0.05 * (k8 + 1), 0.0, 1.0)
					if tb <= 0.0 or tf > 0.9:
						break
					var gb := tb * tb * (3.0 - 2.0 * tb)
					var pb := start.lerp(ctrl, gb).lerp(ctrl.lerp(over, gb), gb)
					draw_circle(pb, cell * (0.12 - 0.015 * k8), Color(SPECIAL_COL[Board.Special.DRONE], 0.5 - 0.07 * k8), true, -1.0, true)
				var bob := sin(_time * 30.0) * cell * 0.02 * (1.0 - glide)
				_draw_special(fp + Vector2(0, bob), Board.Special.DRONE, 0, 1.0 + 0.2 * lift - 0.2 * clampf((tf - 0.85) / 0.15, 0.0, 1.0))
				if int(f[2]) >= 0:
					_draw_special(fp + Vector2(0, cell * 0.35), int(f[2]), 0, 0.6)
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
		"merge":
			var to := cell_center(_cur.to)
			for k6 in _cur.from.size():
				var fc: int = _cur.from[k6]
				var p6 := cell_center(fc).lerp(to, _ease(_t))
				_draw_special(p6, int(_cur.kinds[k6]), 0, 1.0 + 0.3 * _t)
			draw_circle(to, cell * 0.6 * _t, Color(1, 1, 1, 0.5 * _t), true, -1.0, true)
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
			_draw_lifted(tex, Rect2(c0 - Vector2(s, s) * 0.5, Vector2(s, s)), ROCK_TINT[clampi(hpv, 1, 3) - 1])
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
		K.CORE:
			var glow2 := 0.5 + 0.5 * sin(_time * 5.0 + c.y * 0.02)
			draw_circle(c, cell * 0.42 * sc, Color(CORE_COL, 0.16 + 0.14 * glow2), true, -1.0, true)
			var ct := Art.tex(OBS_DIR + "core.png")
			if ct != null:
				var cs := Vector2(cell, cell) * 0.9 * sc * _tok_squash
				_draw_lifted(ct, Rect2(c + Vector2(-cs.x * 0.5, cell * 0.45 * sc - cs.y), cs))
			else:
				draw_circle(c, s * 1.1, CORE_COL)
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
const SPECIAL_COL := [Color("ff4f6d"), Color("7fe8ff"), Color("ffb347"), Color("c88bff"), Color("ffd9a0")]
const SPECIAL_ART := ["blast", "pulsar", "nova", "blackhole", "drone"]


func _draw_special(c: Vector2, sp: int, kind: int, sc: float) -> void:
	var s := cell * 0.33 * sc
	var col: Color = SPECIAL_COL[sp]
	var pul := 0.5 + 0.5 * sin(_time * 7.0 + c.x * 0.05)
	draw_circle(c, s * 1.45, Color(col, 0.18 + 0.16 * pul), true, -1.0, true)
	# a power-up is an object of its own, never drawn on a gem: a coloured gem would ask to be
	# matched, and power-ups go off when MOVED (Royal Match's power-ups read the same way)
	var tex := Art.tex("res://assets/ui/specials/%s.png" % SPECIAL_ART[sp])
	if tex != null:
		var size := cell * 0.86 * sc * (1.0 + 0.05 * pul)
		if _tok_rot != 0.0:
			# a Pulsar being aimed turns about its own centre
			draw_set_transform(_draw_off + c, _tok_rot)
			_draw_lifted(tex, Rect2(-Vector2(size, size) * 0.5, Vector2(size, size)))
			draw_set_transform(_draw_off)
		elif sp == Board.Special.BLACKHOLE:
			draw_set_transform(_draw_off + c, _time * 1.5)  # the disc turns slowly
			_draw_lifted(tex, Rect2(-Vector2(size, size) * 0.5, Vector2(size, size)))
			draw_set_transform(_draw_off)
		else:
			_draw_lifted(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)))
		return
	# no art: a disc in the power-up's colour
	draw_circle(c, s * 1.12, col, true, -1.0, true)
	draw_circle(c, s * 0.8, Color(0.08, 0.02, 0.16, 0.9), true, -1.0, true)
	draw_circle(c, s * 0.3, col, true, -1.0, true)

## How squashed a landed gem is (> 0 flat, < 0 tall): its fall speed carried on into a damped
## spring, so it never stops dead. A long drop squashes hard, a short one barely.
func _spring_of(i: int) -> float:
	if not _land.has(i):
		return 0.0
	var t: float = (1.0 - _land[i]) * LAND_TIME
	var wd := LAND_W * sqrt(1.0 - LAND_DAMP * LAND_DAMP)
	var a := LAND_MAX * clampf(float(_land_k.get(i, 0.0)) / FALL_VMAX, 0.0, 1.0)
	return a * exp(-LAND_DAMP * LAND_W * t) * sin(wd * t) / 0.51  # / 0.51: its first peak is a


func _squash_of(i: int) -> Vector2:
	var q := _spring_of(i)
	return Vector2(1.0 + 0.6 * q, 1.0 - q)


## A landed gem's centre (px up) while it squashes: its bottom stays on the floor.
func _hop_of(i: int) -> float:
	return -_spring_of(i) * GEM_HALF * cell


## Seconds a fall of `cells` takes: from FALL_V0, speeding up at FALL_A, at most FALL_VMAX.
static func _fall_secs(cells: float) -> float:
	var t1 := (FALL_VMAX - FALL_V0) / FALL_A
	var d1 := FALL_V0 * t1 + 0.5 * FALL_A * t1 * t1
	if cells <= d1:
		return (-FALL_V0 + sqrt(FALL_V0 * FALL_V0 + 2.0 * FALL_A * cells)) / FALL_A
	return t1 + (cells - d1) / FALL_VMAX


## Cells a falling piece has covered after t seconds.
static func _fall_dist(t: float) -> float:
	var t1 := (FALL_VMAX - FALL_V0) / FALL_A
	if t <= t1:
		return FALL_V0 * t + 0.5 * FALL_A * t * t
	return FALL_V0 * t1 + 0.5 * FALL_A * t1 * t1 + FALL_VMAX * (t - t1)


static func _fall_speed(t: float) -> float:
	return minf(FALL_V0 + FALL_A * t, FALL_VMAX)


## The point `s` cells along a route (each step between its points, straight or diagonal, is
## covered at the same pace, as Gem Hunter's √2 speed-up on diagonals).
func _route_at(pts: PackedVector2Array, s: float) -> Vector2:
	for k in range(1, pts.size()):
		var d := (pts[k] - pts[k - 1]).abs()
		var n := maxf(d.x / cell, d.y / pitch)
		if s <= n or k == pts.size() - 1:
			return pts[k - 1].lerp(pts[k], clampf(s / maxf(n, 0.001), 0.0, 1.0))
		s -= n
	return pts[pts.size() - 1]


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
func _draw_lifted(tex: Texture2D, r: Rect2, tint := Color.WHITE) -> void:
	var lift := r.size.y * 0.035
	for k in 3:
		var spread := r.size.x * 0.005 * k
		draw_texture_rect(tex, Rect2(r.position + Vector2(-spread, lift - spread * 0.5), r.size + Vector2(spread, spread) * 2.0), false, Color(0.12, 0.04, 0.02, 0.16))
	draw_texture_rect(tex, r, false, tint)


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
