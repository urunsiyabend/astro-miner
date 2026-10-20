class_name DigScreen
extends Control

## One mining session: HUD + board + Mira's guidance + result panel. Owns the live Board.
## Layout puts what matters next to the board: the goals as big icons right above it, Mira's
## current instruction right below it.

signal finished  # player chose to go back to the colony

var board: Board
var site_index := 0
var supply := false
var view: BoardView
var fxl: FxLayer

var _title: Label
var _hud: Widgets.DigHud
var _haul: Widgets.HaulChip
var _haul_pop: Control  # breakdown of the haul, shown for a moment when the haul is tapped
var _chips: Array = []
var _top_plate: Control
var _coach: Dialog.Coach
var _dialog: Dialog.Overlay
var _mission: Control
var _mission_at := 0  # ticks when the goal card opened; it can't be closed right away
const MISSION_HOLD_MS := 1500
var _boosters: Widgets.BoosterBar
var _hint_btn: Button
var _recall_btn: Button
var _recall_armed := 0.0
var _result: Control
var _pending := Vector2i.ZERO
var _has_pending := false
var _reach: Array = []
var _hints_used := 0
var _idle := 0.0
var _auto_hint := false
## The hint arrow appears on its own only in the first digs, after this long without a move;
## later it shows only when the Hint button is tapped.
const AUTO_HINT_DIGS := 5
const AUTO_HINT_IDLE := 8.0
## In every dig, after this long without a move the gems of the nearest match glow.
const IDLE_GLOW := 4.0
var _lesson := false
var _low_warned := false   # the "5 moves left!" banner shows once per dig
var _bonus_skip := false   # tap during the end-of-dig move conversion: finish it at once
var force_treasure := false  # dev: always hide a chest in the next dig
# Mira's script for this dig (see Sites): current step and the event a coach line waits for.
var _script: Array = []
var _step := 0
var _waiting := ""
var _events := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := Art.background()
	if art != null:
		var sky := TextureRect.new()
		sky.texture = art
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sky)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the board runs nearly edge to edge on a phone (BoardView caps its cell on wide screens)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 120)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# top HUD after the hero: moves left, the goals as framed slots, and this dig's haul as a
	# compact slot at the right end (tap it for the breakdown)
	_hud = Widgets.DigHud.new()
	_top_plate = _hud
	col.add_child(_hud)
	_haul = Widgets.HaulChip.new()
	_hud.haul_tapped.connect(_toggle_haul)  # _haul only keeps the per-ore counts now

	# dig name, small in the bottom-right corner (debug, for testing)
	_title = Ui.label("", Pal.FS_TINY, Pal.MUTED)
	_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_title.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_title.offset_right = -12
	_title.offset_bottom = -4
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF

	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.move_requested.connect(_on_move)
	view.path_requested.connect(_on_path)
	view.snap_changed.connect(_on_snap)
	view.settled.connect(_on_settled)
	view.fx.connect(_on_fx)
	# the HUD follows the board, sized off its cell (deferred: the board lays out on the same signal)
	view.resized.connect(_refit_hud.call_deferred)
	col.add_child(view)

	_coach = Dialog.Coach.new()
	col.add_child(_coach)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	_hint_btn = Ui.button("Hint", Pal.ACCENT)
	_hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_btn.pressed.connect(_on_hint)
	_recall_btn = Ui.button("Recall", Pal.WARN)
	_recall_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recall_btn.pressed.connect(_on_recall)
	bar.add_child(_hint_btn)
	bar.add_child(_recall_btn)
	# the Hint and Recall buttons gave way to the booster bar (GDD v4): the idle glow hints, a
	# stuck board reshuffles by itself; they stay as hidden handlers for the keys and tools
	bar.visible = false
	col.add_child(bar)
	_boosters = Widgets.BoosterBar.new()
	_boosters.picked.connect(_on_booster)
	col.add_child(_boosters)
	view.booster_target.connect(_use_booster)
	view.swap_requested.connect(_on_swap)

	add_child(_title)
	fxl = FxLayer.new()
	fxl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fxl)
	fxl.arrived.connect(_on_arrived)

	_dialog = Dialog.Overlay.new()
	add_child(_dialog)


## The haul per gem, on a plate under the top bar, for a few seconds.
## The HUD is sized off the board's cell, and the board gets what the HUD leaves: a feedback
## loop. It contracts (the HUD takes ~1.8 cells of height out of ~9.6), so it settles, except
## that the cell is floored to whole pixels and can flip between two values for ever, inside
## one frame's deferred calls (the game froze). So: ignore changes under 4 px, and never
## refit more than a few times in one frame.
var _refit_frame := -1
var _refits := 0


func _refit_hud() -> void:
	var f := Engine.get_process_frames()
	if f != _refit_frame:
		_refit_frame = f
		_refits = 0
	if _refits >= 3:
		return
	if view.cell > 1.0 and absf(view.cell * 1.25 - _hud.unit) > 4.0:
		_refits += 1
		_hud.fit(view.cell, view.cell * Board.W)


func _toggle_haul() -> void:
	if _haul_pop != null:
		_hide_haul()
		return
	_haul_pop = Ui.panel(Pal.PANEL, 28, "plate")
	_haul_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_haul_pop.add_child(row)
	for r in Board.RES_CRYSTAL + 1:
		if r < Board.RES_CRYSTAL and r >= board.cfg.ore_types:
			continue  # a colour this dig does not use
		var c := Widgets.Chip.new(r)
		c.custom_minimum_size.y = 64
		c.set_value(_haul.values[r])
		_chips.append(c)
		row.add_child(c)
	add_child(_haul_pop)
	_haul_pop.global_position = _top_plate.global_position + Vector2(0, _top_plate.size.y + 6)
	_haul_pop.size.x = _top_plate.size.x
	_haul_pop.modulate.a = 0.0
	var tw := _haul_pop.create_tween()
	tw.tween_property(_haul_pop, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.5)
	tw.tween_property(_haul_pop, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_hide_haul)


func _hide_haul() -> void:
	if _haul_pop != null:
		_haul_pop.queue_free()
		_haul_pop = null
	_chips.clear()


## Start campaign dig `index`, or a supply run on that site (random layout, no lessons).
func start(index: int, is_supply := false, seed_value := -1) -> void:
	site_index = index
	supply = is_supply
	var site := Sites.get_site(index)
	var rules := Game.rules()
	if String(site.get("mode", "robot")) == "fall":
		# drawn paths (Settings): falling-gem digs only; a lesson may hold them back
		rules.path_max = mini(Game.path_max, int(site.get("path_max", Game.path_max)))
	board = Board.new()
	var s := seed_value if seed_value >= 0 else randi()
	if supply:
		var open := site.duplicate()
		open.erase("seed")  # a supply run is a fresh layout every time
		board.setup_site(open, s, rules)
	else:
		board.setup_site(site, s, rules)
	# now and then a regular dig hides a treasure chest (never in a hand-made one)
	var plain: bool = not (site.has("ore") or site.get("guide", false) or site.get("building_level", false)
			or site.get("gold_rush", false)) and Sites.dig_number(index) >= 3
	var trng := RandomNumberGenerator.new()
	trng.seed = s ^ 0x7EA5
	if plain and (force_treasure or Game.roll_treasure(trng)):
		board.place_treasure(trng)
	force_treasure = false
	var num := Sites.dig_number(index)
	_title.text = "Supply run" if supply else ("Gold Rush" if num == 0 else "Dig %d" % num)
	var proto: bool = site.get("proto", false)
	if proto:
		_title.text = "Prototype " + String(site.title)
	view.classic = board.cfg.classic
	view.portals = board.cfg.portals
	view.gravity = board.cfg.gravity
	view.board = board
	view.path_max = board.cfg.path_max
	view.drag_input = Game.path_max > 1 and board.cfg.gravity and not board.cfg.classic
	view.pads = board.cfg.pads
	view.belts = board.cfg.belts
	view.teleports = board.cfg.teleports
	view.docks = board.cfg.docks
	_boosters.visible = not proto  # prototypes compare the core loops alone
	_hud.set_goals(site.goals)
	# ore that counts toward a goal flies into its goal icon; other ore just bursts (Coin comes
	# from clearing the dig, not from ore: the goal card shows the reward, the coin slot fills
	# at the clear)
	_haul.values = [0, 0, 0, 0, 0]
	_hide_haul()
	_hud.set_coin(0)
	_hud.calm = false
	_low_warned = false
	fxl.targets.clear()
	fxl.targets["energy"] = _hud.target_global
	fxl.targets["coin"] = _hud.haul_global
	for i in site.goals.size():
		var g: Dictionary = site.goals[i]
		if g.type == "ore":
			fxl.targets[g.ore] = _hud.icon_global.bind(i)
		elif g.type == "crystal":
			fxl.targets[Board.RES_CRYSTAL] = _hud.icon_global.bind(i)
	# every goal piece flies to its icon (Royal Match): any-colour gems to the gems goal (unless a
	# colour has its own goal), broken rock to the rock goal; the counter ticks as they land
	for i in site.goals.size():
		var g2: Dictionary = site.goals[i]
		if g2.type == "chunks":
			for k in Board.ORE_TYPES:
				if not fxl.targets.has(k):
					fxl.targets[k] = _hud.icon_global.bind(i)
		elif g2.type == "rock":
			fxl.targets["rock"] = _hud.icon_global.bind(i)
	view.scanner = rules.scanner
	view.drill = rules.drill
	view.hint_dir = -1
	view.focus = []
	view.guide = []
	view.input_enabled = true
	view.armed = -1
	view.show_snap(board.snapshot())
	_sync_boosters()
	_hints_used = 0
	_has_pending = false
	_idle = 0.0
	var guide: bool = site.get("guide", false)
	_lesson = (guide or site.get("building_level", false)) and not supply
	_auto_hint = index < AUTO_HINT_DIGS and not supply
	if _result:
		_result.queue_free()
		_result = null
	_recall_btn.text = "Recall"
	_recall_armed = 0.0
	_coach.clear()
	_waiting = ""
	_events = {}
	# Script: Mira says it the first time this dig is played, never again on a retry.
	var seen: bool = Game.tips_seen.has(site.id) and not Game.dev_mode  # dev mode: every lesson again
	_script = []
	# new-tool reminders, except the one this dig's own lesson teaches anyway: only the
	# Workshop's drill has a lesson dig that is about its tool (the Power Station's and the
	# Teleporter's boosters are introduced by the reminder itself)
	var taught := -1
	if site.get("building_level", false) and not supply:
		var nb: int = site.get("needs", {}).get("building", -1)
		if nb >= 0 and Economy.BUILDINGS[nb].has("opens"):
			taught = nb
	for line in Game.take_reminders(taught):
		_script.append({"say": line})
	if not supply:
		for st in site.get("script", []):
			if not seen:
				_script.append(st)
	Game.tips_seen[site.id] = true
	# a lesson that teaches a special itself: no passing note about it on top
	for kind in site.get("explains", []):
		Game.tips_seen["first_special_%d" % Board.SPECIAL_IDS[kind]] = true
	Game.save()
	_step = 0
	_refresh_reach()
	_show_mission(site.goals)


func _show_mission(goals: Array) -> void:
	if _mission:
		_mission.queue_free()
	_mission = Control.new()
	_mission.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mission.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mission)
	move_child(_mission, _dialog.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 56)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	# the goals alone on a jelly card: the gem in each frame and its amount say it all
	var card := Widgets.JellyCard.new(64.0)
	card.custom_minimum_size.x = 760
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var rush := _rush()
	if supply:
		v.add_child(Widgets.JuicyText.new("Supply run", 56, Color("f3c9ff"), 0.05))
	# a hard dig says so up front, in its colour (GDD v4 §3): the player knows to bring a booster
	var tier: String = Sites.get_site(site_index).get("tier", "") if not supply else ""
	if tier == "hard" or tier == "superhard":
		var tcol: Color = Color("ff9a3d") if tier == "hard" else Color("ff4f6a")
		card.rim = tcol
		v.add_child(Widgets.JuicyText.new("Hard Dig" if tier == "hard" else "Super Hard!", 76, tcol, 0.05))
	if rush:
		var pic := Widgets.Picture.new("res://assets/ui/gold_rush.png", 300.0, 0.1)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pic)
		v.add_child(Widgets.JuicyText.new("Gold Rush!", 84, Pal.COIN, 0.3))
	var gc := Widgets.GoalCard.new(goals)
	gc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(gc)
	var psite := Sites.get_site(site_index)
	if psite.get("proto", false):
		var tip_text := String(psite.get("idea", ""))
		var tip := Ui.label(tip_text, Pal.FS_SMALL, Color("f3e9ff"))
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.custom_minimum_size.x = 620
		v.add_child(tip)
	elif psite.has("tip") and not supply:
		v.add_child(_tip_row(psite.tip))
	if not supply and not rush and not psite.get("proto", false):
		# what clearing it pays (plus a Coin per move left)
		var tag := Widgets.CoinTag.new(Economy.clear_coin(site_index), 0.5 + goals.size() * 0.12)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tag)
	card.scale = Vector2(0.7, 0.7)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	# no button (it pulled the thumb to it): once the goal had time to be read, a pulsing
	# line invites a tap anywhere
	_mission_at = Time.get_ticks_msec()
	col.add_child(Widgets.JuicyText.new("Tap to start", 64, Color.WHITE, MISSION_HOLD_MS / 1000.0, true))
	_mission.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			_close_mission())


## A level's tip on its goal card ("tip": [power-up ids..., text]): the pieces it is about,
## then one line, e.g. a Pulsar and a Nova, "draw through both: they merge into a Flare".
## Power-ups are taught this way and by Mira's note the first time one is made, never by a
## level of their own.
func _tip_row(tip: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for k in tip.size() - 1:
		var pic := TextureRect.new()
		pic.texture = Art.tex("res://assets/ui/specials/%s.png" % tip[k])
		pic.custom_minimum_size = Vector2(124, 124)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(pic)
		if k < tip.size() - 2:
			row.add_child(Ui.label("+", Pal.FS_SMALL, Color("ffe27a")))
	var text := Ui.label(String(tip[-1]), Pal.FS_SMALL, Color("f3e9ff"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 440
	row.add_child(text)
	return row


func _close_mission(force := false) -> void:
	if _mission == null:
		return
	if not force and Time.get_ticks_msec() - _mission_at < MISSION_HOLD_MS:
		return
	_mission.queue_free()
	_mission = null
	_run_script()


func _rush() -> bool:
	return not supply and Sites.get_site(site_index).get("gold_rush", false)


func _show_banner(text: String, rim := Color("ffb36b"), face := Color("e2563f"), hold := 0.45, fs := 72) -> void:
	var bn := Widgets.Banner.new(text, rim, face, hold, fs)
	add_child(bn)
	move_child(bn, fxl.get_index())
	bn.show_at(view.get_global_rect().get_center().y - global_position.y, size.x)


# --- Mira's script ------------------------------------------------------------

func _run_script() -> void:
	if board == null or board.over:
		return
	if _step >= _script.size():
		view.focus = []
		view.guide = []
		_waiting = ""
		_coach.clear()
		return
	var st: Dictionary = _script[_step]
	view.focus = st.get("focus", [])
	view.guide = _guide_cells(st)
	if st.has("until"):
		_waiting = st.until
		_coach.say(st.say)
		_refresh_reach()  # the hint follows the new focus
		return
	_waiting = ""
	_coach.clear()
	_dialog.say([st.say], func():
		_step += 1
		_run_script())


## A lesson's guided move ("guide": the cells from the robot on): its cells as board indices,
## [] when the line has none. Only that move is accepted while it is shown.
func _guide_cells(st: Dictionary) -> Array:
	return st.get("guide", []).map(func(c): return Board.idx(c))


## Does a move (its directions) follow the guided move, if one is shown?
func _guide_ok(dirs: Array) -> bool:
	if view.guide.is_empty():
		return true
	if dirs.size() != view.guide.size() - 1:
		return false
	for k in dirs.size():
		if Board.pos(view.guide[k + 1]) - Board.pos(view.guide[k]) != dirs[k]:
			return false
	return true


## Which script events a turn produced, from the board's counters before and after it.
func _turn_events(before: Dictionary) -> Dictionary:
	var s := board.stats
	var e := {"move": true}
	if s.groups > before.groups: e["match"] = true
	if s.paths > before.paths: e["path"] = true
	if s.charges_made > before.charges_made: e["charge"] = true
	if s.blasts > before.blasts: e["blast"] = true
	if s.rocks_broken > before.rocks_broken: e["reveal"] = true
	if s.crystals > before.crystals: e["crystal"] = true
	if s.cells > before.cells: e["cell"] = true
	if s.drills > before.drills: e["drill"] = true
	return e


func _busy_talking() -> bool:
	return _mission != null or _dialog.is_open()


func _say(text: String, secs: float) -> void:
	# passing remarks never cover an instruction the player is working on
	if _waiting == "":
		_coach.say(text, secs)


# --- play ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _recall_armed > 0.0:
		_recall_armed -= delta
		if _recall_armed <= 0.0:
			_recall_btn.text = "Recall"
	if view.is_drawing():
		# a path being drawn is the player thinking: no hints until it is done
		_idle = 0.0
		view.hint_dir = -1
		if not view.glow.is_empty():
			view.set_glow([])
	elif board and not board.over and not view.is_busy() and not _busy_talking() and view.guide.is_empty():
		_idle += delta
		if _auto_hint and _idle > AUTO_HINT_IDLE and view.hint_dir == -1 and not _reach.is_empty():
			view.hint_dir = _reach[0]
		if _idle > IDLE_GLOW and view.glow.is_empty():
			var gems := []
			if board.cfg.classic:
				var sw := board.find_swap()
				if not sw.is_empty():
					gems = [sw[0], Board.idx(Board.pos(sw[0]) + Board.DIRS[sw[1]])]
			else:
				var path := board.path_to_match(4)
				gems = board.match_gems(path) if not path.is_empty() else []
			# nothing in reach: keep checking, but not every frame
			if gems.is_empty():
				_idle = IDLE_GLOW - 1.0
			view.set_glow(gems)


## Drawn paths: a drag anywhere on the dig screen draws the robot's path (BoardView maps the
## finger's travel onto the robot), except on the HUD and the booster bar, and not while a
## card, Mira or a booster is up.
func _input(event: InputEvent) -> void:
	if not visible or view == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if board == null or board.over or _result != null or _busy_talking() or view.armed >= 0 or board.cfg.classic:
				return
			if _hud.get_global_rect().has_point(event.position) or (_boosters.visible and _boosters.get_global_rect().has_point(event.position)):
				return
			if view.begin_drag(event.position):
				get_viewport().set_input_as_handled()
		elif view.is_drawing():
			view.end_drag(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and view.is_drawing():
		view.drag_to(event.position)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or board == null or _busy_talking():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var d := Vector2i.ZERO
		match event.keycode:
			KEY_UP, KEY_W: d = Vector2i(0, -1)
			KEY_DOWN, KEY_S: d = Vector2i(0, 1)
			KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
			KEY_H: _on_hint()
		if d != Vector2i.ZERO:
			_on_move(d)
			get_viewport().set_input_as_handled()


func _on_move(dir: Vector2i) -> void:
	if board == null or board.over or _result != null or _busy_talking() or view.armed >= 0 or board.cfg.classic:
		return
	if view.is_busy():
		return  # a swipe made while the board is still moving is dropped, never queued
	if not _guide_ok([dir]):
		view.bump(dir)  # a lesson: only the move the hand shows
		return
	_do_move(dir)


## A path drawn from the robot (path_max > 1): one move, resolved at the end.
func _on_path(dirs: Array) -> void:
	if board == null or board.over or _result != null or _busy_talking() or view.armed >= 0 or view.is_busy():
		view.cancel_path()
		return
	if not _guide_ok(dirs):
		view.cancel_path()  # a lesson: only the move the hand shows (it shows it again)
		Sfx.play("bump", 1.2)
		return
	_idle = 0.0
	view.new_turn()
	var before := board.stats.duplicate()
	var r := board.try_path(dirs)
	if not r.ok:
		view.cancel_path()
		return
	for k in _turn_events(before):
		_events[k] = true
	view.hint_dir = -1
	view.set_glow([])
	view.play_steps(r.steps)
	if OS.has_feature("mobile"):
		for s in r.steps:
			if s.type == "match":
				Input.vibrate_handheld(25)
				break


## Classic prototype: swap a gem with its neighbour (a swap that makes no line wobbles back).
func _on_swap(cell: int, dir: Vector2i) -> void:
	if board == null or board.over or _result != null or _busy_talking() or view.is_busy():
		return
	_idle = 0.0
	view.new_turn()
	var before := board.stats.duplicate()
	var r := board.try_swap(cell, dir)
	if not r.ok:
		if r.reason == "nomatch":
			view.reject_swap(cell, Board.idx(Board.pos(cell) + dir))
		return
	for k in _turn_events(before):
		_events[k] = true
	view.set_glow([])
	view.play_steps(r.steps)
	if Engine.has_singleton("Android") or OS.has_feature("mobile"):
		Input.vibrate_handheld(25)


func _do_move(dir: Vector2i) -> void:
	_idle = 0.0
	view.new_turn()
	var before := board.stats.duplicate()
	var r := board.try_move(dir)
	if not r.ok:
		view.bump(dir)
		match r.reason:
			"rock":
				var at := Board.pos(board.robot) + dir
				if board.buried[Board.idx(at)] == Board.Buried.TREASURE:
					_say("A treasure chest! Make a match right next to it to burst it open.", 3.0)
				else:
					_say("Solid rock. Make a match right next to it to crack it.", 3.0)
			"energy":
				_say("Not enough energy to drill.", 2.0)
		return
	for k in _turn_events(before):
		_events[k] = true
	view.hint_dir = -1
	view.set_glow([])
	view.play_steps(r.steps)
	if Engine.has_singleton("Android") or OS.has_feature("mobile"):
		for s in r.steps:
			if s.type == "match":
				Input.vibrate_handheld(25)
				break


func _on_snap(s: Dictionary) -> void:
	_hud.set_energy(s.energy, board.cfg.capacity)
	_haul.set_values(s.haul)
	for c in _chips:
		(c as Widgets.Chip).set_value(s.haul[(c as Widgets.Chip).res])
	var site := Sites.get_site(site_index)
	# the Board counts every goal (Board.goal_progress); the snapshot carries it step by step
	var progress: Array = s.get("progress", [])
	for i in mini(site.goals.size(), progress.size()):
		_hud.set_have(i, progress[i])


func _on_settled() -> void:
	if board.over:
		_hud.sync()
		view.input_enabled = false
		view.focus = []
		view.guide = []
		view.set_glow([])
		_coach.clear()
		if board.complete or _rush():
			_celebrate()
		else:
			get_tree().create_timer(0.45).timeout.connect(_show_result)
		return
	# the last moves: once per dig, after the move has played out
	if board.energy <= Widgets.DigHud.LOW_MOVES and not _low_warned and not _rush():
		_low_warned = true
		_show_banner("%d moves left!" % board.energy)
	_refresh_reach()
	_first_encounters()
	if _waiting != "" and _events.has(_waiting):
		_events = {}
		_step += 1
		_run_script()
		return
	_events = {}
	if _has_pending:
		_has_pending = false
		_do_move(_pending)


## One-line notes for things that can turn up before their own lesson (a random line of 4
## leaves a charge long before the charge dig). Each is said once per colony.
func _first_encounters() -> void:
	if supply or _waiting != "" or Sites.get_site(site_index).has("special"):
		return  # a prototype says what its special does on its goal card
	if not _events.has("charge"):
		return
	# the first time each kind of special turns up, one line says what it does
	var notes := {
		Board.Special.BLAST: "A line of 4 leaves a blast charge. Step onto it to blow up everything around it.",
		Board.Special.PULSAR: "4 in a row made a Pulsar! Swap with it: it fires twin beams both ways along the way it moves.",
		Board.Special.NOVA: "An L or T made a Nova! Swap with it and it blows up everything around it.",
		Board.Special.BLACKHOLE: "5 in a row made a Black hole! Swap with it and it swallows the most common colour.",
		Board.Special.DRONE: "A square made a Scout drone! Swap with it: it flies to whatever helps you most.",
	}
	for i in Board.W * Board.H:
		if board.token[i] != Board.Token.CHARGE:
			continue
		var kind: int = board.spec[i]
		var key := "first_special_%d" % kind
		if notes.has(kind) and not Game.tips_seen.has(key):
			Game.tips_seen[key] = true
			_coach.say(notes[kind], 6.0)
			return

func _refresh_reach() -> void:
	if board.cfg.classic:
		_reach = []
		if board.find_swap().is_empty():
			_say("No swaps left: the gems reshuffle.", 2.5)
			view.play_steps(board.shuffle_classic().steps)
		return
	# a crystal, energy cell or charge in the open comes first: it is usually what the dig is for
	_reach = board.path_to_pickup(10)
	if _reach.is_empty():
		_reach = board.path_to_match(5)
	if _reach.is_empty() and _lesson:
		# lessons: point at the cell Mira is talking about (e.g. the rock to drill), never Pulse
		for f in view.focus:
			var di := Board.DIRS.find(Vector2i(f) - Board.pos(board.robot))
			if di >= 0:
				_reach = [di]
				break
		_hint_btn.text = "Hint"
		Ui.paint_button(_hint_btn, Pal.ACCENT)
		if not _reach.is_empty():
			return
	if _reach.is_empty():
		if board.can_pulse():
			# nothing in reach: the ground shakes and the ore reshuffles by itself (as a stuck
			# board does in any match-3), for the pulse's energy
			_say("No line of 3 in reach: a seismic pulse reshuffles the ore.", 3.0)
			var r := board.pulse()
			view.play_steps(r.steps)
		else:
			_hint_btn.text = "Hint"
			# stuck for good: this beats any instruction still on screen
			_coach.say("Nothing left in reach, and no energy for a pulse.")
			board.recall()
			view.input_enabled = false
			get_tree().create_timer(1.2).timeout.connect(_show_result)
	else:
		_hint_btn.text = "Hint"
		Ui.paint_button(_hint_btn, Pal.ACCENT)


func _on_hint() -> void:
	if board == null or board.over or view.is_busy() or _busy_talking():
		return
	if _reach.is_empty():
		if board.can_pulse():
			var r := board.pulse()
			view.play_steps(r.steps)
		return
	view.hint_dir = _reach[0]
	_hints_used += 1


## Boosters (GDD v4 §1): tap a slot to arm it, then pick its target on the board; tap the
## armed slot again to put it away.
func _sync_boosters() -> void:
	var u := []
	for k in Economy.BOOSTERS.size():
		u.append(Game.booster_unlocked(k))
	_boosters.set_state(Game.boosters, u, view.armed)


func _on_booster(k: int) -> void:
	if k < 0 or k >= Economy.BOOSTERS.size() or board == null or board.over or _result != null or _busy_talking() or _mission != null:
		return
	if view.armed == k:
		view.armed = -1
		_coach.clear()
	elif Game.boosters[k] <= 0:
		var maker: String = Economy.BUILDINGS[Economy.BOOSTERS[k].building].name
		_say("No %ss left. The %s makes more as you clear digs." % [Economy.BOOSTERS[k].name, maker], 3.0)
		Sfx.play("bump")
	else:
		view.armed = k
		view.hint_dir = -1
		view.set_glow([])
		_coach.say(String(Economy.BOOSTERS[k].tip) + ". Tap the booster again to cancel.")
		Sfx.play("swap", 1.2)
	_sync_boosters()


func _use_booster(target: int) -> void:
	var k := view.armed
	if k < 0 or board == null or board.over or view.is_busy() or _busy_talking():
		return
	view.new_turn()
	var before := board.stats.duplicate()
	var r := board.use_booster(k, target)
	if not r.ok:
		Sfx.play("bump")
		return
	Game.use_booster(k)
	view.armed = -1
	_coach.clear()
	_idle = 0.0
	for e in _turn_events(before):
		_events[e] = true
	_sync_boosters()
	view.play_steps(r.steps)
	if Engine.has_singleton("Android") or OS.has_feature("mobile"):
		Input.vibrate_handheld(40)


func _on_recall() -> void:
	if board == null or board.over or _result != null or _busy_talking():
		return
	if _recall_armed <= 0.0:
		_recall_armed = 2.0
		_recall_btn.text = "Tap again"
		_say("Press back again to leave this dig.", 2.0)
		return
	board.recall()
	view.input_enabled = false
	_show_result()


func _on_fx(kind: String, d: Dictionary) -> void:
	match kind:
		"extract":
			var k := 0
			# longer cascades throw more sparkle (x1.15 per step, capped)
			var more := minf(2.5, 1.0 + 0.15 * float(d.get("chain", 1) - 1))
			for p in d.points:
				if fxl.targets.has(d.ore):
					fxl.fly(p, d.ore, Pal.ORE[d.ore], k * 0.03)
				if not d.get("pop", false):
					fxl.burst(p, Pal.ORE[d.ore], 5, 300.0)
				k += 1
			if d.get("pop", false):
				# the gems pulled together: one bright pop where they met
				var at: Vector2 = d.points[0]
				fxl.sparks(at, Pal.ORE[d.ore], int(7 * more), 560.0 * minf(1.6, more), 24.0)
				fxl.burst(at, Pal.ORE[d.ore], int(6 * more), 420.0)
			var mid: Vector2 = d.points[d.points.size() / 2]
			fxl.text(mid, "+%d" % (d.points.size() + board.cfg.yield_bonus), Pal.ORE[d.ore], 76)
		"energy":
			if d.amount > 0:
				fxl.text(d.pos + Vector2(0, -60), "+%d energy" % d.amount, Pal.GOOD, 40)
			else:
				fxl.text(d.pos, "+%d energy" % board.cfg.cell_energy, Pal.GOOD, 48)
				fxl.burst(d.pos, Pal.CELL, 12)
		"pickup":
			if fxl.targets.has(Board.RES_CRYSTAL):
				fxl.fly(d.pos, Board.RES_CRYSTAL, Pal.CRYSTAL)
			fxl.burst(d.pos, Pal.CRYSTAL, 14, 520.0)
			fxl.text(d.pos, "Crystal!", Pal.CRYSTAL, 56)
		"treasure":
			# the chest bursts: gold sparks, its amount, and its Coin flying into the slot
			var n: int = board.cfg.treasure_coin
			fxl.burst(d.pos, Pal.COIN, 18, 620.0)
			fxl.text(d.pos, "+%d" % n, Pal.COIN, 80)
			for k in n:
				fxl.fly(d.pos, "coin", Pal.COIN, 0.12 + k * 0.07, 0.55,
						Vector2(randf_range(-150, 150), randf_range(-200, -80)))
			Sfx.play("pickup")
		"path_step":
			# each step of a drawn path throws a few sparks, more as the path grows
			fxl.sparks(d.pos, Color("bff6ff"), 4 + int(d.n), 300.0, 14.0)
		"debris":
			fxl.burst(d.pos, d.color, 7, 380.0)
		"callout":
			# a power-up chain ("CHAIN x3") or a combo's name ("SUPERNOVA!"), over the board
			var r2 := view.get_global_rect()
			var at2 := Vector2(r2.get_center().x, r2.position.y + r2.size.y * 0.36)
			var big: bool = d.get("big", false)
			var ccol := Color("ffe27a") if not String(d.text).begins_with("CHAIN") else Color("7fe8ff")
			fxl.callout(at2, d.text, ccol, 150 if big else 112)
			fxl.sparks(at2, ccol, 24 if big else 14, 800.0, 30.0)
			if big:
				fxl.confetti(at2, 90)
		"chain":
			# a cascade climbing: the bigger the chain, the bigger the word
			var tiers := {3: ["Nice!", Color("7fe8ff"), 96], 5: ["Stellar!", Color("ffe27a"), 112],
					7: ["Cosmic!", Color("ff8ef0"), 128], 9: ["Galactic!", Color("ffb347"), 144]}
			var tier: Array = tiers.get(int(d.n), [])
			if not tier.is_empty():
				var r := view.get_global_rect()
				var at := Vector2(r.get_center().x, r.position.y + r.size.y * 0.42)
				fxl.callout(at, tier[0], tier[1], tier[2])
				fxl.sparks(at, tier[1], 10 + int(d.n) * 2, 700.0, 30.0)
				Sfx.play("prism" if int(d.n) >= 7 else "reveal", 1.0 + 0.03 * int(d.n))
				if int(d.n) >= 9:
					fxl.confetti(at, 70)
		"reveal":
			fxl.burst(d.pos, Pal.TEXT, 10, 460.0)
			if fxl.targets.has("rock"):
				fxl.fly(d.pos, "rock", Pal.ROCK[1], 0.05)
		"blast":
			fxl.burst(d.pos, Pal.CHARGE, 22, 700.0)
			fxl.sparks(d.pos, Color("ffd27a"), 14, 820.0, 30.0)


func _on_arrived(res) -> void:
	if res is int or res == "rock":
		_hud.landed(res)
		Sfx.play("tick", 1.3)
	elif res == "coin":
		_hud.coin_tick()
		# each Coin rings a little higher, so a long run of moves climbs
		Sfx.play("coin", 1.0 + 0.02 * mini(_hud.coin_shown, 30))


## The dig is won (or a gold rush is over): say so loud and clear before anything else moves
## (banner, confetti, the win jingle), then pay out.
func _celebrate() -> void:
	Sfx.play("win")
	var title := "Dig Complete!"
	if _rush():
		title = "All chests!" if board.complete else "Gold Rush done!"
	_show_banner(title, Color("a8f7b5"), Color("37b65a"), 0.9, 92)
	var r := view.get_global_rect()
	fxl.confetti(Vector2(r.get_center().x, r.position.y + r.size.y * 0.55), 110)
	# the Coin starts flying with the banner, not after it
	if (board.energy > 0 or board.complete) and not Sites.get_site(site_index).get("proto", false):
		_play_bonus()
	else:
		await get_tree().create_timer(1.1).timeout
		_show_result()


## The clear's payout, shown before the result card: the clear reward bursts off the board
## into the coin slot, then every move left leaves the Moves count and flies in as a Coin,
## faster and faster. A tap finishes it at once.
func _play_bonus() -> void:
	var moves := board.energy
	var base := 0 if _rush() else Economy.clear_coin(site_index)
	_hud.calm = true
	_bonus_skip = false
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_bonus_skip = true)
	add_child(catcher)
	await get_tree().create_timer(0.05).timeout
	var mid := view.get_global_rect().get_center()
	for k in base:
		var a := TAU * k / base
		fxl.fly(mid + Vector2(cos(a), sin(a)) * view.cell * 0.9, "coin", Pal.COIN, k * 0.07, 0.85,
				Vector2(randf_range(-120, 120), randf_range(-160, -60)))
	# a short beat between the clear reward landing and the moves being counted
	await get_tree().create_timer(0.85 + base * 0.07 + 0.45).timeout
	var from: Vector2 = _hud.target_global()
	var gap := 0.1
	var left := moves
	while left > 0 and not _bonus_skip:
		left -= 1
		_hud.set_energy(left, board.cfg.capacity)
		view.snap["energy"] = left  # the robot's own counter runs down with it
		fxl.fly(from, "coin", Pal.COIN, 0.0, 0.42, Vector2(randf_range(-60, 60), randf_range(-140, -90)))
		await get_tree().create_timer(gap).timeout
		gap = maxf(0.035, gap * 0.88)
	if _bonus_skip:
		# land the rest at once
		_hud.set_energy(0, board.cfg.capacity)
		view.snap["energy"] = 0
		_hud.set_coin(board.treasure_coin + base + moves)
	await get_tree().create_timer(0.55).timeout
	catcher.queue_free()
	_show_result()


# --- results ---------------------------------------------------------------

func _show_result() -> void:
	if _result != null:
		return
	var reason := "complete" if board.complete else ("energy" if board.energy <= 0 else "recall")
	var res := Game.finish_dig(site_index, board, reason, _hints_used)
	reason = res.reason   # a gold rush that ran out of moves comes back as "rush"
	if reason != "complete" and reason != "rush":
		Sfx.play("lose")   # a win already played its jingle when it was celebrated
	_result = Control.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_result)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)
	var card := Widgets.JellyCard.new(60.0)
	card.custom_minimum_size.x = 820
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	card.add_child(v)
	var titles := {"complete": "Dig Complete!", "energy": "Out of Moves", "recall": "Back at Base",
			"rush": "Gold Rush!"}
	var colors := {"complete": Pal.GOOD, "energy": Pal.WARN, "recall": Pal.ACCENT, "rush": Pal.COIN}
	if reason == "complete" and _rush():
		reason = "rush"
	v.add_child(Widgets.JuicyText.new(titles[reason], 88, colors[reason], 0.12))
	v.add_child(Widgets.RewardRow.new(res.coin, res.star, 0.45))
	var b1 := Widgets.JellyButton.new("Colony", Color("8ff0a4"), Color("37b65a"))
	b1.pressed.connect(func(): finished.emit())
	v.add_child(b1)
	var proto: bool = Sites.get_site(site_index).get("proto", false)
	if (reason != "complete" and reason != "rush" and not supply) or proto:
		var b2 := Widgets.JellyButton.new("Play again" if proto else "Try again", Color("c7a6f5"), Color("6b45b0"), 116.0, 46)
		b2.pressed.connect(func(): start(site_index))
		v.add_child(b2)
	card.modulate.a = 0.0
	card.scale = Vector2(0.75, 0.75)
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.15)
	tw.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
