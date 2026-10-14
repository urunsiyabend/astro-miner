class_name ColonyScreen
extends Control

## Hub: bank, buildings with upgrades, dig-site list, local field log.

signal launch(site_index: int)

var _chips: Array = []
var _view: ColonyView
var _cards: VBoxContainer
var _sites: VBoxContainer
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

	_go_btn = Ui.button("", Pal.WARN, Pal.FS, 140)
	_go_btn.pressed.connect(func(): launch.emit(_next_site()))
	col.add_child(_go_btn)

	col.add_child(Ui.label("BUILDINGS", Pal.FS_SMALL, Pal.MUTED))
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	col.add_child(_cards)

	col.add_child(Ui.label("DIG SITES", Pal.FS_SMALL, Pal.MUTED))
	_sites = VBoxContainer.new()
	_sites.add_theme_constant_override("separation", 14)
	col.add_child(_sites)

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
	for c in _sites.get_children():
		c.queue_free()
	for i in Sites.count():
		_sites.add_child(_site_button(i))
	_sound_btn.text = "Sound: %s" % ("on" if Game.sfx_on else "off")
	var ns := _next_site()
	_go_btn.text = "DIG: %d. %s" % [ns + 1, Sites.get_site(ns).name]
	var t: Dictionary = Game.totals
	var mpm := float(t.moves) / maxf(1.0, t.groups)
	_log.text = "Digs %d · cleared %d · battery depleted %d · recalled %d\nMoves %d · extractions %d (%.1f moves each) · cascades %d\nRock broken %d · crystals %d · pulses %d · hints %d · upgrades %d" % [
		t.digs, t.clears, t.exhausted, t.recalled, t.moves, t.groups, mpm, t.cascades,
		t.rocks, t.crystals, t.pulses, t.hints, t.upgrades]


## First unlocked site not yet cleared, else the last unlocked one.
func _next_site() -> int:
	for i in Game.unlocked:
		if not Game.cleared[i]:
			return i
	return Game.unlocked - 1


func _card(b: int) -> Control:
	var def: Dictionary = Economy.BUILDINGS[b]
	var lv: int = Game.levels[b]
	var p := Ui.panel(Pal.PANEL, 26)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	h.add_child(info)
	info.add_child(Ui.label("%s  ·  Lv %d/%d" % [def.name, lv, Economy.MAX_LEVEL], Pal.FS, Pal.TEXT))
	info.add_child(Ui.label("Now: " + def.effects[lv], Pal.FS_TINY, Pal.DIM))
	var c := Economy.cost(b, lv)
	if lv < Economy.MAX_LEVEL:
		info.add_child(Ui.label("Next: " + def.effects[lv + 1], Pal.FS_TINY, Pal.GOOD))
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 14)
		for i in 4:
			if c[i] > 0:
				var enough: bool = Game.bank[i] >= c[i]
				var cl := Ui.label("%d %s" % [c[i], Economy.RES_NAMES[i]], Pal.FS_TINY, Pal.RES[i] if enough else Pal.BAD)
				cl.autowrap_mode = TextServer.AUTOWRAP_OFF
				cost_row.add_child(cl)
		info.add_child(cost_row)
	var btn := Ui.button("Build" if lv == 0 else "Upgrade", Pal.GOOD, Pal.FS_SMALL, 100)
	btn.custom_minimum_size.x = 230
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if lv >= Economy.MAX_LEVEL:
		btn.text = "Max"
		btn.disabled = true
	elif not Economy.can_afford(Game.bank, c):
		btn.disabled = true
	btn.pressed.connect(func(): _buy(b))
	h.add_child(btn)
	return p


func _buy(b: int) -> void:
	if Game.buy(b):
		Sfx.play("buy")
		refresh(b)
		var at := _view.building_global(b) + Vector2(0, -80)
		_fx.burst(at, Pal.GOOD, 24, 600.0)
		_fx.text(at, Economy.BUILDINGS[b].effects[Game.levels[b]], Pal.GOOD, 40)


func _site_button(i: int) -> Control:
	var site := Sites.get_site(i)
	var locked := i >= Game.unlocked
	var goals := []
	for g in site.goals:
		goals.append(Sites.goal_text(g))
	var tag := "  [cleared]" if Game.cleared[i] else ""
	var text := "%d. %s%s\n%s" % [i + 1, site.name, tag, " + ".join(goals)]
	if locked:
		text = "%d. Locked\nClear %s first" % [i + 1, Sites.get_site(i - 1).name]
	var color := Pal.ACCENT if not Game.cleared[i] else Pal.PANEL_HI.lightened(0.35)
	var btn := Ui.button(text, color, Pal.FS_SMALL, 130)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = locked
	btn.pressed.connect(func(): launch.emit(i))
	return btn


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
