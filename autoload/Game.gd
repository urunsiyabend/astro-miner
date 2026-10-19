extends Node

## Persistent colony state + local play metrics. Saved as JSON after every dig/purchase.

const SAVE_VERSION := 3
const LOG_MAX := 60

var save_path := "user://save.json"
var coin := 0            # soft currency: every ore chunk merges into Coin; the only spent one
var star := 0            # progress counter, NEVER spent: +1 per dig first-clear (= digs cleared)
var levels := [0, 0, 0, 0]  # by Economy.BUILDINGS index [power, workshop, lab, teleporter]
var boosters := [0, 0, 0, 0]  # inventory, by Economy.Booster
var made := [0, 0, 0, 0]      # boosters waiting on each building to be collected
var made_progress := [0, 0, 0, 0]  # clears toward each building's next booster
var unlocked := 1
var cleared := []
var sfx_on := true
var music_on := true
var path_max := 4  # drawn paths: most steps per path (1: off, a swipe is one step)
var show_fps := false  # Settings: a frame-rate readout in the corner (to test on a phone)
var dev_mode := false  # Settings: Dig opens a list of every level (to test any of them on a phone)
var tips_seen := {}
var totals := {}
var dig_log := []  # most recent digs, local instrumentation only
var reminders := []  # [building, level] pairs Mira still has to mention at the next dig
var milestones_seen := 0  # star milestones the colony has already celebrated
var treasure_dry := 0  # digs since a treasure chest last turned up (bad-luck protection)


func _ready() -> void:
	load_save()


func reset() -> void:
	coin = 0
	star = 0
	levels = [0, 0, 0, 0]
	boosters = [0, 0, 0, 0]
	made = [0, 0, 0, 0]
	made_progress = [0, 0, 0, 0]
	unlocked = 1
	cleared = []
	for i in Sites.count():
		cleared.append(false)
	tips_seen = {}
	dig_log = []
	reminders = []
	milestones_seen = 0
	treasure_dry = 0
	totals = {
		"digs": 0, "clears": 0, "exhausted": 0, "recalled": 0, "moves": 0, "drills": 0,
		"groups": 0, "cascades": 0, "chunks": 0, "pulses": 0, "upgrades": 0,
		"rocks": 0, "crystals": 0, "hints": 0,
	}


func rules() -> Dictionary:
	return Economy.rules(levels)


## A building is unlocked once the colony reaches its star milestone (GDD v3 §4).
func building_unlocked(b: int) -> bool:
	return star >= Economy.STAR_UNLOCK[b]


## How many colony milestones the current star count has reached (drives colony growth).
func milestones_reached() -> int:
	var n := 0
	for m in Economy.STAR_MILESTONES:
		if star >= m:
			n += 1
	return n


## Milestones reached since the colony last celebrated, oldest first (indices into
## Economy.STAR_MILESTONES / Colony.MILESTONES).
func new_milestones() -> Array:
	return range(milestones_seen, milestones_reached())


func ack_milestones() -> void:
	milestones_seen = maxi(milestones_seen, milestones_reached())
	save()


## The next star milestone: [index, stars needed], or [] when all are reached.
func next_milestone() -> Array:
	var n := milestones_reached()
	return [n, Economy.STAR_MILESTONES[n]] if n < Economy.STAR_MILESTONES.size() else []


## Progress from the last milestone reached to the next one, 0..1 (1 when all are reached).
func milestone_progress() -> float:
	var n := milestones_reached()
	if n >= Economy.STAR_MILESTONES.size():
		return 1.0
	var lo: int = Economy.STAR_MILESTONES[n - 1] if n > 0 else 0
	var hi: int = Economy.STAR_MILESTONES[n]
	return clampf(float(star - lo) / float(hi - lo), 0.0, 1.0)


## The next building the colony will unlock and the star it needs: [building, star], or [].
func next_unlock() -> Array:
	for b in Economy.BUILDINGS.size():
		if not building_unlocked(b):
			return [b, Economy.STAR_UNLOCK[b]]
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
	var c := Economy.cost(building, lv)  # Coin; level 0 -> 1 is free (0)
	if not Economy.can_afford(coin, c):
		return false
	coin -= c
	levels[building] = lv + 1
	if lv == 0:  # a new building hands out its first booster at once
		boosters[Economy.BUILDINGS[building].booster] += 1
	reminders.append([building, lv + 1])
	totals.upgrades += 1
	save()
	return true


## A cleared dig moves every built building toward its next booster (GDD v4 §1).
func _produce() -> void:
	for b in Economy.BUILDINGS.size():
		var lv: int = levels[b]
		if lv <= 0:
			continue
		if made[b] >= Economy.HOLD[lv]:
			continue  # full: it waits to be collected
		made_progress[b] += 1
		if made_progress[b] >= Economy.PRODUCE_EVERY[lv]:
			made_progress[b] = 0
			made[b] += 1


## Collect what building b has made: into the inventory. Returns how many.
func collect(b: int) -> int:
	var n: int = made[b]
	if n <= 0:
		return 0
	boosters[Economy.BUILDINGS[b].booster] += n
	made[b] = 0
	save()
	return n


func booster_unlocked(k: int) -> bool:
	return levels[Economy.BOOSTERS[k].building] >= 1


## Spend one booster k (a dig used it). False if none is left.
func use_booster(k: int) -> bool:
	if boosters[k] <= 0:
		return false
	boosters[k] -= 1
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
## `taught`: a building whose lesson dig is about to teach its tool: only its booster is
## announced (the dig's own script teaches the tool).
func take_reminders(taught := -1) -> Array:
	var out := []
	for r in reminders:
		var line: String = Story.REMIND[r[0]][r[1] - 1]
		if r[0] == taught and r[1] == 1:
			line = Story.REMIND_BOOSTER[r[0]]
		if line != "":
			out.append(line)
	reminders = []
	return out


## Bank a finished dig. reason: "complete" | "energy" | "recall".
func finish_dig(site_index: int, board: Board, reason: String, hints_used := 0) -> Dictionary:
	if Sites.get_site(site_index).get("proto", false):
		# a core-loop prototype (Settings > Prototypes): never progress, never pay
		return {"haul": Array(board.haul), "coin": 0, "star": 0, "clear_coin": 0, "move_coin": 0,
				"treasure_coin": 0, "first_clear": false, "reason": reason, "next_unlocked": false}
	var haul := Array(board.haul)
	var rush: bool = Sites.get_site(site_index).get("gold_rush", false)
	var coin_gain: int = board.treasure_coin  # chests pay whatever happens next
	var star_gain := 0
	var clear_coin := 0
	var move_coin := 0
	var first_clear := false
	if rush and reason == "energy":
		reason = "rush"                # a gold rush has no fail: the moves ran out, it's done
	if reason == "complete" or reason == "rush":
		clear_coin = 0 if rush else Economy.clear_coin(site_index)
		move_coin = Economy.move_coin(board.energy)
		coin_gain += clear_coin + move_coin
		if not cleared[site_index]:
			first_clear = true
			cleared[site_index] = true
			star_gain += Economy.FIRST_CLEAR_STARS           # +1 Star per dig first-clear
			unlocked = maxi(unlocked, mini(Sites.count(), site_index + 2))
		totals.clears += 1
		_produce()
	elif reason == "energy":
		totals.exhausted += 1
	else:
		totals.recalled += 1
	coin += coin_gain
	star += star_gain
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
	return {"haul": haul, "coin": coin_gain, "star": star_gain, "clear_coin": clear_coin,
			"move_coin": move_coin, "treasure_coin": board.treasure_coin,
			"first_clear": first_clear, "reason": reason,
			"next_unlocked": first_clear and site_index + 1 < Sites.count()}


func save() -> void:
	var data := {
		"version": SAVE_VERSION, "coin": coin, "star": star, "levels": levels, "unlocked": unlocked,
		"cleared_ids": cleared_ids(), "reminders": reminders, "sfx_on": sfx_on, "music_on": music_on, "path_max": path_max, "show_fps": show_fps, "dev_mode": dev_mode, "tips_seen": tips_seen, "totals": totals,
		"dig_log": dig_log, "milestones_seen": milestones_seen, "treasure_dry": treasure_dry,
		"boosters": boosters, "made": made, "made_progress": made_progress,
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
	levels = _ints(data.get("levels", levels), Economy.BUILDINGS.size())
	for i in levels.size():
		levels[i] = clampi(levels[i], 0, Economy.MAX_LEVEL)
	boosters = _ints(data.get("boosters", boosters), Economy.BOOSTERS.size())
	made = _ints(data.get("made", made), Economy.BUILDINGS.size())
	made_progress = _ints(data.get("made_progress", made_progress), Economy.BUILDINGS.size())
	# Cleared sites are stored by id, so inserting new sites never shifts progress.
	for id in data.get("cleared_ids", []):
		var k := Sites.index_of(String(id))
		if k >= 0:
			cleared[k] = true
	# Currency: v3 stores coin/star; a v2 save held a 4-bank [ferrite,cryo,lumen,crystal].
	if data.has("bank") and data.bank is Array and data.bank.size() == 4:
		var ob: Array = data.bank
		coin = int(ob[0]) + int(ob[1]) + int(ob[2])
	else:
		coin = int(data.get("coin", 0))
	# v4: Star is one per cleared dig and nothing else, so it is rebuilt from progress (older
	# saves also counted crystals)
	star = cleared.count(true) * Economy.FIRST_CLEAR_STARS
	unlocked = 1
	for i in cleared.size():
		if cleared[i]:
			unlocked = maxi(unlocked, mini(Sites.count(), i + 2))
	sfx_on = bool(data.get("sfx_on", true))
	music_on = bool(data.get("music_on", true))
	path_max = int(data.get("path_max", 4))
	show_fps = bool(data.get("show_fps", false))
	dev_mode = bool(data.get("dev_mode", false))
	tips_seen = data.get("tips_seen", {})
	treasure_dry = int(data.get("treasure_dry", 0))
	var t: Dictionary = data.get("totals", {})
	for k in t:
		totals[k] = int(t[k])
	dig_log = data.get("dig_log", [])
	# a save from before the colony map has no counter: treat what it already has as celebrated
	milestones_seen = clampi(int(data.get("milestones_seen", milestones_reached())), 0, milestones_reached())
	reminders = []
	for r in data.get("reminders", []):
		if r is Array and r.size() == 2 and int(r[0]) >= 0 and int(r[0]) < Economy.BUILDINGS.size() and int(r[1]) >= 1 and int(r[1]) <= Economy.MAX_LEVEL:
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


## Does this dig hide a treasure chest? Rare, but every dig without one makes the next more
## likely (bad-luck protection), and finding one resets it.
func roll_treasure(rng: RandomNumberGenerator) -> bool:
	var hit := rng.randf() < Economy.treasure_chance(treasure_dry)
	treasure_dry = 0 if hit else treasure_dry + 1
	return hit
