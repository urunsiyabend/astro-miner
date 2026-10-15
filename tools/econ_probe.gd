extends SceneTree

## Income per dig over the campaign (PLANNER bot, first clears in order, nothing spent).
##   godot --headless --path . -s res://tools/econ_probe.gd
func _initialize() -> void:
	var n := 20
	var per := []
	for si in Sites.count():
		per.append([0.0, 0.0, 0.0, 0.0, 0.0])
	for c in n:
		var levels := [0, 0, 0]
		for si in Sites.count():
			var site: Dictionary = Sites.get_site(si)
			if site.has("unlock"):
				pass
			var m := Bots.play(site, Economy.rules(levels), 777 + c * 31 + si, Bots.Kind.PLANNER)
			var inc := [0, 0, 0, 0]
			for r in 4:
				inc[r] += m.haul[r]
			if m.complete:
				var b := Economy.completion_bonus(m.energy_left)
				for r in 4:
					inc[r] += b[r]
				inc[3] += Economy.FIRST_CLEAR_CRYSTALS
			for r in 4:
				per[si][r] += inc[r] / float(n)
			per[si][4] += (1.0 if m.complete else 0.0) / n
			if site.has("unlock"):
				levels[site.unlock] = 1
	var cum := [0.0, 0.0, 0.0, 0.0]
	print("| # | id | F | C | L | cr | win | cum F | cum C | cum L | cum cr |")
	for si in Sites.count():
		for r in 4:
			cum[r] += per[si][r]
		print("| %d | %s | %.0f | %.0f | %.0f | %.1f | %.0f%% | %.0f | %.0f | %.0f | %.1f |" % [si + 1, Sites.get_site(si).id, per[si][0], per[si][1], per[si][2], per[si][3], per[si][4] * 100, cum[0], cum[1], cum[2], cum[3]])
	quit(0)
