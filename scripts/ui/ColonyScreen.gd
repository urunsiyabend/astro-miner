class_name ColonyScreen
extends Control

## The colony (GDD v3 §4): one screen, no list. A compact top bar (Coin and the bar toward the
## next star milestone, room on the right for lives later), the colony map in the middle
## (Colony / ColonyView), Mira and the DIG button below it, and the tab bar at the bottom
## (Market, Ranks, Colony, a placeholder, Settings). Tapping a building on the map opens its
## card (what it does, the next level and its Coin cost). Reaching a star milestone grows the
## map: a new building plot to build for free, or a decoration that Mira announces. The field
## log, sound and reset live in the Settings tab while we are testing.

signal launch(site_index: int, supply: bool)

const NAV_H := 200.0

var _top: Widgets.ColonyTop
var _view: ColonyView
var _advice: Dialog.Coach
var _dialog: Dialog.Overlay
var _spot: Dialog.Spotlight
var _go_btn: Widgets.JellyButton
var _nav: Widgets.NavBar
var _fx: FxLayer
var _card_layer: Control
var _panel: Control       # a tab's page over the colony (settings, coming soon)
var _log: Label
var _sound_btn: Button
var _reset_btn: Button
var _reset_armed := 0.0
var _building := false   # a build animation is playing: taps are ignored


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
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", int(NAV_H) + 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_top = Widgets.ColonyTop.new()
	col.add_child(_top)

	_view = ColonyView.new()
	_view.plot_tapped.connect(_on_plot)
	_view.landed.connect(_on_landed)
	col.add_child(_view)

	_advice = Dialog.Coach.new()
	col.add_child(_advice)

	_go_btn = Widgets.JellyButton.new("DIG", Color("ffd27a"), Color("f0901c"), 150.0, 72)
	_go_btn.custom_minimum_size.x = 560
	_go_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_go_btn.pressed.connect(_on_go)
	col.add_child(_go_btn)

	_nav = Widgets.NavBar.new()
	_nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_nav.offset_top = -NAV_H
	_nav.tab_pressed.connect(_on_tab)
	add_child(_nav)

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
		if _reset_armed <= 0.0 and _reset_btn != null:
			_reset_btn.text = "Reset"


# --- tabs ---------------------------------------------------------------------

func _on_tab(i: int) -> void:
	_close_panel()
	_nav.select(i)
	match i:
		2: pass  # the colony itself
		4: _open_settings()
		_: _open_soon(Widgets.NavBar.TABS[i][0], Widgets.NavBar.TABS[i][1])


func _open_panel(card: Control) -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_bottom = -NAV_H
	add_child(_panel)
	move_child(_panel, _nav.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_on_tab(2))
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(center)
	center.add_child(card)
	card.scale = Vector2(0.85, 0.85)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Movement prototypes (Sites.protos()): drawn paths plus board elements that move things
## (launch pads, belts, tunnels). They never count as progress and pay nothing.
func _open_protos() -> void:
	_close_panel()
	var card := Widgets.JellyCard.new(48.0)
	card.custom_minimum_size.x = 900
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	v.add_child(Widgets.JuicyText.new("Prototypes", 70, Color.WHITE, 0.1))
	var intro := Ui.label("Hold the robot and draw a path. Launch pads, belts and tunnels move things around: which ideas are fun?", Pal.FS_SMALL, Color("e7dcff"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.custom_minimum_size.x = 780
	v.add_child(intro)
	var faces := [Color("2f97ea"), Color("37b65a"), Color("c0394f"), Color("c77a1c"), Color("8a4fd8")]
	var list: Array = Sites.proto_list()
	for k in list.size():
		var b := Widgets.JellyButton.new(list[k][0], faces[k % faces.size()].lightened(0.35), faces[k % faces.size()], 110.0, 46)
		b.custom_minimum_size.x = 640
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var index: int = list[k][1]
		b.pressed.connect(func():
			_close_panel()
			launch.emit(index, false))
		v.add_child(b)
	_open_panel(card)


## Dev mode (Settings): Dig opens every level, campaign and prototypes, to play any of them.
## The next dig is marked; a level played this way counts like any other.
func _open_levels() -> void:
	_close_panel()
	var card := Widgets.JellyCard.new(40.0)
	card.custom_minimum_size.x = 960
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(Widgets.JuicyText.new("Levels", 64, Color.WHITE, 0.1))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 1180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var next := Game.next_dig()
	var items := []
	for i in Sites.count():
		var n := Sites.dig_number(i)
		items.append([("%d %s" % [n, Sites.get_site(i).id]) if n > 0 else String(Sites.get_site(i).id), i])
	items.append_array(Sites.proto_list().map(func(p): return ["P" + String(p[0]), p[1]]))
	for it in items:
		var i: int = it[1]
		var face := Color("37b65a") if i == next else (Color("8a4fd8") if i >= Sites.count() else Color("2f97ea"))
		var b := Widgets.JellyButton.new(it[0], face.lightened(0.35), face, 92.0, 32)
		b.custom_minimum_size.x = 288
		b.pressed.connect(func():
			_close_panel()
			launch.emit(i, false))
		grid.add_child(b)
	_open_panel(card)


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_reset_btn = null
	_sound_btn = null


## Placeholder page for a tab that is not built yet.
func _open_soon(icon: String, title: String) -> void:
	var card := Widgets.JellyCard.new(56.0)
	card.custom_minimum_size.x = 760
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	var pic := Widgets.Picture.new("res://assets/ui/tabs/%s.png" % icon, 220.0, 0.05)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	v.add_child(Widgets.JuicyText.new(title, 72, Color.WHITE, 0.15))
	v.add_child(Widgets.JuicyText.new("Coming soon", 44, Color("d9ccf2"), 0.3))
	_open_panel(card)


func _open_settings() -> void:
	var card := Widgets.JellyCard.new(56.0)
	card.custom_minimum_size.x = 800
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	card.add_child(v)
	v.add_child(Widgets.JuicyText.new("Settings", 72, Color.WHITE, 0.1))
	_sound_btn = Widgets.JellyButton.new("", Color("8fe0f0"), Color("2f9fb8"), 120.0, 48)
	_sound_btn.pressed.connect(func():
		Game.sfx_on = not Game.sfx_on
		Game.save()
		_sound_btn.text = "Sound: %s" % ("On" if Game.sfx_on else "Off"))
	_sound_btn.text = "Sound: %s" % ("On" if Game.sfx_on else "Off")
	v.add_child(_sound_btn)
	var music_btn := Widgets.JellyButton.new("", Color("c9a8ff"), Color("6f4fb8"), 120.0, 48)
	music_btn.text = "Music: %s" % ("On" if Game.music_on else "Off")
	music_btn.pressed.connect(func():
		Game.music_on = not Game.music_on
		Game.save()
		music_btn.text = "Music: %s" % ("On" if Game.music_on else "Off"))
	v.add_child(music_btn)
	var path_btn := Widgets.JellyButton.new("", Color("7fe8ff"), Color("2f7fb8"), 120.0, 48)
	var path_text := func(): return "Path: %s" % ("Off" if Game.path_max <= 1 else "%d steps" % Game.path_max)
	path_btn.text = path_text.call()
	path_btn.pressed.connect(func():
		var opts := [1, 3, 4, 5]
		Game.path_max = opts[(opts.find(Game.path_max) + 1) % opts.size()]
		Game.save()
		path_btn.text = path_text.call())
	v.add_child(path_btn)
	var fps_btn := Widgets.JellyButton.new("", Color("b8f59a"), Color("4f9a3a"), 120.0, 48)
	fps_btn.text = "FPS: %s" % ("On" if Game.show_fps else "Off")
	fps_btn.pressed.connect(func():
		Game.show_fps = not Game.show_fps
		Game.save()
		fps_btn.text = "FPS: %s" % ("On" if Game.show_fps else "Off"))
	v.add_child(fps_btn)
	var dev_btn := Widgets.JellyButton.new("", Color("ff9ae0"), Color("b8378f"), 120.0, 48)
	dev_btn.text = "Dev mode: %s" % ("On" if Game.dev_mode else "Off")
	dev_btn.pressed.connect(func():
		Game.dev_mode = not Game.dev_mode
		Game.save()
		refresh()
		dev_btn.text = "Dev mode: %s" % ("On" if Game.dev_mode else "Off"))
	v.add_child(dev_btn)
	var proto_btn := Widgets.JellyButton.new("Prototypes", Color("ffd27a"), Color("c77a1c"), 120.0, 48)
	proto_btn.pressed.connect(_open_protos)
	v.add_child(proto_btn)
	_reset_btn = Widgets.JellyButton.new("Reset", Color("ff9a9a"), Color("c0394f"), 120.0, 48)
	_reset_btn.pressed.connect(_on_reset)
	v.add_child(_reset_btn)
	# testing: the field log and the build version
	_log = Ui.label("", Pal.FS_TINY, Pal.DIM)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size.x = 680
	v.add_child(_log)
	v.add_child(Ui.label("v%s · prototype" % ProjectSettings.get_setting("application/config/version", "0"), Pal.FS_TINY, Pal.MUTED))
	_fill_log()
	_open_panel(card)


func _fill_log() -> void:
	if _log == null or not is_instance_valid(_log):
		return
	var t: Dictionary = Game.totals
	var mpm := float(t.moves) / maxf(1.0, t.groups)
	_log.text = "Digs %d · cleared %d · out of moves %d · recalled %d\nMoves %d · extractions %d (%.1f moves each) · cascades %d\nRock broken %d · crystals %d · pulses %d · hints %d · upgrades %d" % [
		t.digs, t.clears, t.exhausted, t.recalled, t.moves, t.groups, mpm, t.cascades,
		t.rocks, t.crystals, t.pulses, t.hints, t.upgrades]


## celebrate: a building index whose plot gets a celebration ring (after a build/upgrade).
func refresh(celebrate := -1) -> void:
	var nm := Game.next_milestone()
	if nm.is_empty():
		_top.set_values(Game.coin, 1.0, "%d" % Game.star)
	else:
		_top.set_values(Game.coin, Game.milestone_progress(), "%d/%d" % [Game.star, nm[1]])
	_view.set_state(Game.levels, Game.star, Game.made)
	if celebrate >= 0:
		_view.celebrate(Colony.building_plot(celebrate))
	var next := Game.next_dig()
	_go_btn.disabled = false
	_go_btn.modulate = Color.WHITE
	if Game.dev_mode:
		_go_btn.add_theme_font_size_override("font_size", 72)
		_go_btn.text = "DIG"
		_go_btn.paint(Color("ff9ae0"), Color("b8378f"))  # dev mode: Dig opens every level
	elif Game.pending_build() >= 0:
		# a freshly unlocked building comes first: its tool is what the next dig teaches
		_go_btn.text = "BUILD FIRST"
		_go_btn.add_theme_font_size_override("font_size", 54)
		_go_btn.disabled = true
		_go_btn.modulate = Color(0.7, 0.7, 0.75)
	elif next >= 0 and Game.can_start(next):
		_go_btn.add_theme_font_size_override("font_size", 72)
		_go_btn.text = "DIG"
		_go_btn.paint(Color("ffd27a"), Color("f0901c"))
	else:
		_go_btn.add_theme_font_size_override("font_size", 60)
		_go_btn.text = "SUPPLY RUN"
		_go_btn.paint(Color("8fe0f0"), Color("2f9fb8"))
	_fill_log()
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
	if not visible or _building or _dialog.is_open() or _spot.visible or _card_layer != null:
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
	_advice.clear()   # the spotlight has its own line; no second bubble under it
	_spot.point(btn, "Tap here to build the %s. This one is free!" % Economy.BUILDINGS[b].name, func(): _buy(b))


func _spot_dig(text := "Now tap DIG. I'll show you how to use it down there.") -> void:
	await get_tree().process_frame
	_advice.clear()
	_spot.point(_go_btn, text, _on_go)


func _on_plot(i: int) -> void:
	if _building or _spot.visible:
		return
	var plot: Dictionary = Colony.PLOTS[i]
	if _view.plot_state(i) == "locked":
		# a little shake and a popped line right at the plot, not a coach line below
		_view.nudge(i)
		var at := _view.plot_global(i) - Vector2(0, _view.size.x * 0.12)
		at.x = clampf(at.x, size.x * 0.3, size.x * 0.7)   # keep the whole line on screen
		_fx.text(at, "Earn more stars!", Color("fff2b0"), 52)
		Sfx.play("bump")
		return
	if not plot.has("building"):
		return
	var b: int = plot.building
	if Game.levels[b] == 0:
		_buy(b)
		return
	_view.poke(i)
	if Game.made[b] > 0:
		_collect(b, i)
		return
	# the building answers the tap first (squash-hop, a soft sound), then its card pops up
	Sfx.play("tap")
	_building = true
	await get_tree().create_timer(0.16).timeout
	_building = false
	_open_card(b)


## Collect what building b has made: its bubble bursts and the boosters fly to the DIG button
## (they are used in digs), with a popped "+1 Bomb".
func _collect(b: int, i: int) -> void:
	var at := _view.bubble_global(i)
	var k: int = Economy.BUILDINGS[b].booster
	var n := Game.collect(b)
	_view.pop_bubble(i)
	_view.set_state(Game.levels, Game.star, Game.made)
	var tex := Art.tex("res://assets/ui/boosters/%s.png" % Widgets.BoosterBar.ICONS[k])
	_fx.targets["dig"] = func(): return _go_btn.get_global_rect().get_center()
	for j in n:
		_fx.fly_icon(at, "dig", tex, 120.0, j * 0.12)
	_fx.burst(at, Color("fff2b0"), 14, 520.0)
	_fx.text(at - Vector2(0, 60), "+%d %s" % [n, Economy.BOOSTERS[k].name], Color("fff2b0"), 56)
	Sfx.play("collect")


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
	card.custom_minimum_size.x = 860
	center.add_child(card)


func _close_card() -> void:
	if _card_layer != null:
		_card_layer.queue_free()
		_card_layer = null


func _on_go() -> void:
	if Game.dev_mode:
		_open_levels()
		return
	var next := Game.next_dig()
	if next >= 0 and Game.can_start(next):
		launch.emit(next, false)
	else:
		launch.emit(Game.supply_site(), true)


## A building's card: its painted sprite, name and level stars, what it does now and what the
## next level brings, and the Coin cost on the upgrade button. Same jelly look as the dig cards.
func _card(b: int) -> Control:
	var def: Dictionary = Economy.BUILDINGS[b]
	var lv: int = Game.levels[b]
	var card := Widgets.JellyCard.new(52.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 48)
	close.add_theme_color_override("font_color", Color("d9ccf2"))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(80, 60)
	close.pressed.connect(_close_card)
	v.add_child(close)
	var pic := Widgets.Picture.new("res://assets/colony/%s.png" % Colony.PLOTS[Colony.building_plot(b)].id, 300.0, 0.05)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	v.add_child(Widgets.JuicyText.new(def.name, 70, Color.WHITE, 0.1))
	var stars := Widgets.LevelStars.new(lv, Economy.MAX_LEVEL)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(stars)
	if lv > 0:
		v.add_child(Widgets.EffectPlate.new("Now", Economy.effect(b, lv), Color("b9a6e8")))
	var c := Economy.cost(b, lv)
	if lv < Economy.MAX_LEVEL:
		v.add_child(Widgets.EffectPlate.new("Next" if lv > 0 else "Gives", Economy.effect(b, lv + 1), Pal.GOOD))
		var btn := Widgets.CostButton.new("Build" if lv == 0 else "Upgrade", c, Economy.can_afford(Game.coin, c))
		btn.pressed.connect(func(): _buy(b))
		v.add_child(btn)
	else:
		v.add_child(Widgets.JuicyText.new("Max level!", 56, Pal.COIN, 0.2))
	card.scale = Vector2(0.8, 0.8)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return card


func _buy(b: int) -> void:
	if not Game.buy(b):
		return
	_close_card()
	var fresh: bool = Game.levels[b] == 1
	# nothing can be tapped while it builds: the tap that started it must not reach the plot
	# button under it either (that opened the card over the animation)
	var lock := Control.new()
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lock)
	_building = true
	refresh()
	_view.build_anim(Colony.building_plot(b), fresh)
	Sfx.play("pulse" if fresh else "buy")
	await get_tree().create_timer(_view.BUILD_T + 0.2).timeout
	lock.queue_free()
	_building = false
	var lines: Array = Story.BUILT[b][Game.levels[b] - 1]
	if fresh:
		# a brand-new tool: straight to the DIG button, Mira's line on the spotlight
		_spot_dig(" ".join(lines) + " Tap DIG to try it!")
	else:
		_dialog.say(lines)


## A building hit the ground (build) or topped its hop (upgrade): dust, sparkles, a shake.
func _on_landed(i: int) -> void:
	var at := _view.plot_global(i)
	var plot: Dictionary = Colony.PLOTS[i]
	var b: int = plot.get("building", -1)
	var fresh: bool = b >= 0 and Game.levels[b] == 1
	if fresh:
		_fx.burst(at, Color("c9875a"), 26, 520.0)        # dirt
		_fx.burst(at, Color("f3e3ff"), 14, 380.0)        # dust
		_fx.burst(at - Vector2(0, 60), Pal.COIN, 16, 640.0)
		Sfx.play("quake")
		_shake(14.0)
	else:
		_fx.burst(at - Vector2(0, 90), Pal.STAR, 22, 600.0)
		_fx.burst(at - Vector2(0, 90), Pal.COIN, 12, 480.0)
		Sfx.play("buy")
		_shake(6.0)
	if b >= 0:
		var title: String = Economy.BUILDINGS[b].name if fresh else "Level %d!" % Game.levels[b]
		_fx.text(at - Vector2(0, _view.size.x * 0.2), title, Color("fff2b0"), 60)
	if Engine.has_singleton("Android") or OS.has_feature("mobile"):
		Input.vibrate_handheld(40 if fresh else 20)


func _shake(px: float) -> void:
	var tw := create_tween()
	for k in 6:
		var a := px * (1.0 - k / 6.0)
		tw.tween_property(_view, "position:x", _view.position.x + (a if k % 2 == 0 else -a), 0.035)
	tw.tween_property(_view, "position:x", _view.position.x, 0.04)


func _on_reset() -> void:
	if _reset_armed <= 0.0:
		_reset_armed = 2.5
		_reset_btn.text = "Tap again"
		return
	Game.reset()
	Game.save()
	_reset_armed = 0.0
	if _reset_btn != null:
		_reset_btn.text = "Reset"
	refresh()
