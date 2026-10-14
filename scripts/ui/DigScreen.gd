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
var _goals: Widgets.GoalStrip
var _energy: Widgets.EnergyBar
var _chips: Array = []
var _coach: Dialog.Coach
var _dialog: Dialog.Overlay
var _mission: Control
var _mission_at := 0  # ticks when the goal card opened; it can't be closed right away
const MISSION_HOLD_MS := 1500
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
var _lesson := false
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
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# top HUD: dig number and battery on one plate, the haul on a second one
	var top_plate := Ui.panel(Pal.PANEL, 28, "plate")
	col.add_child(top_plate)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top_plate.add_child(top)
	_title = Ui.label("", Pal.FS_BIG, Pal.TEXT)
	_title.custom_minimum_size.x = 230
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.outline(_title)
	top.add_child(_title)
	_energy = Widgets.EnergyBar.new()
	_energy.custom_minimum_size.y = 88
	_energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_energy)

	var haul_plate := Ui.panel(Pal.PANEL, 28, "plate")
	col.add_child(haul_plate)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 18)
	haul_plate.add_child(chips)
	for r in 4:
		var c := Widgets.Chip.new(r)
		c.custom_minimum_size.y = 64
		_chips.append(c)
		chips.add_child(c)

	_goals = Widgets.GoalStrip.new()
	col.add_child(_goals)

	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.move_requested.connect(_on_move)
	view.snap_changed.connect(_on_snap)
	view.settled.connect(_on_settled)
	view.fx.connect(_on_fx)
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
	col.add_child(bar)

	fxl = FxLayer.new()
	fxl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fxl)
	for r in 4:
		var chip: Widgets.Chip = _chips[r]
		fxl.targets[r] = chip.icon_global
	fxl.targets["energy"] = _energy.target_global

	_dialog = Dialog.Overlay.new()
	add_child(_dialog)


## Start campaign dig `index`, or a supply run on that site (random layout, no lessons).
func start(index: int, is_supply := false, seed_value := -1) -> void:
	site_index = index
	supply = is_supply
	var site := Sites.get_site(index)
	var rules := Game.rules()
	board = Board.new()
	var s := seed_value if seed_value >= 0 else randi()
	if supply:
		var open := site.duplicate()
		open.erase("seed")  # a supply run is a fresh layout every time
		board.setup_site(open, s, rules)
	else:
		board.setup_site(site, s, rules)
	_title.text = "Supply run" if supply else "Dig %d" % (index + 1)
	_goals.set_goals(site.goals)
	# ore that counts toward a goal flies into its goal icon, the rest into the haul chips
	for r in 4:
		fxl.targets[r] = (_chips[r] as Widgets.Chip).icon_global
	for i in site.goals.size():
		var g: Dictionary = site.goals[i]
		if g.type == "ore":
			fxl.targets[g.ore] = _goals.icon_global.bind(i)
		elif g.type == "crystal":
			fxl.targets[3] = _goals.icon_global.bind(i)
	view.scanner = rules.scanner
	view.drill = rules.drill
	view.hint_dir = -1
	view.focus = []
	view.input_enabled = true
	view.show_snap(board.snapshot())
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
	var seen: bool = Game.tips_seen.has(site.id)
	_script = []
	# new-tool reminders, unless this dig is the hand-made lesson that teaches the tool anyway
	var reminders := Game.take_reminders()
	if not (site.get("guide", false) or site.get("building_level", false)) or supply:
		for line in reminders:
			_script.append({"say": line})
	if not supply:
		for st in site.get("script", []):
			if not seen:
				_script.append(st)
	Game.tips_seen[site.id] = true
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
	var panel := Ui.panel(Pal.PANEL, 36)
	panel.custom_minimum_size = Vector2(900, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(Ui.label("SUPPLY RUN" if supply else "THIS DIG", Pal.FS_SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var strip := Widgets.GoalStrip.new(true)
	strip.set_goals(goals)
	v.add_child(strip)
	var words := []
	for g in goals:
		words.append(Sites.goal_text(g))
	v.add_child(Ui.label(" + ".join(words), Pal.FS_SMALL, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var tap := Ui.label("tap to start", Pal.FS_SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tap.modulate.a = 0.0
	v.add_child(tap)
	# the card stays up for a moment so the goal is actually read, then invites the tap
	_mission_at = Time.get_ticks_msec()
	var tw := tap.create_tween()
	tw.tween_interval(MISSION_HOLD_MS / 1000.0)
	tw.tween_property(tap, "modulate:a", 1.0, 0.3)
	strip.scale = Vector2(0.6, 0.6)
	strip.pivot_offset = Vector2(420, 115)
	strip.create_tween().tween_property(strip, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mission.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			_close_mission())


func _close_mission(force := false) -> void:
	if _mission == null:
		return
	if not force and Time.get_ticks_msec() - _mission_at < MISSION_HOLD_MS:
		return
	_mission.queue_free()
	_mission = null
	_run_script()


# --- Mira's script ------------------------------------------------------------

func _run_script() -> void:
	if board == null or board.over:
		return
	if _step >= _script.size():
		view.focus = []
		_waiting = ""
		_coach.clear()
		return
	var st: Dictionary = _script[_step]
	view.focus = st.get("focus", [])
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


## Which script events a turn produced, from the board's counters before and after it.
func _turn_events(before: Dictionary) -> Dictionary:
	var s := board.stats
	var e := {"move": true}
	if s.groups > before.groups: e["match"] = true
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
	if board and not board.over and not view.is_busy() and not _busy_talking():
		_idle += delta
		if _auto_hint and _idle > AUTO_HINT_IDLE and view.hint_dir == -1 and not _reach.is_empty():
			view.hint_dir = _reach[0]


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
	if board == null or board.over or _result != null or _busy_talking():
		return
	if view.is_busy():
		_pending = dir
		_has_pending = true
		return
	_do_move(dir)


func _do_move(dir: Vector2i) -> void:
	_idle = 0.0
	var before := board.stats.duplicate()
	var r := board.try_move(dir)
	if not r.ok:
		view.bump(dir)
		match r.reason:
			"rock":
				_say("Solid rock. Make a match right next to it to crack it.", 3.0)
			"energy":
				_say("Not enough energy to drill.", 2.0)
		return
	for k in _turn_events(before):
		_events[k] = true
	view.hint_dir = -1
	view.play_steps(r.steps)
	if Engine.has_singleton("Android") or OS.has_feature("mobile"):
		for s in r.steps:
			if s.type == "match":
				Input.vibrate_handheld(25)
				break


func _on_snap(s: Dictionary) -> void:
	_energy.set_energy(s.energy, board.cfg.capacity)
	for r in 4:
		(_chips[r] as Widgets.Chip).set_value(s.haul[r])
	var site := Sites.get_site(site_index)
	for i in site.goals.size():
		var g: Dictionary = site.goals[i]
		var v := 0
		match g.type:
			"ore": v = s.extracted[g.ore]
			"rock": v = s.rocks
			"chunks": v = s.chunks
			"crystal": v = s.crystals
			"blast": v = s.blasts
		_goals.set_have(i, v)


func _on_settled() -> void:
	if board.over:
		view.input_enabled = false
		view.focus = []
		_coach.clear()
		get_tree().create_timer(0.45).timeout.connect(_show_result)
		return
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
	if supply or _waiting != "":
		return
	var notes := {"charge": "A line of 4 leaves a blast charge. Step onto it to blow up everything around it."}
	for ev in notes:
		var key: String = "first_" + ev
		if _events.has(ev) and not Game.tips_seen.has(key):
			Game.tips_seen[key] = true
			_coach.say(notes[ev], 5.0)
			return


func _refresh_reach() -> void:
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
			_hint_btn.text = "Pulse (-%d)" % board.cfg.pulse_cost
			Ui.paint_button(_hint_btn, Pal.CRYSTAL)
			_say("No line of 3 within reach. Pulse reshuffles the ore, or Recall to bank your haul.", 4.0)
		else:
			_hint_btn.text = "Hint"
			# stuck for good: this beats any instruction still on screen
			_coach.say("Nothing left in reach. Tap Recall to bank your haul and try again.")
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


func _on_recall() -> void:
	if board == null or board.over or _result != null or _busy_talking():
		return
	if _recall_armed <= 0.0:
		_recall_armed = 2.0
		_recall_btn.text = "Tap again"
		return
	board.recall()
	view.input_enabled = false
	_show_result()


func _on_fx(kind: String, d: Dictionary) -> void:
	match kind:
		"extract":
			var k := 0
			for p in d.points:
				fxl.fly(p, d.ore, Pal.ORE[d.ore], k * 0.03)
				fxl.burst(p, Pal.ORE[d.ore], 5, 300.0)
				k += 1
			var mid: Vector2 = d.points[d.points.size() / 2]
			fxl.text(mid, "+%d" % (d.points.size() + board.cfg.yield_bonus), Pal.ORE[d.ore], 54)
		"energy":
			if d.amount > 0:
				fxl.text(d.pos + Vector2(0, -60), "+%d energy" % d.amount, Pal.GOOD, 40)
			else:
				fxl.text(d.pos, "+%d energy" % board.cfg.cell_energy, Pal.GOOD, 48)
				fxl.burst(d.pos, Pal.CELL, 12)
		"pickup":
			fxl.fly(d.pos, 3, Pal.CRYSTAL)
			fxl.burst(d.pos, Pal.CRYSTAL, 14, 520.0)
			fxl.text(d.pos, "Crystal!", Pal.CRYSTAL, 56)
		"debris":
			fxl.burst(d.pos, d.color, 7, 380.0)
		"reveal":
			fxl.burst(d.pos, Pal.TEXT, 10, 460.0)
		"blast":
			fxl.burst(d.pos, Pal.CHARGE, 22, 700.0)


# --- results ---------------------------------------------------------------

func _show_result() -> void:
	if _result != null:
		return
	var reason := "complete" if board.complete else ("energy" if board.energy <= 0 else "recall")
	var res := Game.finish_dig(site_index, board, reason, _hints_used)
	Sfx.play("win" if reason == "complete" else "lose")
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
	var panel := Ui.panel(Pal.PANEL, 36)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	var titles := {"complete": "DIG COMPLETE", "energy": "BATTERY EMPTY", "recall": "BACK AT BASE"}
	var colors := {"complete": Pal.GOOD, "energy": Pal.WARN, "recall": Pal.ACCENT}
	v.add_child(Ui.label(titles[reason], Pal.FS_HUGE - 8, colors[reason], HORIZONTAL_ALIGNMENT_CENTER))
	var sub := "Everything you mined goes to the colony." if reason != "complete" else "Leftover energy was turned into bonus ore."
	v.add_child(Ui.label(sub, Pal.FS_SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var total := [0, 0, 0, 0]
	for i in 4:
		total[i] = res.haul[i] + res.bonus[i]
	var haul := Widgets.CostRow.new()
	haul.custom_minimum_size.y = 70
	haul.setup(total, [9999, 9999, 9999, 9999])
	var hc := CenterContainer.new()
	haul.custom_minimum_size.x = 620
	hc.add_child(haul)
	v.add_child(hc)
	var b1 := Ui.button("Back to colony", Pal.GOOD)
	b1.pressed.connect(func(): finished.emit())
	v.add_child(b1)
	if reason != "complete" and not supply:
		var b2 := Ui.button("Try again", Pal.PANEL_HI.lightened(0.3))
		b2.pressed.connect(func(): start(site_index))
		v.add_child(b2)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = Vector2(450, 300)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
