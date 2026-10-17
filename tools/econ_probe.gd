extends SceneTree

## Income per dig over the campaign (PLANNER bot, first clears in order, nothing spent).
## Reports the two v3 currencies: Coin (clear reward + moves left) and Star (crystal +
## first-clear).  godot --headless --path . -s res://tools/econ_probe.gd
func _initialize() -> void:
	var n := 20
	var per := []  # [coin, star, win] averaged per dig
	for si in Sites.count():
		per.append([0.0, 0.0, 0.0])
	for c in n:
		var levels := [0, 0, 0, 0]
		for si in Sites.count():
			var site: Dictionary = Sites.get_site(si)
			var m := Bots.play(site, Economy.rules(levels), 777 + c * 31 + si, Bots.Kind.PLANNER)
			var coin := 0
			var star := 0
			if m.complete:
				coin += Economy.clear_coin(si) + Economy.move_coin(m.energy_left)
				star += Economy.FIRST_CLEAR_STARS
			per[si][0] += coin / float(n)
			per[si][1] += star / float(n)
			per[si][2] += (1.0 if m.complete else 0.0) / n
			if site.has("unlock"):
				levels[site.unlock] = 1
	var cum_coin := 0.0
	var cum_star := 0.0
	print("| # | id | Coin | Star | win | cum Coin | cum Star |")
	for si in Sites.count():
		cum_coin += per[si][0]
		cum_star += per[si][1]
		print("| %d | %s | %.0f | %.1f | %.0f%% | %.0f | %.1f |" % [
			si + 1, Sites.get_site(si).id, per[si][0], per[si][1], per[si][2] * 100, cum_coin, cum_star])
	quit(0)
