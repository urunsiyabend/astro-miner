class_name ColonyScreen
extends Control

## Hub and the sense of progress: the colony grows as you build. Mira says what to do next,
## one DIG button starts the next dig (or a supply run), and each building shows the tool it
## gives the robot. There is no site list: digs simply come one after another.

signal launch(site_index: int, supply: bool)

var _chips: Array = []
var _view: ColonyView
var _cards: VBoxContainer
var _advice: Dialog.Coach
var _dialog: Dialog.Overlay
var _log: Label
var _sound_btn: Button
var _reset_btn: Button
var _reset_armed := 0.0
var _fx: FxLayer
var _go_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)

	col.add_child(Ui.label("ASTRO MINER", Pal.FS_HUGE, Pal.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Ui.label("Outpost on Corvo IV", Pal.FS_SMALL, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 18)
	for r in 4:
		var c := Widgets.Chip.new(r)
		_chips.append(c)
		chips.add_child(c)
	col.add_child(chips)

	_view = ColonyView.new()
	col.add_child(_view)

	_advice = Dialog.Coach.new()
	col.add_child(_advice)

	_go_btn = Ui.button("", Pal.WARN, Pal.FS_BIG, 150)
	_go_btn.pressed.connect(_on_go)
	col.add_child(_go_btn)

	col.add_child(Ui.label("COLONY BUILDINGS", Pal.FS_SMALL, Pal.MUTED))
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	col.add_child(_cards)

	col.add_child(Ui.label("FIELD LOG (local stats)", Pal.FS_SMALL, Pal.MUTED))
	_log = Ui.label("", Pal.FS_TINY, Pal.DIM)
	col.add_child(_log)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_sound_btn = Ui.button("", Pal.PANEL_HI.lightened(0.25), Pal.FS_SMALL, 90)
	_sound_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_btn.pressed.connect(func():
		Game.sfx_on = not Game.sfx_on
		Game.save()
		refresh())
	_reset_btn = Ui.button("Reset progress", Pal.PANEL_HI.lightened(0.25), Pal.FS_SMALL, 90)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn.pressed.connect(_on_reset)
	row.add_child(_sound_btn)
	row.add_child(_reset_btn)
	col.add_child(row)
	col.add_child(Ui.label("v%s · prototype" % ProjectSettings.get_setting("application/config/version", "0"), Pal.FS_TINY, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	_fx = FxLayer.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_dialog = Dialog.Overlay.new()
	add_child(_dialog)
	refresh()


func _process(delta: float) -> void:
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			_reset_btn.text = "Reset progress"


func refresh(celebrate := -1) -> void:
	for r in 4:
		(_chips[r] as Widgets.Chip).set_value(Game.bank[r])
	_view.set_levels(Game.levels, celebrate)
	for c in _cards.get_children():
		c.queue_free()
	for b in Economy.BUILDINGS.size():
		_cards.add_child(_card(b))
	_sound_btn.text = "Sound: %s" % ("on" if Game.sfx_on else "off")
	var next := Game.next_dig()
	_go_btn.disabled = false
	if Game.pending_build() >= 0:
		# a freshly unlocked building comes first: its tool is what the next dig teaches
		_go_btn.text = "BUILD FIRST"
		_go_btn.disabled = true
	elif next >= 0 and Game.can_start(next):
		_go_btn.text = "DIG  ·  #%d" % (next + 1)
		_go_btn.add_theme_stylebox_override("normal", Ui.box(Pal.WARN, 28))
	else:
		_go_btn.text = "SUPPLY RUN"
		_go_btn.add_theme_stylebox_override("normal", Ui.box(Pal.ACCENT, 28))
	if is_inside_tree():
		_advice.say(Story.advice())
		_announce_unlocks.call_deferred()
	var t: Dictionary = Game.totals
	var mpm := float(t.moves) / maxf(1.0, t.groups)
	_log.text = "Digs %d · cleared %d · battery depleted %d · recalled %d\nMoves %d · extractions %d (%.1f moves each) · cascades %d\nRock broken %d · crystals %d · pulses %d · hints %d · upgrades %d" % [
		t.digs, t.clears, t.exhausted, t.recalled, t.moves, t.groups, mpm, t.cascades,
		t.rocks, t.crystals, t.pulses, t.hints, t.upgrades]


## Mira announces a building the last dig unlocked (once).
func _announce_unlocks() -> void:
	if not visible or _dialog.is_open():
		return
	for b in Economy.BUILDINGS.size():
		var key := "unlock_%d" % b
		if Game.building_unlocked(b) and not Game.tips_seen.has(key):
			Game.tips_seen[key] = true
			Game.save()
			_dialog.say(Story.UNLOCK[b])
			return


func _on_go() -> void:
	var next := Game.next_dig()
	if next >= 0 and Game.can_start(next):
		launch.emit(next, false)
	else:
		launch.emit(Game.supply_site(), true)


func _card(b: int) -> Control:
	var def: Dictionary = Economy.BUILDINGS[b]
	var lv: int = Game.levels[b]
	var p := Ui.panel(Pal.PANEL, 26)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var icon := Widgets.BuildingIcon.new(b)
	icon.level = lv
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	if lv == 0 and not Game.building_unlocked(b):
		# locked: a dim silhouette that tells you more is coming
		p.modulate = Color(1, 1, 1, 0.45)
		var lk := VBoxContainer.new()
		lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lk.add_child(Ui.label("Locked", Pal.FS, Pal.DIM))
		lk.add_child(Ui.label("Keep digging to unlock it", Pal.FS_TINY, Pal.MUTED))
		h.add_child(lk)
		return p
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	info.add_child(Ui.label("%s  ·  %d/%d" % [def.name, lv, Economy.MAX_LEVEL], Pal.FS, Pal.TEXT))
	if lv > 0:
		info.add_child(Ui.label("Now: " + def.effects[lv], Pal.FS_TINY, Pal.DIM))
	var c := Economy.cost(b, lv)
	if lv < Economy.MAX_LEVEL:
		info.add_child(Ui.label(("Gives: " if lv == 0 else "Next: ") + def.effects[lv + 1], Pal.FS_TINY, Pal.GOOD))
		var cost_row := Widgets.CostRow.new()
		cost_row.setup(c, Game.bank)
		info.add_child(cost_row)
	var btn := Ui.button("Build" if lv == 0 else "Upgrade", Pal.GOOD, Pal.FS_SMALL, 100)
	btn.custom_minimum_size.x = 210
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if lv >= Economy.MAX_LEVEL:
		btn.text = "Max"
		btn.disabled = true
	elif not Economy.can_afford(Game.bank, c):
		btn.disabled = true
	if lv == 0:
		btn.text = "Build\nfree"
		# pulse until tapped: this is the button Mira is talking about
		btn.pivot_offset = Vector2(105, 50)
		var tw := btn.create_tween().set_loops()
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	btn.pressed.connect(func(): _buy(b))
	h.add_child(btn)
	return p


func _buy(b: int) -> void:
	if Game.buy(b):
		Sfx.play("buy")
		refresh(b)
		var at := _view.building_global(b) + Vector2(0, -80)
		_fx.burst(at, Pal.GOOD, 24, 600.0)
		_fx.text(at, Economy.BUILDINGS[b].name + "!", Pal.GOOD, 44)
		_dialog.say(Story.BUILT[b][Game.levels[b] - 1])


func _on_reset() -> void:
	if _reset_armed <= 0.0:
		_reset_armed = 2.5
		_reset_btn.text = "Tap again to wipe"
		return
	Game.reset()
	Game.save()
	_reset_armed = 0.0
	_reset_btn.text = "Reset progress"
	refresh()
