extends Node

## Dev-only screenshot harness (inert unless ASTRO_SHOT is set).
##   ASTRO_SHOT=out.png ASTRO_SCENE=colony|dig ASTRO_MOVES="RRDL" godot --path .
## Plays the scripted moves on site ASTRO_SITE (default 0) with a fixed seed, then saves.

func _ready() -> void:
	Game.save_path = "user://shot_save.json"
	if OS.has_environment("ASTRO_BANK"):
		Game.bank = [999, 999, 999, 99]
		Game.levels = [1, 1, 1]
		Game.unlocked = Sites.count()
	_run.call_deferred()


func _run() -> void:
	var main := get_parent()
	var scene := OS.get_environment("ASTRO_SCENE")
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
			main.dig._close_mission()
		for k in talk * 2:
			if not main.dig._dialog.visible:
				break
			main.dig._dialog._advance()
		await get_tree().create_timer(0.3).timeout
		var map := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
		for ch in OS.get_environment("ASTRO_MOVES"):
			if map.has(ch):
				main.dig._on_move(map[ch])
				await get_tree().create_timer(0.7).timeout
		if OS.has_environment("ASTRO_HINT"):
			main.dig._on_hint()
		var mid := float(OS.get_environment("ASTRO_MID")) if OS.has_environment("ASTRO_MID") else 0.0
		await get_tree().create_timer(0.6 if mid <= 0.0 else mid).timeout
	else:
		main.colony.refresh()
		await get_tree().create_timer(0.5).timeout
	print("main size ", main.size, " colony ", main.colony.size, " vis ", main.colony.visible)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("ASTRO_SHOT"))
	get_tree().quit()
