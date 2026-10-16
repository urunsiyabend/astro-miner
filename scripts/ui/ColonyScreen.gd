class_name ColonyScreen
extends Control

## The colony (GDD v3 §4): one screen, no list. Coin and Star on top with the progress toward
## the next star milestone, the colony map in the middle (Colony / ColonyView), Mira and the
## DIG button below. Tapping a building on the map opens its card (what it does, the next
## level and its Coin cost). Reaching a star milestone grows the map: a new building plot to
## build for free, or a decoration that Mira announces. The field log, sound and reset stay in
## a small debug row while we are testing.

signal launch(site_index: int, supply: bool)

var _coin: Widgets.CurrencyChip
var _star: Widgets.CurrencyChip
var _bar: Widgets.MilestoneBar
var _view: ColonyView
var _advice: Dialog.Coach
var _dialog: Dialog.Overlay
var _spot: Dialog.Spotlight
var _go_btn: Button
var _fx: FxLayer
var _card_layer: Control
var _log_panel: Control
var _log: Label
var _sound_btn: Button
var _reset_btn: Button
var _reset_armed := 0.0


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
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	# top: bank + progress to the next star milestone
	var top := Ui.panel(Pal.PANEL, 24, "plate")
	col.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 40)
	tv.add_child(chips)
	_coin = Widgets.CurrencyChip.new(false)
	_star = Widgets.CurrencyChip.new(true)
	chips.add_child(_coin)
	chips.add_child(_star)
	_bar = Widgets.MilestoneBar.new()
	tv.add_child(_bar)

	_view = ColonyView.new()
	_view.plot_tapped.connect(_on_plot)
	col.add_child(_view)

	_advice = Dialog.Coach.new()
	col.add_child(_advice)

	_go_btn = Ui.button("", Pal.WARN, Pal.FS_BIG, 150)
	_go_btn.pressed.connect(_on_go)
	col.add_child(_go_btn)

	# debug row (testing): field log, sound, reset
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var log_btn := Ui.button("Log", Pal.PANEL_HI.lightened(0.25), Pal.FS_TINY, 64)
	log_btn.pressed.connect(func(): _log_panel.visible = not _log_panel.visible)
	_sound_btn = Ui.button("", Pal.PANEL_HI.lightened(0.25), Pal.FS_TINY, 64)
	_sound_btn.pressed.connect(func():
		Game.sfx_on = not Game.sfx_on
		Game.save()
		refresh())
	_reset_btn = Ui.button("Reset", Pal.PANEL_HI.lightened(0.25), Pal.FS_TINY, 64)
	_reset_btn.pressed.connect(_on_reset)
	for b in [log_btn, _sound_btn, _reset_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	col.add_child(row)

	_log_panel = Ui.panel(Pal.PANEL, 20)
	_log_panel.visible = false
	_log_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_log_panel.position = Vector2(32, 0)
	var lv := VBoxContainer.new()
	_log_panel.add_child(lv)
	_log = Ui.label("", Pal.FS_TINY, Pal.DIM)
	lv.add_child(_log)
	lv.add_child(Ui.label("v%s · prototype" % ProjectSettings.get_setting("application/config/version", "0"), Pal.FS_TINY, Pal.MUTED))
	add_child(_log_panel)

	_fx = FxLayer.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_dialog = Dialog.Overlay.new()
	add_child(_dialog)
	_spot = Dialog.Spotlight.new()
	add_child(_spot)
	refresh()


func _process(delta: float) -> void:
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			_reset_btn.text = "Reset"
	if _log_panel.visible:
		_log_panel.position = Vector2(32, size.y - _log_panel.size.y - 140)
		_log_panel.size.x = size.x - 64


## celebrate: a building index whose plot gets a celebration ring (after a build/upgrade).
func refresh(celebrate := -1) -> void:
	_coin.set_value(Game.coin)
	_star.set_value(Game.star)
	var nm := Game.next_milestone()
	if nm.is_empty():
		_bar.set_progress(1.0, "Colony complete")
	else:
		_bar.set_progress(Game.milestone_progress(), "%d / %d" % [Game.star, nm[1]])
	_view.set_state(Game.levels, Game.star)
	if celebrate >= 0:
		_view.celebrate(Colony.building_plot(celebrate))
	_sound_btn.text = "Sound %s" % ("on" if Game.sfx_on else "off")
	var next := Game.next_dig()
	_go_btn.disabled = false
	if Game.pending_build() >= 0:
		# a freshly unlocked building comes first: its tool is what the next dig teaches
		_go_btn.text = "BUILD FIRST"
		_go_btn.disabled = true
	elif next >= 0 and Game.can_start(next):
		_go_btn.text = "DIG  ·  #%d" % (next + 1)
		Ui.paint_button(_go_btn, Pal.WARN)
	else:
		_go_btn.text = "SUPPLY RUN"
		Ui.paint_button(_go_btn, Pal.ACCENT)
	var t: Dictionary = Game.totals
	var mpm := float(t.moves) / maxf(1.0, t.groups)
	_log.text = "Digs %d · cleared %d · battery depleted %d · recalled %d\nMoves %d · extractions %d (%.1f moves each) · cascades %d\nRock broken %d · crystals %d · pulses %d · hints %d · upgrades %d" % [
		t.digs, t.clears, t.exhausted, t.recalled, t.moves, t.groups, mpm, t.cascades,
		t.rocks, t.crystals, t.pulses, t.hints, t.upgrades]
	if is_inside_tree():
		var line := Story.advice()
		if line == "":
			_advice.clear()
		else:
			_advice.say(line)
		_guide.call_deferred()


## Walks the player through what changed since last time, one thing at a time:
## new star milestones (the map grows, Mira names any decoration), then a newly unlocked
## building (Mira announces it, the spotlight points at its plot, building it is free).
func _guide() -> void:
	if not visible or _dialog.is_open() or _spot.visible or _card_layer != null:
		return
	var fresh := Game.new_milestones()
	if not fresh.is_empty():
		Game.ack_milestones()
		var lines := []
		for m in fresh:
			var c: Dictionary = Colony.MILESTONES[m]
			var i := Colony.building_plot(c.building) if c.has("building") else Colony.plot_index(c.deco)
			_view.celebrate(i)
			_fx.burst(_view.plot_global(i), Pal.STAR, 22, 520.0)
			if c.has("deco"):
				lines.append_array(Story.DECO[c.deco])
		Sfx.play("buy")
		if not lines.is_empty():
			_dialog.say(lines, _guide)
			return
	for b in Economy.BUILDINGS.size():
		var key := "unlock_%d" % b
		if Game.building_unlocked(b) and not Game.tips_seen.has(key):
			Game.tips_seen[key] = true
			Game.save()
			_dialog.say(Story.UNLOCK[b], func(): _spot_build(b))
			return
	var p := Game.pending_build()
	if p >= 0:
		_spot_build(p)


func _spot_build(b: int) -> void:
	var btn := _view.plot_button(Colony.building_plot(b))
	if btn == null:
		return
	await get_tree().process_frame
	_spot.point(btn, "Tap here to build the %s. This one is free!" % Economy.BUILDINGS[b].name, func(): _buy(b))


func _spot_dig() -> void:
	await get_tree().process_frame
	_spot.point(_go_btn, "Now tap DIG. I'll show you how to use it down there.", _on_go)


func _on_plot(i: int) -> void:
	var plot: Dictionary = Colony.PLOTS[i]
	if not plot.has("building"):
		return
	var b: int = plot.building
	if not Game.building_unlocked(b):
		_advice.say("The %s comes at %d★. Stars come from crystals and from clearing new digs." % [Economy.BUILDINGS[b].name, Economy.STAR_UNLOCK[b]], 4.0)
		return
	if Game.levels[b] == 0:
		_buy(b)
		return
	_open_card(b)


func _open_card(b: int) -> void:
	_close_card()
	_card_layer = Control.new()
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_card_layer)
	move_child(_card_layer, _fx.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_card())
	_card_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.add_child(center)
	var card := _card(b)
	card.custom_minimum_size.x = 900
	center.add_child(card)


func _close_card() -> void:
	if _card_layer != null:
		_card_layer.queue_free()
		_card_layer = null


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
		cost_row.setup(c, Game.coin)
		info.add_child(cost_row)
	var btn := Ui.button("Build" if lv == 0 else "Upgrade", Pal.GOOD, Pal.FS_SMALL, 100)
	btn.custom_minimum_size.x = 210
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if lv >= Economy.MAX_LEVEL:
		btn.text = "Max"
		btn.disabled = true
	elif not Economy.can_afford(Game.coin, c):
		btn.disabled = true
	btn.pressed.connect(func(): _buy(b))
	h.add_child(btn)
	return p


func _buy(b: int) -> void:
	if Game.buy(b):
		_close_card()
		Sfx.play("buy")
		refresh(b)
		var at := _view.building_global(b) + Vector2(0, -80)
		_fx.burst(at, Pal.GOOD, 24, 600.0)
		_fx.text(at, Economy.BUILDINGS[b].name + "!", Pal.GOOD, 44)
		var then := Callable()
		if Game.levels[b] == 1:
			then = _spot_dig  # a brand-new tool: straight to the dig that teaches it
		_dialog.say(Story.BUILT[b][Game.levels[b] - 1], then)


func _on_reset() -> void:
	if _reset_armed <= 0.0:
		_reset_armed = 2.5
		_reset_btn.text = "Tap again"
		return
	Game.reset()
	Game.save()
	_reset_armed = 0.0
	_reset_btn.text = "Reset"
	refresh()
