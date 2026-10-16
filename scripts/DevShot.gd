extends Node

## Dev-only screenshot harness (inert unless ASTRO_SHOT is set).
##   ASTRO_SHOT=out.png ASTRO_SCENE=colony|dig ASTRO_MOVES="RRDL" godot --path .
## Plays the scripted moves on site ASTRO_SITE (default 0) with a fixed seed, then saves.

func _ready() -> void:
	Game.save_path = "user://shot_save.json"
	if OS.has_environment("ASTRO_CLEARED"):
		for i in int(OS.get_environment("ASTRO_CLEARED")):
			Game.cleared[i] = true
	if OS.has_environment("ASTRO_BANK"):
		Game.coin = 9999
		Game.star = 999
		Game.levels = [1, 1, 1]
		Game.unlocked = Sites.count()
	# colony states: ASTRO_STAR=<stars>, ASTRO_LEVELS=<p,w,l>; milestones count as celebrated
	# unless ASTRO_FRESH is set (then the colony plays its milestone/unlock walkthrough)
	if OS.has_environment("ASTRO_STAR"):
		Game.star = int(OS.get_environment("ASTRO_STAR"))
		Game.coin = maxi(Game.coin, 200)
		if not OS.has_environment("ASTRO_FRESH"):
			Game.milestones_seen = Game.milestones_reached()
			for b in 3:
				Game.tips_seen["unlock_%d" % b] = true
	if OS.has_environment("ASTRO_LEVELS"):
		var lv := OS.get_environment("ASTRO_LEVELS").split(",")
		for b in mini(3, lv.size()):
			Game.levels[b] = int(lv[b])
	_run.call_deferred()


func _run() -> void:
	var main := get_parent()
	var scene := OS.get_environment("ASTRO_SCENE")
	if OS.has_environment("ASTRO_PLANET"):
		Art.planet = OS.get_environment("ASTRO_PLANET")
	await get_tree().create_timer(0.3).timeout
	if scene == "dig":
		var site := int(OS.get_environment("ASTRO_SITE")) if OS.has_environment("ASTRO_SITE") else 0
		main.colony.visible = false
		main.dig.visible = true
		main.dig.start(site, false, 12345)
		await get_tree().create_timer(0.4).timeout
		# ASTRO_TALK=n: tap through the goal card and n of Mira's lines first (all if unset)
		var talk := int(OS.get_environment("ASTRO_TALK")) if OS.has_environment("ASTRO_TALK") else 99
		if talk >= 0:
			main.dig._close_mission(true)
		for k in talk * 2:
			if not main.dig._dialog.visible:
				break
			main.dig._dialog._advance()
		await get_tree().create_timer(0.3).timeout
		var map := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
		for ch in OS.get_environment("ASTRO_MOVES"):
			if map.has(ch):
				main.dig._on_move(map[ch])
				await get_tree().create_timer(float(OS.get_environment("ASTRO_MOVEWAIT")) if OS.has_environment("ASTRO_MOVEWAIT") else 0.7).timeout
		if OS.has_environment("ASTRO_HAUL"):
			main.dig._toggle_haul()
		if OS.has_environment("ASTRO_HINT"):
			main.dig._on_hint()
		if OS.has_environment("ASTRO_FOCUS"):  # ASTRO_FOCUS="x,y;x,y": frame those cells
			var cells := []
			for p in OS.get_environment("ASTRO_FOCUS").split(";"):
				var xy := p.split(",")
				cells.append(Vector2i(int(xy[0]), int(xy[1])))
			main.dig.view.focus = cells
		if OS.has_environment("ASTRO_HINTDIR"):  # ASTRO_HINTDIR=0..3: frame the hinted step
			main.dig.view.hint_dir = int(OS.get_environment("ASTRO_HINTDIR"))
		if OS.has_environment("ASTRO_ENERGY"):  # ASTRO_ENERGY=n: moves left (e.g. the low-moves beat)
			main.dig.board.energy = int(OS.get_environment("ASTRO_ENERGY"))
			main.dig._hud.set_energy(main.dig.board.energy, main.dig.board.cfg.capacity)
		if OS.has_environment("ASTRO_RESULT"):  # ASTRO_RESULT=complete|recall: end the dig now
			if OS.get_environment("ASTRO_RESULT") == "complete":
				main.dig.board.complete = true
			main.dig.board.over = true
			main.dig._show_result()
		var mid := float(OS.get_environment("ASTRO_MID")) if OS.has_environment("ASTRO_MID") else 0.0
		await get_tree().create_timer(0.6 if mid <= 0.0 else mid).timeout
	else:
		main.colony.refresh()
		await get_tree().create_timer(0.5).timeout
		# ASTRO_TALK=n taps through n of Mira's colony lines; ASTRO_BUY=b then buys building b
		var talk := int(OS.get_environment("ASTRO_TALK")) if OS.has_environment("ASTRO_TALK") else 0
		for k in talk * 2:
			if main.colony._dialog.visible:
				main.colony._dialog._advance()
		await get_tree().create_timer(0.4).timeout
		if OS.has_environment("ASTRO_BUY"):
			main.colony._spot.close()
			main.colony._buy(int(OS.get_environment("ASTRO_BUY")))
			await get_tree().create_timer(0.3).timeout
			for k in 8:
				if main.colony._dialog.visible:
					main.colony._dialog._advance()
		if OS.has_environment("ASTRO_CARD"):  # ASTRO_CARD=b: tap building b's plot
			main.colony._on_plot(Colony.building_plot(int(OS.get_environment("ASTRO_CARD"))))
		await get_tree().create_timer(0.6).timeout
	if OS.has_environment("ASTRO_DUMP"):  # print every visible control's global rect
		var stack: Array = [main]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Control and (n as Control).is_visible_in_tree():
				print(n.get_path(), " ", n.get_class(), " ", (n as Control).get_global_rect())
			stack.append_array(n.get_children())
	print("main size ", main.size, " colony ", main.colony.size, " vis ", main.colony.visible)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("ASTRO_SHOT"))
	get_tree().quit()
