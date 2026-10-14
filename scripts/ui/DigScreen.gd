class_name DigScreen
extends Control

## One mining session: HUD + board + result panel. Owns the live Board.

signal finished  # player chose to go back to the colony

var board: Board
var site_index := 0
var view: BoardView
var fxl: FxLayer

var _title: Label
var _goal_box: VBoxContainer
var _goal_rows: Array = []
var _energy: Widgets.EnergyBar
var _chips: Array = []
var _toast: Label
var _toast_t := 0.0
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_title = Ui.label("", Pal.FS_BIG, Pal.TEXT)
	col.add_child(_title)

	var goals_panel := Ui.panel(Pal.PANEL, 24)
	_goal_box = VBoxContainer.new()
	_goal_box.add_theme_constant_override("separation", 6)
	goals_panel.add_child(_goal_box)
	col.add_child(goals_panel)

	_energy = Widgets.EnergyBar.new()
	col.add_child(_energy)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 18)
	for r in 4:
		var c := Widgets.Chip.new(r)
		_chips.append(c)
		chips.add_child(c)
	col.add_child(chips)

	view = BoardView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.move_requested.connect(_on_move)
	view.snap_changed.connect(_on_snap)
	view.settled.connect(_on_settled)
	view.fx.connect(_on_fx)
	col.add_child(view)

	_toast = Ui.label("", Pal.FS_SMALL, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.custom_minimum_size = Vector2(0, 96)
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_toast)

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


func start(index: int, seed_value := -1) -> void:
	site_index = index
	var site := Sites.get_site(index)
	var rules := Game.rules()
	board = Board.new()
	board.setup_site(site, seed_value if seed_value >= 0 else randi(), rules)
	_title.text = "%d. %s" % [index + 1, site.name]
	for c in _goal_box.get_children():
		c.queue_free()
	_goal_rows.clear()
	for g in site.goals:
		var row := Widgets.GoalRow.new()
		var gc: Color = Pal.ROCK[1]
		match g.type:
			"ore": gc = Pal.ORE[g.ore]
			"crystal": gc = Pal.CRYSTAL
			"chunks": gc = Pal.VEIN
		row.setup(Sites.goal_text(g), g.n, gc)
		_goal_box.add_child(row)
		_goal_rows.append(row)
	view.scanner = rules.scanner
	view.drill = rules.drill
	view.hint_dir = -1
	view.input_enabled = true
	view.show_snap(board.snapshot())
	_hints_used = 0
	_has_pending = false
	_idle = 0.0
	_auto_hint = site.get("guide", false)
	if _result:
		_result.queue_free()
		_result = null
	_recall_btn.text = "Recall"
	_recall_armed = 0.0
	var tip: String = site.tip
	var perks := _perk_text(rules)
	_show_toast(tip + ("\n" + perks if perks != "" else ""), 12.0 if _auto_hint else 7.0)
	Game.tips_seen[site.id] = true
	_refresh_reach()


func _perk_text(r: Dictionary) -> String:
	var p := []
	if r.capacity > 20:
		p.append("Battery %d" % r.capacity)
	if r.drill:
		p.append("Drill ready (bump rock)")
	if r.scanner:
		p.append("Scanner on")
	if r.blast_radius > 1:
		p.append("Big blasts")
	return "Colony tech: " + ", ".join(p) if not p.is_empty() else ""


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	if _recall_armed > 0.0:
		_recall_armed -= delta
		if _recall_armed <= 0.0:
			_recall_btn.text = "Recall"
	if board and not board.over and not view.is_busy():
		_idle += delta
		if _auto_hint and _idle > 2.0 and view.hint_dir == -1 and not _reach.is_empty():
			view.hint_dir = _reach[0]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or board == null:
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
	if board == null or board.over or _result != null:
		return
	if view.is_busy():
		_pending = dir
		_has_pending = true
		return
	_do_move(dir)


func _do_move(dir: Vector2i) -> void:
	_idle = 0.0
	var r := board.try_move(dir)
	if not r.ok:
		view.bump(dir)
		match r.reason:
			"rock":
				_show_toast("Solid rock. Match ore next to it to crack it.\nThe Mining Workshop adds a drill.", 3.0)
			"energy":
				_show_toast("Not enough energy to drill.", 2.0)
		return
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
		(_goal_rows[i] as Widgets.GoalRow).set_have(v)


func _on_settled() -> void:
	if board.over:
		view.input_enabled = false
		get_tree().create_timer(0.45).timeout.connect(_show_result)
		return
	_refresh_reach()
	if _has_pending:
		_has_pending = false
		_do_move(_pending)


func _refresh_reach() -> void:
	# a crystal or energy cell in the open comes first: it is usually what the dig is for
	_reach = board.path_to_pickup(10)
	if _reach.is_empty():
		_reach = board.path_to_match(5)
	if _reach.is_empty():
		if board.can_pulse():
			_hint_btn.text = "Pulse (-%d)" % board.cfg.pulse_cost
			_hint_btn.add_theme_stylebox_override("normal", Ui.box(Pal.CRYSTAL, 28))
			_show_toast("No ore line within 5 steps.\nPulse reshuffles the ore, or Recall to bank your haul.", 4.0)
		else:
			_hint_btn.text = "Hint"
			_show_toast("Nothing left in reach. Recall to bank your haul.", 4.0)
	else:
		_hint_btn.text = "Hint"
		_hint_btn.add_theme_stylebox_override("normal", Ui.box(Pal.ACCENT, 28))


func _on_hint() -> void:
	if board == null or board.over or view.is_busy():
		return
	if _reach.is_empty():
		if board.can_pulse():
			var r := board.pulse()
			view.play_steps(r.steps)
		return
	view.hint_dir = _reach[0]
	_hints_used += 1


func _on_recall() -> void:
	if board == null or board.over or _result != null:
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


func _show_toast(t: String, secs: float) -> void:
	_toast.text = t
	_toast_t = secs
	_toast.modulate.a = 1.0


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
	var titles := {"complete": "OBJECTIVE COMPLETE", "energy": "BATTERY DEPLETED", "recall": "RECALLED TO BASE"}
	var colors := {"complete": Pal.GOOD, "energy": Pal.WARN, "recall": Pal.ACCENT}
	v.add_child(Ui.label(titles[reason], Pal.FS_HUGE - 8, colors[reason], HORIZONTAL_ALIGNMENT_CENTER))
	var sub := "The haul is banked at the colony." if reason != "complete" else "Leftover energy was refined into bonus ore."
	v.add_child(Ui.label(sub, Pal.FS_SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for i in 4:
		var amount: int = res.haul[i] + res.bonus[i]
		if amount == 0:
			continue
		var line := "%s  +%d" % [Economy.RES_NAMES[i], res.haul[i]]
		if res.bonus[i] > 0:
			line += "   (+%d bonus)" % res.bonus[i]
		v.add_child(Ui.label(line, Pal.FS, Pal.RES[i], HORIZONTAL_ALIGNMENT_CENTER))
	if res.first_clear:
		v.add_child(Ui.label("First clear: +%d crystal" % Economy.FIRST_CLEAR_CRYSTALS, Pal.FS, Pal.CRYSTAL, HORIZONTAL_ALIGNMENT_CENTER))
	if res.next_unlocked:
		v.add_child(Ui.label("New site unlocked: %s" % Sites.get_site(site_index + 1).name, Pal.FS, Pal.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Ui.label("%d moves, %d extractions, %d rock broken" % [board.stats.moves, board.stats.groups, board.stats.rocks_broken], Pal.FS_TINY, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := Ui.button("Back to colony", Pal.GOOD)
	b1.pressed.connect(func(): finished.emit())
	v.add_child(b1)
	var again := site_index
	if res.next_unlocked:
		var b2 := Ui.button("Next site: %s" % Sites.get_site(site_index + 1).name, Pal.ACCENT)
		b2.pressed.connect(func(): start(site_index + 1))
		v.add_child(b2)
	var b3 := Ui.button("Dig here again", Pal.PANEL_HI.lightened(0.3))
	b3.pressed.connect(func(): start(again))
	v.add_child(b3)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = Vector2(450, 300)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
