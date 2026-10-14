extends Node

## Persistent colony state + local play metrics. Saved as JSON after every dig/purchase.

const SAVE_VERSION := 2
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
var reminders := []  # [building, level] pairs Mira still has to mention at the next dig


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
	reminders = []
	totals = {
		"digs": 0, "clears": 0, "exhausted": 0, "recalled": 0, "moves": 0, "drills": 0,
		"groups": 0, "cascades": 0, "chunks": 0, "pulses": 0, "upgrades": 0,
		"rocks": 0, "crystals": 0, "hints": 0,
	}


func rules() -> Dictionary:
	return Economy.rules(levels)


## A building is unlocked once the dig that brings it (Sites "unlock") is cleared.
func building_unlocked(b: int) -> bool:
	for i in Sites.count():
		if cleared[i] and Sites.get_site(i).get("unlock", -1) == b:
			return true
	return false


## The next building the campaign will unlock and the dig that does it: [building, dig], or [].
func next_unlock() -> Array:
	for i in Sites.count():
		var u: int = Sites.get_site(i).get("unlock", -1)
		if u >= 0 and not cleared[i]:
			return [u, i]
	return []


## Unlocked building still at level 0: the colony asks you to build it before moving on.
func pending_build() -> int:
	for b in Economy.BUILDINGS.size():
		if levels[b] == 0 and building_unlocked(b):
			return b
	return -1


func buy(building: int) -> bool:
	if not building_unlocked(building):
		return false
	var lv: int = levels[building]
	var c := Economy.cost(building, lv)
	if not Economy.can_afford(bank, c):
		return false
	for i in 4:
		bank[i] -= c[i]
	levels[building] = lv + 1
	reminders.append([building, lv + 1])
	totals.upgrades += 1
	save()
	return true


## Index of the next campaign dig (first one not cleared yet), or -1 when all are done.
func next_dig() -> int:
	for i in Sites.count():
		if not cleared[i]:
			return i
	return -1


## Whether the colony has what dig i needs (e.g. the drill for a basalt shell).
func can_start(i: int) -> bool:
	var need: Dictionary = Sites.get_site(i).get("needs", {})
	return need.is_empty() or levels[need.building] >= need.level


## A cleared open site to replay for resources (random layout each time).
func supply_site() -> int:
	var pool := []
	for i in Sites.count():
		var s := Sites.get_site(i)
		if cleared[i] and not s.has("ore") and can_start(i):
			pool.append(i)
	if pool.is_empty():
		return maxi(0, Sites.index_of("landing"))
	return pool[randi() % pool.size()]


## Mira's reminders about new colony tech, consumed by the next dig.
func take_reminders() -> Array:
	var out := []
	for r in reminders:
		out.append(Story.REMIND[r[0]][r[1] - 1])
	reminders = []
	return out


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
		"cleared_ids": cleared_ids(), "reminders": reminders, "sfx_on": sfx_on, "tips_seen": tips_seen, "totals": totals,
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
	for id in data.get("cleared_ids", []):
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
	reminders = []
	for r in data.get("reminders", []):
		if r is Array and r.size() == 2 and int(r[0]) in [0, 1, 2] and int(r[1]) >= 1 and int(r[1]) <= Economy.MAX_LEVEL:
			reminders.append([int(r[0]), int(r[1])])


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
