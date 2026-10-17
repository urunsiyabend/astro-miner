extends SceneTree

## Bot clear rate per dig, with the buildings a player has there (level 1, no upgrades).
## Hand-made digs too (their pinned seed ignored: every run is a fresh ore roll unless the dig
## hand-places its ore). Columns: clear %, moves left on a win, moves used on a win.
##   godot --headless --path . -s res://tools/bot_probe.gd -- [runs] [greedy|planner|sloppy] [c3|c4] [id ...]
## c3 / c4 force every dig to 3 or 4 ore colours (to measure what a colour does).
const LevelsTool := preload("res://tools/levels.gd")


func _initialize() -> void:
	var runs := 30
	var kind := Bots.Kind.PLANNER
	var only := []
	var colours := 0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		elif a == "greedy":
			kind = Bots.Kind.GREEDY
		elif a == "planner":
			kind = Bots.Kind.PLANNER
		elif a == "sloppy":
			kind = Bots.Kind.SLOPPY
		elif a == "c3" or a == "c4":
			colours = int(a.substr(1))
		else:
			only.append(a)
	for i in Sites.count():
		var site: Dictionary = Sites.get_site(i)
		if not only.is_empty() and not only.has(site.id):
			continue
		if colours > 0:
			site = site.duplicate()
			site.colours = colours
		var levels := LevelsTool.campaign_levels(i)
		var need: Dictionary = site.get("needs", {})
		if not need.is_empty():
			levels[need.building] = maxi(levels[need.building], need.level)
		var wins := 0
		var left := 0.0
		var used := 0.0
		for s in runs:
			var m := Bots.play(site, Economy.rules(levels), 4000 + s * 17, kind)
			if m.complete:
				wins += 1
				left += m.energy_left
				used += m.moves + m.drills
		print("%2d %-10s budget %3d  clear %3d%%  left %5.1f  used %5.1f" % [i + 1, site.id,
			int(site.get("energy", 20)), wins * 100 / runs, left / maxi(1, wins), used / maxi(1, wins)])
	quit(0)
