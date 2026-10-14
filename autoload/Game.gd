extends Node

## Persistent colony state + local play metrics. Saved as JSON after every dig/purchase.

const SAVE_VERSION := 2
# v1 saved cleared sites by position; this was the site order then.
const V1_SITE_ORDER := ["landing", "rubble", "glint", "shale", "vein", "core"]
const LOG_MAX := 60

var save_path := "user://save.json"
var bank := [0, 0, 0, 0]
var levels := [0, 0, 0]
var unlocked := 1
var cleared := []
var sfx_on := true
var tips_seen := {}
var totals := {}
var dig_log := []  # most recent digs, local instrumentation only


func _ready() -> void:
	load_save()


func reset() -> void:
	bank = [0, 0, 0, 0]
	levels = [0, 0, 0]
	unlocked = 1
	cleared = []
	for i in Sites.count():
		cleared.append(false)
	tips_seen = {}
	dig_log = []
	totals = {
		"digs": 0, "clears": 0, "exhausted": 0, "recalled": 0, "moves": 0, "drills": 0,
		"groups": 0, "cascades": 0, "chunks": 0, "pulses": 0, "upgrades": 0,
		"rocks": 0, "crystals": 0, "hints": 0,
	}


func rules() -> Dictionary:
	return Economy.rules(levels)


func buy(building: int) -> bool:
	var lv: int = levels[building]
	var c := Economy.cost(building, lv)
	if not Economy.can_afford(bank, c):
		return false
	for i in 4:
		bank[i] -= c[i]
	levels[building] = lv + 1
	totals.upgrades += 1
	save()
	return true


## Bank a finished dig. reason: "complete" | "energy" | "recall".
func finish_dig(site_index: int, board: Board, reason: String, hints_used := 0) -> Dictionary:
	var haul := [board.haul[0], board.haul[1], board.haul[2], board.haul[3]]
	var bonus := [0, 0, 0, 0]
	var first_clear := false
	if reason == "complete":
		bonus = Economy.completion_bonus(board.energy)
		if not cleared[site_index]:
			first_clear = true
			cleared[site_index] = true
			bonus[3] += Economy.FIRST_CLEAR_CRYSTALS
			unlocked = maxi(unlocked, mini(Sites.count(), site_index + 2))
		totals.clears += 1
	elif reason == "energy":
		totals.exhausted += 1
	else:
		totals.recalled += 1
	for i in 4:
		bank[i] += haul[i] + bonus[i]
	totals.digs += 1
	totals.moves += board.stats.moves
	totals.drills += board.stats.drills
	totals.groups += board.stats.groups
	totals.cascades += board.stats.cascade_groups
	totals.chunks += board.stats.chunks
	totals.pulses += board.stats.pulses
	totals.rocks += board.stats.rocks_broken
	totals.crystals += board.stats.crystals
	totals.hints += hints_used
	dig_log.append({
		"site": Sites.get_site(site_index).id, "reason": reason, "moves": board.stats.moves,
		"groups": board.stats.groups, "chunks": board.stats.chunks, "haul": haul,
		"levels": levels.duplicate(), "time": int(Time.get_unix_time_from_system()),
	})
	while dig_log.size() > LOG_MAX:
		dig_log.pop_front()
	save()
	return {"haul": haul, "bonus": bonus, "first_clear": first_clear, "reason": reason,
			"next_unlocked": first_clear and site_index + 1 < Sites.count()}


func save() -> void:
	var data := {
		"version": SAVE_VERSION, "bank": bank, "levels": levels, "unlocked": unlocked,
		"cleared_ids": cleared_ids(), "sfx_on": sfx_on, "tips_seen": tips_seen, "totals": totals,
		"dig_log": dig_log,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_save() -> void:
	reset()
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("save corrupt, starting fresh")
		return
	bank = _ints(data.get("bank", bank), 4)
	levels = _ints(data.get("levels", levels), 3)
	for i in 3:
		levels[i] = clampi(levels[i], 0, Economy.MAX_LEVEL)
	# Cleared sites are stored by id, so inserting new sites never shifts progress.
	var ids: Array = data.get("cleared_ids", [])
	if not data.has("cleared_ids"):
		var cl: Array = data.get("cleared", [])
		for i in mini(cl.size(), V1_SITE_ORDER.size()):
			if bool(cl[i]):
				ids.append(V1_SITE_ORDER[i])
	for id in ids:
		var k := Sites.index_of(String(id))
		if k >= 0:
			cleared[k] = true
	unlocked = 1
	for i in cleared.size():
		if cleared[i]:
			unlocked = maxi(unlocked, mini(Sites.count(), i + 2))
	sfx_on = bool(data.get("sfx_on", true))
	tips_seen = data.get("tips_seen", {})
	var t: Dictionary = data.get("totals", {})
	for k in t:
		totals[k] = int(t[k])
	dig_log = data.get("dig_log", [])


func cleared_ids() -> Array:
	var out := []
	for i in cleared.size():
		if cleared[i]:
			out.append(Sites.get_site(i).id)
	return out


func _ints(a, n: int) -> Array:
	var out := []
	for i in n:
		out.append(int(a[i]) if a is Array and i < a.size() else 0)
	return out
