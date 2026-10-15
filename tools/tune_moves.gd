extends SceneTree

## Move-budget tuner. Energy is the dig's move budget, so it is the difficulty lever. The bots
## play each random-ore dig with unlimited energy and record how many moves their wins took;
## the budget is the move count that the target share of those wins fits in (target by the
## dig's place in its chapter, docs/design/level-plan.md). Runs where the bot gets stuck are
## left out: they measure the bot, not the dig.
##   godot --headless --path . -s res://tools/tune_moves.gd -- [runs] [id ...]

## Target clear rate by place in a 10-dig chapter (0-based): a gentle ramp, reward at the end.
const TARGET := [0.95, 0.95, 0.95, 0.95, 0.90, 0.88, 0.84, 0.80, 0.76, 0.98]
const LevelsTool := preload("res://tools/levels.gd")


func _initialize() -> void:
	var runs := 24
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		else:
			only.append(a)
	for i in Sites.count():
		var site: Dictionary = Sites.get_site(i)
		if site.has("ore") or (not only.is_empty() and not only.has(site.id)):
			continue
		var rules := Economy.rules(LevelsTool.campaign_levels(i))
		var target: float = TARGET[mini(i % 10, 9)] if i < 30 else 0.95
		var free := site.duplicate(true)
		free.energy = 200
		var lt := LevelsTool.new()
		var used := []
		for k in runs:
			var m: Dictionary = lt._play(free, rules, 1000 + k, Bots.Kind.PLANNER)
			if m.complete:
				used.append(200 - m.energy_left)
		used.sort()
		if used.is_empty():
			print("%2d %-10s bot never wins" % [i + 1, site.id])
			continue
		var budget: int = used[mini(used.size() - 1, int(ceil(target * used.size())) - 1)]
		print("%2d %-10s target %3d%%  budget %2d  (wins use %d..%d, median %d; bot stuck %d%%)" % [
			i + 1, site.id, int(target * 100), budget, used[0], used[-1], used[used.size() / 2],
			100 - used.size() * 100 / runs])
	quit(0)
