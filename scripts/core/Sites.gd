class_name Sites
extends RefCounted

## The campaign: digs in play order, one after the other. Players never see a site list or
## site names; they press "Dig" in the colony and get the next one. The order follows the
## master sheet in docs/design/level-plan.md: chapters of 10 whose difficulty climbs step by step
## up to a reward dig, a building unlocked at the end of each chapter and that
## building's own hand-made dig right after it. Digs with an "ore" layout are always the same;
## the others keep their shape and goals but get fresh ore every attempt.
## Mira's script is said the first time a dig is played and never repeated.
## Terrain codes: see Board._parse_cell(). Rows are 7 cells wide, 8 rows tall. Optional keys:
##   "ore":    hand-placed tokens (see Board._place_layout); the opening is always the same
##   "seed":   fixed seed, so what surfaces after each match is always the same
##   "energy": starting energy (below the battery capacity)
##   "guide":  hand-made lesson (fixed layout); its intended solution is replayed by the tests
##   "needs":  colony building level required before this dig can start
##   "unlock": building that becomes available once this dig is cleared; Mira then asks you
##             to build it (level 1 is free) and points you at DIG
##   "building_level": the hand-made dig right after a building: it needs the new tool to
##             finish, but mixes it with matching, rock and energy like any other dig
##   "script": what Mira says. A line without "until" waits for a tap; a line with "until"
##             stays up while you play and moves on when that event happens (see DigScreen).
##             "focus" cells pulse on the board. "guide" (cells from the robot on): a
##             hand draws that move, the board dims around it, and only it is accepted.
##   "path_max": the longest drawn path this dig allows (a lesson before paths: 1)
##   "explains": specials its script teaches (["pulsar"]), so Mira's passing note is skipped

## Levels 1..JOURNEY_BUILT are rebuilt as the journey (docs/design/journey.md); the rest keep
## their old design. A journey level clears its board: every obstacle on it is a goal, all of it.
const JOURNEY_BUILT := 10
const LIST := [
	# --- Chapter 1 · Landing (docs/design/journey.md) -------------------------------------
	# L1: draw a path, and the first obstacle. Paths are the game, so the very first move is
	# one: the hand draws three steps that make two lines, one along the rock floor, which
	# cracks (Royal Match also meets its first obstacle, the Box, on level 1). The rock stands
	# on the floor and in the corners, so the gems always refill.
	{
		"id": "first", "mode": "fall", "colours": 3, "guide": true, "seed": 382, "energy": 20,
		"goals": [{"type": "rock", "n": 15}],
		"rows": [
			"1 . . . . . 1",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			". . @ . . . .",
			"1 . . . . . 1",
			"1 1 . . . 1 1",
			"1 1 1 1 1 1 1",
		],
		"ore": [
			"- F C F L C -",
			"L F L F F C C",
			"L C C L C F L",
			"C C F C C L C",
			"L F F L L C L",
			"C L - F L F L",
			"- C F L C C -",
			"- - F C C - -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Hi, I'm Mira! Hold anywhere and draw: the robot swaps with every gem on its way, and the whole path is one move.",
					"until": "match", "guide": [Vector2i(2, 5), Vector2i(2, 6), Vector2i(3, 6), Vector2i(3, 7)],
					"focus": [Vector2i(2, 3), Vector2i(2, 4), Vector2i(4, 6), Vector2i(5, 6)]},
			{"say": "A match right next to rock cracks it. Break all 15 rocks!", "until": "move"},
		],
	},
	# L2 "bastions": four rock bastions stand in the corners, stepped like stairs; the gems hold
	# a plus of open ground between them. Beams fired from the middle reach every corner.
	{
		"id": "arches", "mode": "fall", "colours": 4, "tier": "intro", "energy": 26,
		"goals": [{"type": "rock", "n": 24}],
		"tip": ["pulsar", "4 in a row makes a Pulsar. Swap with it: twin beams fire both ways, through rock."],
		"rows": [
			"1 1 1 . . . 1 1 1",
			"1 1 . . . . . 1 1",
			"1 . . . . . . . 1",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			"1 . . . . . . . 1",
			"1 1 . . . . . 1 1",
			"1 1 1 . . . 1 1 1",
		],
	},



	# L3 "pillars": two rock pillars on wide plinths, with thick capitals (the chapter's variant);
	# the gems work the aisle between them and the lanes outside. Mira points at a capital.
	{
		"id": "layers", "mode": "fall", "colours": 4, "tier": "intro", "energy": 26,
		"goals": [{"type": "rock", "n": 30}],
		"script": [
			{"say": "Darker rock is thicker: it cracks on the first match and breaks on the second.", "until": "move",
					"focus": [Vector2i(2, 1), Vector2i(6, 1)]},
		],
		"rows": [
			". . . . . . . . .",
			". . 2 . . . 2 . .",
			". . 1 . . . 1 . .",
			". . 1 . @ . 1 . .",
			". 1 1 . . . 1 1 .",
			". 1 1 . . . 1 1 .",
			"1 1 1 . . . 1 1 1",
			"1 1 1 . . . 1 1 1",
			"# 1 1 . . . 1 1 #",
		],
	},


	# L4 "spine": a crowned spine of rock splits the board into two wings; pockets of rock wait
	# in the bottom corners. Break the spine to join the wings; a Scout drone reaches the crown.
	{
		"id": "spine", "mode": "fall", "colours": 4, "tier": "intro", "energy": 24,
		"goals": [{"type": "rock", "n": 24}],
		"tip": ["drone", "A 2x2 square makes a Scout drone. It flies to what helps you most."],
		"rows": [
			". . . 1 1 1 . . .",
			". . . . 1 . . . .",
			". . . . 1 . . . .",
			"1 . . . 1 . . . 1",
			"1 1 . . 1 . . 1 1",
			"1 1 . . 1 . . 1 1",
			"1 1 . . . . . 1 1",
			"1 . . . @ . . . 1",
			"# # . . . . . # #",
		],
	},


	# L5 "valley": the rock steps down from both sides into a V, thicker the deeper; the gems
	# pour down the middle. Dig the steps from the top, the thick floor last.
	{
		"id": "strata1", "mode": "fall", "colours": 4, "tier": "normal", "energy": 28,
		"goals": [{"type": "rock", "n": 38}],
		"tip": ["nova", "An L or a T makes a Nova: a big blast all around it."],
		"rows": [
			". . . . @ . . . .",
			". . . . . . . . .",
			"1 . . . . . . . 1",
			"1 1 . . . . . 1 1",
			"2 1 1 . . . 1 1 2",
			"2 2 1 1 . 1 1 2 2",
			"2 2 2 1 . 1 2 2 2",
			"# 2 2 2 . 2 2 2 #",
			"# # 2 2 . 2 2 # #",
		],
	},


	# L6: cave webs, the chapter's new element (Royal Match meets grass on level 4): a floor
	# layer under the gems, cleared by a match on top of it. A diamond board, a diamond of webs.
	{
		"id": "webs1", "mode": "fall", "colours": 4, "tier": "intro", "energy": 20,
		"goals": [{"type": "web", "n": 13}],
		"obstacles": [[Vector2i(4, 2), "web"], [Vector2i(3, 3), "web"], [Vector2i(4, 3), "web"], [Vector2i(5, 3), "web"], [Vector2i(2, 4), "web"], [Vector2i(3, 4), "web"], [Vector2i(4, 4), "web"], [Vector2i(5, 4), "web"], [Vector2i(6, 4), "web"], [Vector2i(3, 5), "web"], [Vector2i(4, 5), "web"], [Vector2i(5, 5), "web"], [Vector2i(4, 6), "web"]],
		"rows": [
			"# # . . . . . # #",
			"# . . . . . . . #",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"# . . . @ . . . #",
			"# # . . . . . # #",
		],
		"script": [
			{"say": "Cave webs! Make a match on top of a web to clear it.", "until": "match",
					"focus": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]},
		],
	},
	# L7 "chessboard": an octagon; below the open top, a chessboard of rock lies over a web
	# garden (Royal Match hides grass under boxes). Every rock broken shows a web; match on it.
	{
		"id": "silk", "mode": "fall", "colours": 4, "tier": "intro", "energy": 30,
		"goals": [{"type": "web", "n": 43}, {"type": "rock", "n": 21}],
		"obstacles": [[Vector2i(0, 4), "web"], [Vector2i(1, 4), "web"], [Vector2i(2, 4), "web"], [Vector2i(3, 4), "web"], [Vector2i(4, 4), "web"], [Vector2i(5, 4), "web"], [Vector2i(6, 4), "web"], [Vector2i(7, 4), "web"], [Vector2i(8, 4), "web"], [Vector2i(0, 5), "web"], [Vector2i(1, 5), "web"], [Vector2i(2, 5), "web"], [Vector2i(3, 5), "web"], [Vector2i(4, 5), "web"], [Vector2i(5, 5), "web"], [Vector2i(6, 5), "web"], [Vector2i(7, 5), "web"], [Vector2i(8, 5), "web"], [Vector2i(0, 6), "web"], [Vector2i(1, 6), "web"], [Vector2i(2, 6), "web"], [Vector2i(3, 6), "web"], [Vector2i(4, 6), "web"], [Vector2i(5, 6), "web"], [Vector2i(6, 6), "web"], [Vector2i(7, 6), "web"], [Vector2i(8, 6), "web"], [Vector2i(0, 7), "web"], [Vector2i(1, 7), "web"], [Vector2i(2, 7), "web"], [Vector2i(3, 7), "web"], [Vector2i(4, 7), "web"], [Vector2i(5, 7), "web"], [Vector2i(6, 7), "web"], [Vector2i(7, 7), "web"], [Vector2i(8, 7), "web"], [Vector2i(1, 8), "web"], [Vector2i(2, 8), "web"], [Vector2i(3, 8), "web"], [Vector2i(4, 8), "web"], [Vector2i(5, 8), "web"], [Vector2i(6, 8), "web"], [Vector2i(7, 8), "web"]],
		"rows": [
			"# . . . . . . . #",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			"1 . 1 . 1 . 1 . 1",
			". 1 . 1 . 1 . 1 .",
			"1 . 1 . 1 . 1 . 1",
			". 1 . 1 . 1 . 1 .",
			"# . 1 . 1 . 1 . #",
		],
	},




	# L8 "crystal vaults": crystals wait in the two bottom-corner pockets and under a thick
	# dome in the middle. The goal card's tip: path combos.
	{
		"id": "glint1", "mode": "fall", "colours": 4, "tier": "intro", "energy": 24,
		"goals": [{"type": "crystal", "n": 3}, {"type": "rock", "n": 29}],
		"tip": ["pulsar", "nova", "Draw a path through two power-ups: they merge into one big combo."],
		"script": [
			{"say": "Crystals at the bottom of the rock! Dig down, then draw the robot over a crystal to grab it.", "until": "crystal",
					"focus": [Vector2i(0, 8), Vector2i(4, 8), Vector2i(8, 8)]},
		],
		"rows": [
			"# # . . @ . . # #",
			"# . . . . . . . #",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"1 1 . . . . . 1 1",
			"1 1 1 . 2 . 1 1 1",
			"1 1 1 2 2 2 1 1 1",
			"1c 1 1 2 2c 2 1 1 1c",
		],
	},

	# L9: the chapter's small peak (two goal types). Idea: an hourglass; the webs are up top,
	# beyond a narrow waist, and a rock band guards the bottom. Clear a way up through the
	# waist, then send power-ups through it.
	{
		"id": "hourglass", "mode": "fall", "colours": 4, "tier": "normal", "energy": 26,
		"goals": [{"type": "web", "n": 18}, {"type": "rock", "n": 4}],
		"tip": ["drone", "pulsar", "A drone carrying a Pulsar flies to the best line and fires it there."],
		"obstacles": [[Vector2i(0, 0), "web"], [Vector2i(1, 0), "web"], [Vector2i(2, 0), "web"], [Vector2i(3, 0), "web"], [Vector2i(4, 0), "web"], [Vector2i(5, 0), "web"], [Vector2i(6, 0), "web"], [Vector2i(7, 0), "web"], [Vector2i(8, 0), "web"], [Vector2i(0, 1), "web"], [Vector2i(1, 1), "web"], [Vector2i(2, 1), "web"], [Vector2i(3, 1), "web"], [Vector2i(4, 1), "web"], [Vector2i(5, 1), "web"], [Vector2i(6, 1), "web"], [Vector2i(7, 1), "web"], [Vector2i(8, 1), "web"]],
		"rows": [
			". . . . . . . . .",
			". . . . . . . . .",
			"# . . . . . . . #",
			"# # . . . . . # #",
			"# # # . . . # # #",
			"# # . . . . . # #",
			"# 2 . . . . . 2 #",
			"2 . . . . . . . 2",
			". . . . @ . . . .",
			". . . . . . . . .",
		],
	},
	# L10: the chapter's reward, a show level (Royal Match floods a board with its element): a
	# plus-shaped board, thick webs everywhere and power-ups already waiting.
	{
		"id": "starfall", "mode": "fall", "colours": 4, "tier": "reward", "energy": 22,
		"goals": [{"type": "web", "n": 54}],
		"tip": ["blackhole", "5 in a row makes a Black hole: it swallows the colour of the gem you bring it in with."],
		"specials": [[Vector2i(2, 4), "pulsar"], [Vector2i(6, 4), "pulsar"], [Vector2i(4, 2), "nova"]],
		"obstacles": [[Vector2i(2, 1), "web", 2], [Vector2i(3, 1), "web", 2], [Vector2i(4, 1), "web", 2], [Vector2i(5, 1), "web", 2], [Vector2i(6, 1), "web", 2], [Vector2i(0, 2), "web", 2], [Vector2i(1, 2), "web", 2], [Vector2i(2, 2), "web", 2], [Vector2i(3, 2), "web", 2], [Vector2i(4, 2), "web", 2], [Vector2i(5, 2), "web", 2], [Vector2i(6, 2), "web", 2], [Vector2i(7, 2), "web", 2], [Vector2i(8, 2), "web", 2], [Vector2i(0, 3), "web", 2], [Vector2i(1, 3), "web", 2], [Vector2i(2, 3), "web", 2], [Vector2i(3, 3), "web", 2], [Vector2i(4, 3), "web", 2], [Vector2i(5, 3), "web", 2], [Vector2i(6, 3), "web", 2], [Vector2i(7, 3), "web", 2], [Vector2i(8, 3), "web", 2], [Vector2i(0, 4), "web", 2], [Vector2i(1, 4), "web", 2], [Vector2i(2, 4), "web", 2], [Vector2i(3, 4), "web", 2], [Vector2i(4, 4), "web", 2], [Vector2i(5, 4), "web", 2], [Vector2i(6, 4), "web", 2], [Vector2i(7, 4), "web", 2], [Vector2i(8, 4), "web", 2], [Vector2i(0, 5), "web", 2], [Vector2i(1, 5), "web", 2], [Vector2i(2, 5), "web", 2], [Vector2i(3, 5), "web", 2], [Vector2i(4, 5), "web", 2], [Vector2i(5, 5), "web", 2], [Vector2i(6, 5), "web", 2], [Vector2i(7, 5), "web", 2], [Vector2i(8, 5), "web", 2], [Vector2i(0, 6), "web", 2], [Vector2i(1, 6), "web", 2], [Vector2i(2, 6), "web", 2], [Vector2i(3, 6), "web", 2], [Vector2i(5, 6), "web", 2], [Vector2i(6, 6), "web", 2], [Vector2i(7, 6), "web", 2], [Vector2i(8, 6), "web", 2], [Vector2i(2, 7), "web", 2], [Vector2i(3, 7), "web", 2], [Vector2i(4, 7), "web", 2], [Vector2i(5, 7), "web", 2], [Vector2i(6, 7), "web", 2]],
		"rows": [
			"# # . . . . . # #",
			"# # . . . . . # #",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . @ . . . .",
			"# # . . . . . # #",
			"# # . . . . . # #",
		],
	},

	{
		# the Bomb lesson (GDD v4, iteration 1): the Power Station has just handed out a free Bomb.
		# Rubble clumps 2x2 are slow to crack with matches (only their outer cells touch open
		# ground), a Bomb on a clump breaks all four at once
		"id": "quarry", "mode": "fall", "colours": 4, "tier": "normal", "energy": 36,
		"goals": [{"type": "rock", "n": 10}],
		"rows": [
			". . . . . . .",
			". 1 1 . 1 1 .",
			". 1 1 . 1 1 .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . 1 1 1 . .",
			"# . . . . . #",
		],
	},
	{
		# gold rush: a bonus dig with no fail. Chests everywhere; open as many as the moves
		# allow, every chest is Coin. Announced by its own card and banner (DigScreen).
		"id": "rush1", "mode": "fall", "colours": 4, "gold_rush": true, "energy": 14,
		"goals": [{"type": "treasure", "n": 10}],
		"rows": [
			". . . . . . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
			"1t . . . . . 1t",
			". . 1t @ 1t . .",
			". . . . . . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
		],
	},
	{
		# a rubble zig-zag on scarce ground; with falling gems (iteration 1) its old hand-made
		# opening no longer applies, so it rolls fresh gems like any other dig
		"id": "zigzag", "mode": "fall", "colours": 4, "tier": "normal", "energy": 24,
		"goals": [{"type": "rock", "n": 11}],
		"rows": [
			"# # # # # # #",
			": _ : 1 : _ :",
			"1 1 : 1 : 1 1",
			": 1 : : : 1 :",
			": 1 1 : 1 1 :",
			"_ : 1 @ 1 : _",
			"# : : _ : : #",
			"# # # # # # #",
		],
	},
	{
		# the cell lesson (falling gems): 9 moves for 20 Ferrite is not enough, the buried cell's 6
		# more moves are (the solver's route takes 13). It starts on a full budget: opening
		# on a half-empty one read as moves taken away.
		"id": "battery", "mode": "fall", "colours": 4, "guide": true, "seed": 5, "energy": 9,
		"goals": [{"type": "ore", "ore": 0, "n": 20}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# . . 1e . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- C L - F C -",
			"- C F - F F -",
			"- F L C L C -",
			"- C C L F L -",
			"- L F C C F -",
			"- - - - - - -",
		],
		"script": [
			{"say": "20 Ferrite in 9 moves is too tight. But there's an energy cell buried in that rock: it's worth 6 more moves."},
			{"say": "Make a match right next to that rock to crack it open.", "until": "reveal", "focus": [Vector2i(3, 2)]},
			{"say": "There's the cell! Drive onto it for 6 more moves.", "until": "cell"},
		],
	},
	{
		# energy cells, practised: shallow ground runs dry fast, and the cells sit under rubble, so
		# cracking the right rock first buys the moves to finish
		"id": "cellar", "mode": "fall", "colours": 4, "tier": "normal", "energy": 14,
		"goals": [{"type": "chunks", "n": 48}],
		"rows": [
			": : : : : : :",
			": 1e : 1 : 1e :",
			": : : : : : :",
			". . . @ . . .",
			": : : : : : :",
			": 1 : 1e : 1 :",
			": : : : : : :",
			"# : : : : : #",
		],
	},
	{
		# a variation, not a new mechanic: 2-layer rock (a match cracks one layer, so each needs two)
		"id": "boulders", "mode": "fall", "colours": 4, "tier": "normal", "energy": 21,
		"goals": [{"type": "rock", "n": 5}, {"type": "chunks", "n": 18}],
		"rows": [
			". . . . . . .",
			". 2 . . . 2 .",
			". . . 2 . . .",
			". . . @ . . .",
			". 2 . . . 2 .",
			". . . . . . .",
			". . 2 . 2 . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Some rocks here are tougher: two layers. A match next to one only cracks a layer, so hit it twice."},
		],
	},
	{
		# three rooms, each closed by a rock gate; every room is a small puzzle (a pair next to
		# the gate, the third gem one row away: walk over and step onto it), the crystal is in
		# the rock in the top-left corner. The intended route takes 23 moves; 25 leaves room for
		# two wasted moves. (v4: it no longer teaches the Power Station, whose +moves are gone;
		# the Bomb lesson replaces it when the levels are redone.)
		"id": "longhaul", "building_level": true, "seed": 31, "energy": 25,
		"goals": [{"type": "crystal", "n": 1}],
		"needs": {"building": 0, "level": 1},
		"rows": [
			"1c . . . . . .",
			". . . . . . .",
			"# # # # # 1 #",
			". . . . . . .",
			". . . . . . .",
			"# 1 # # # # #",
			". . . . . @ .",
			". . . . . . .",
		],
		"ore": [
			"- C L F C F C",
			"L L F C F C F",
			"- - - - - - -",
			"L F L F L C C",
			"C C F L C F L",
			"- - - - - - -",
			"F F C L C - L",
			"C L F C L C F",
		],
		"script": [
			{"say": "The crystal is in the top room, behind two rock gates. Each room hides a match that cracks its gate."},
			{"say": "Two Ferrite sit by the gate. Walk over and step down onto the third.", "until": "reveal", "focus": [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 7)]},
			{"say": "Gate's open. Same trick in every room: find the pair next to the gate.", "until": "crystal"},
		],
	},
	{
		"id": "charge", "guide": true, "seed": 9, "energy": 14,
		"goals": [{"type": "blast", "n": 2}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# 1 1 1 1 1 #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C L F C L -",
			"- F F - F C -",
			"- L C L L F -",
			"- C L C F C -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Line up 4 at once and the robot leaves a blast charge behind."},
			{"say": "Swipe up: that lines up 4 Ferrite.", "until": "charge", "focus": [Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 4)]},
			{"say": "There's the charge. Step onto it to set it off!", "until": "blast", "focus": [Vector2i(3, 4)]},
			{"say": "Boom! A blast clears everything around it, rock too. Make another line of 4 and set off one more."},
		],
	},
	{
		"id": "checker", "tier": "hard", "energy": 21,
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			". . . . . . .",
			". 1 . 2c . 1 .",
			". . . . . . .",
			". 1e . 1 . 1e .",
			". . . @ . . .",
			". 1 . 2c . 1 .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "route", "tier": "normal", "energy": 37,
		"goals": [{"type": "crystal", "n": 2}, {"type": "chunks", "n": 27}],
		"rows": [
			"1 . 1c 1 1c . 1",
			". . . . . . .",
			"# . . . . . #",
			"# # . . . # #",
			"# # . @ . # #",
			"# # . . . # #",
			"# # . . . # #",
			"# # # # # # #",
		],
	},
	{
		"id": "deep", "tier": "normal", "energy": 31,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 42}],
		"rows": [
			"o : : : : : o",
			": o : : : o :",
			": : o 1c o : :",
			": : : @ : : :",
			": : o : o : :",
			": o : : : o :",
			"o : : : : : o",
			"# : : : : : #",
		],
	},
	{
		"id": "rush2", "gold_rush": true, "energy": 16,
		"goals": [{"type": "treasure", "n": 12}],
		"rows": [
			"1t . . 1t . . 1t",
			". . . . . . .",
			". 1t . . . 1t .",
			". . 1t . 1t . .",
			"1t . . @ . . 1t",
			". . 1t . 1t . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
		],
	},
	{
		"id": "shallows", "tier": "superhard", "energy": 19,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			": : : : : : :",
			"1c : : : : : 1c",
			": : 1e : 1e : :",
			": : : @ : : :",
			": : : : : : :",
			": : 1e : 1e : :",
			": : : 1c : : :",
			"# : : : : : #",
		],
	},
	{
		"id": "well", "tier": "breather", "energy": 24,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 12}],
		"rows": [
			"# . . . . . #",
			"# . . @ . . #",
			"# 1 . . . 1 #",
			"# . 1 . 1 . #",
			"# 1 . . . 1 #",
			"# . 1 . 1 . #",
			"# . . 1e . . #",
			"# # . 1c . # #",
		],
	},
	{
		"id": "garden", "tier": "reward", "energy": 41, "unlock": 1,
		"goals": [{"type": "crystal", "n": 4}],
		"rows": [
			". . 1c . 1c . .",
			". o . . . o .",
			". . . . . . .",
			"1c . . @ . . 1c",
			". . . . . . .",
			". o . . . o .",
			". . 1e . 1e . .",
			"# . . . . . #",
		],
	},
	{
		"id": "vaults", "building_level": true, "seed": 32, "energy": 42,
		"goals": [{"type": "crystal", "n": 2}],
		"needs": {"building": 1, "level": 1},
		"rows": [
			"3c # . . . # 3c",
			"_ # . . . # _",
			". . . . . . .",
			". . 2 . 2 . .",
			". . . . . . .",
			". . . . . . .",
			"1e . . . . . 1e",
			"# . . @ . . #",
		],
		"ore": [
			"- - L F L - -",
			"- - L L C - -",
			"F C C L C F C",
			"C F - F - F C",
			"C F C C L L F",
			"F C F F C L F",
			"- C C L F C -",
			"- F L - L C -",
		],
		"script": [
			{"say": "Two crystals, sealed in basalt vaults three layers thick. Matches barely scratch them."},
			{"say": "But now you have a drill! Stand in a vault's doorway and swipe up into the rock."},
			{"say": "Get to a doorway and swipe up into the basalt.", "until": "drill", "focus": [Vector2i(0, 1), Vector2i(6, 1)]},
			{"say": "Each bump knocks off a layer for 2 energy. Keep drilling, then grab the crystal.", "until": "crystal", "focus": [Vector2i(0, 0), Vector2i(6, 0)]},
			{"say": "One more vault. The corners hide energy cells, so grab one if the battery runs low.", "until": "crystal", "focus": [Vector2i(0, 0), Vector2i(6, 0)]},
		],
	},
	{
		"id": "stone", "tier": "normal", "energy": 34,
		"goals": [{"type": "rock", "n": 6}],
		"rows": [
			"# # # # # # #",
			". . 2 . 2 . .",
			". . . . . . .",
			". 2 . @ . 2 .",
			". . . . . . .",
			". . 2 . 2 . .",
			". . . . . . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Stone has 2 layers: one match only chips it. Crack it twice, drill it, or blast it.", "focus": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(5, 1)]},
		],
	},
	{
		"id": "seam", "tier": "normal", "colours": 4, "energy": 26,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"o o o o o o o",
			". . . . . . .",
			": : : : : : :",
			". . . @ . . .",
			"o o o o o o o",
			". . . . . . .",
			": : : : : : :",
			"# . . . . . #",
		],
	},
	{
		"id": "rubble", "tier": "hard", "energy": 18,
		"goals": [{"type": "rock", "n": 14}],
		"rows": [
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			"1 1e 1 1 1 1e 1",
			"1 1 1e 1 1e 1 1",
			". . . . . . .",
			". . 1 1 1 . .",
			"# . . . . . #",
		],
	},
	{
		"id": "strata", "tier": "normal", "energy": 48,
		"goals": [{"type": "rock", "n": 10}],
		"rows": [
			"o . 2 . 2 . o",
			". 2 . . . 2 .",
			"2 . o . o . 2",
			". . . @ . . .",
			"2 . o . o . 2",
			". 2 . . . 2 .",
			"o . 2 . 2 . o",
			"# . . . . . #",
		],
	},
	{
		"id": "pockets", "tier": "normal", "energy": 36,
		"goals": [{"type": "crystal", "n": 4}],
		"rows": [
			". . 2c . 2c . .",
			". . . . . . .",
			". 1e . . . 1e .",
			". . . @ . . .",
			". . . . . . .",
			". 2c . . . 2c .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "maze", "tier": "normal", "energy": 24,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			"# # # # # # #",
			". . 2 . 2 . .",
			". 1c . . . 1c .",
			". . . @ . . .",
			". 2 . 1e . 2 .",
			". . . 2 . . .",
			". . 1c . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "shale", "tier": "superhard", "colours": 4, "energy": 28,
		"goals": [{"type": "ore", "ore": 1, "n": 8}, {"type": "crystal", "n": 1}],
		"rows": [
			": : : : : : :",
			": : : @ : : :",
			": : : : : : :",
			"2 1e 2 2 2 1e 2",
			". . . . . . .",
			". . . . . . .",
			"2 2 3 1c 3 2 2",
			"# 3 3 3 3 3 #",
		],
	},
	{
		"id": "core", "tier": "breather", "energy": 23,
		"goals": [{"type": "crystal", "n": 2}, {"type": "chunks", "n": 15}],
		"needs": {"building": 1, "level": 1},
		"rows": [
			"# # # # # # #",
			"o . . . . . o",
			". 2 2 2 2 2 .",
			". 2 2c 1e 2c 2 .",
			". . . @ . . .",
			". 2 2 2 2 2 .",
			"o . . . . . o",
			"# . . . . . #",
		],
	},
	{
		"id": "openseam", "tier": "reward", "energy": 28, "unlock": 2,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"2 o 2 . 2 o 2",
			"2 o 1 . 1 o 2",
			"1 . . @ . . 1",
			"2e . . . . . 2e",
			"1 . . . . . 1",
			"2 o 1 . 1 o 2",
			"2 o 2 . 2 o 2",
			"# 3 3e 3 3 3 #",
		],
	},
	{
		"id": "readings", "building_level": true, "seed": 33, "energy": 34,
		"goals": [{"type": "crystal", "n": 2}],
		"needs": {"building": 2, "level": 1},
		"rows": [
			". 2x . 2x . 2c .",
			". . . . . . .",
			"2x . 2e . 2x . 2x",
			". . . . . . .",
			". 2c . 2x . 2e .",
			". . . . . . .",
			". . . . . . .",
			". . . @ . . .",
		],
		"ore": [
			"C - L - L - F",
			"C F C L C L F",
			"- L - C - C -",
			"F F L C L C L",
			"L - C - F - C",
			"C L F C L L C",
			"L F F C F L F",
			"L C L - L F L",
		],
		"script": [
			{"say": "The lab's scanner is on: the icons on each rock show what's buried inside."},
			{"say": "Ten rocks, two crystals, and a small battery. Don't waste energy on empty rock."},
			{"say": "Find the rocks with a crystal icon, then drill or crack them open.", "until": "crystal", "focus": [Vector2i(5, 0), Vector2i(1, 4)]},
			{"say": "One more! The green battery icons are energy cells, if you run low.", "until": "crystal", "focus": [Vector2i(5, 0), Vector2i(1, 4)]},
		],
	},
]

static func count() -> int:
	return LIST.size()


static func get_site(i: int) -> Dictionary:
	if i >= LIST.size() and i - LIST.size() < protos().size():
		return protos()[i - LIST.size()]
	return LIST[clampi(i, 0, LIST.size() - 1)]


# --- prototypes ------------------------------------------------------------------------
## Movement prototypes (Settings > Prototypes), to find the fun in drawn paths plus board
## elements that move things. They sit after the campaign (index count() + k), never count
## as progress and pay nothing. All are falling-gem digs on Royal Match sized boards (9 wide);
## each has one idea, said on its goal card.
##   pads:     [[pad, target]]: a special, crystal or cell resting on the pad flies to the
##             target (a special goes off there); the dotted arc shows where
##   belts:    [[cell, ...]]: after every move it runs one step, plus one per gem matched on it
##             (Board._turn_end); what leaves the last cell comes back on the first. A belt
##             whose ends do not touch is also a shelf (nothing falls through it)
##   teleports: [[a, b]]: a move or path that ends on one puts the robot on the twin; a special
##             pushed or dropped onto one goes off at the twin
##   specials: [[cell, kind]]: gems that start out carrying a special
##   collect:  crystals and cells are collected at the bottom of their run
##   obstacles: [[top-left cell, kind]]: generators, cages... (Obstacles.KINDS)
##   cores:    [cell]: energy cores to deliver; docks: [cell] where they are delivered
const PROTOS := [
	{"name": "Launch bay", "energy": 20, "collect": true,
		"idea": "The vault is sealed. The launch pad throws power-ups into it: clear the gems under the Nova and let it drop onto the pad.",
		"goals": [{"type": "crystal", "n": 2}, {"type": "rock", "n": 10}],
		"pads": [[Vector2i(4, 9), Vector2i(4, 1)]],
		"specials": [[Vector2i(4, 7), "nova"]],
		"rows": [
			"# # 1 1 1 1 1 # #",
			"# # 1c 1 . 1 1c # #",
			"# # 1 1 1 1 1 # #",
			"# # # # # # # # #",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"# . . . . . . . #",
		]},
	{"name": "Conveyor ring", "energy": 20, "collect": true,
		"idea": "The belt turns one step after every move, carrying gems round the rock core. Draw paths that leave lines for the belt to finish.",
		"goals": [{"type": "rock", "n": 9}, {"type": "crystal", "n": 1}],
		"belts": [[Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 3),
			Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6),
			Vector2i(2, 6), Vector2i(2, 5), Vector2i(2, 4), Vector2i(2, 3)]],
		"rows": [
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . 2 2 2 . . .",
			". . . 2 2c 2 . . .",
			". . . 2 2 2 . . .",
			". . . . . . . . .",
			". . . . @ . . . .",
			"# . . . . . . . #",
		]},
	{"name": "Teleporters", "energy": 22, "collect": true,
		"idea": "A wall splits the board. End a path on a teleporter and the robot comes out of its twin; push a power-up onto one and it goes off at the twin.",
		"goals": [{"type": "crystal", "n": 3}, {"type": "rock", "n": 9}],
		"teleports": [[Vector2i(2, 7), Vector2i(6, 7)], [Vector2i(1, 2), Vector2i(7, 5)]],
		"specials": [[Vector2i(2, 6), "pulsar"]],
		"rows": [
			". . . . # . . . .",
			". . . . # . 1c . .",
			". . . . # . . . .",
			". . . . # 1 1 1 1",
			". . @ . # . . . .",
			". . . . # . . . .",
			". . . . # 2 . . 2",
			". . . . # . . . .",
			". . . . # . 1c . 1c",
			". . . . # . . . .",
		]},
	{"name": "Express belt", "energy": 20, "collect": true,
		"idea": "The belt runs into the launch pad: a step after every move, one more for every gem you match on it. What leaves the end comes back at the start. Speed the Nova to the pad.",
		"goals": [{"type": "crystal", "n": 2}, {"type": "rock", "n": 10}],
		"pads": [[Vector2i(8, 9), Vector2i(4, 1)]],
		"belts": [[Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9),
			Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9)]],
		"specials": [[Vector2i(2, 9), "nova"]],
		"rows": [
			"# # 1 1 1 1 1 # #",
			"# # 1c 1 . 1 1c # #",
			"# # 1 1 1 1 1 # #",
			"# # # # # # # # #",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		]},
	{"name": "Shelf belt", "energy": 30, "collect": true,
		"idea": "A belt runs across the middle into a launch pad. Match under the Nova to drop it onto the belt, then speed it to the pad with matches on the belt.",
		"goals": [{"type": "crystal", "n": 2}, {"type": "rock", "n": 10}],
		"pads": [[Vector2i(5, 6), Vector2i(4, 1)]],
		"belts": [[Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6)]],
		"specials": [[Vector2i(2, 5), "nova"]],
		"rows": [
			"# # 1 1 1 1 1 # #",
			"# # 1c 1 . 1 1c # #",
			"# # 1 1 1 1 1 # #",
			"# # # # # # # # #",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . @ . . . . .",
			"# . . . . . . . #",
		]},
	{"name": "Big dig", "energy": 20, "collect": true,
		"idea": "A big board, no tricks: dig down through the layers with long paths and big combos. The crystals wait at the bottom.",
		"goals": [{"type": "rock", "n": 20}, {"type": "crystal", "n": 3}],
		"specials": [[Vector2i(4, 2), "pulsar"]],
		"rows": [
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			"1 1 1 . . . 1 1 1",
			". . . . . . . . .",
			". . 2 2 . 2 2 . .",
			". . . . . . . . .",
			"1 1 . . . . . 1 1",
			". . . 2 2 2 . . .",
			"1c . . . 1c . . . 1c",
		]},
	# --- obstacles (Obstacles.KINDS): modern match-3 goals beyond "collect" ---------------
	{"name": "Power grid", "energy": 20,
		"idea": "Activate: matches next to a generator charge it. Charge all three to switch them on. Power-ups charge them too.",
		"goals": [{"type": "generator", "n": 3}],
		"obstacles": [[Vector2i(1, 1), "generator"], [Vector2i(6, 1), "generator"], [Vector2i(3, 6), "generator"]],
		"rows": [
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"1 1 . . . . . 1 1",
			". . . . @ . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"# . . . . . . . #",
		]},
	{"name": "Core run", "energy": 20,
		"idea": "Deliver: bring both energy cores down onto the docks. Cages lock their gems and hold up the columns: match a caged gem or hit it with a power-up to break it, or push a core around them with the robot.",
		"goals": [{"type": "core", "n": 2}],
		"cores": [Vector2i(2, 0), Vector2i(6, 0)],
		"docks": [Vector2i(2, 9), Vector2i(6, 9)],
		"obstacles": [[Vector2i(1, 4), "cage"], [Vector2i(2, 4), "cage"], [Vector2i(3, 4), "cage"],
			[Vector2i(5, 4), "cage"], [Vector2i(6, 4), "cage"], [Vector2i(7, 4), "cage"]],
		"rows": [
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"# . . . . . . . #",
		]},
]

## Budgets (drawn paths, 4 steps). Set by hand for the first playtest: the path bot clears
## Conveyor ring in ~7 moves (14 with the human margin), but cannot plan pad shots well enough
## to rate Launch bay (40% at 60 moves), so the others are guesses to calibrate. Power grid and
## Core run: the path bot clears 75% / 93% at 20 moves (93% / 100% at 30).
const PROTO_ENERGY := [30, 14, 22, 30, 30, 22, 26, 22]

static var _protos: Array = []


static func protos() -> Array:
	if _protos.is_empty():
		for k in PROTOS.size():
			var site: Dictionary = PROTOS[k].duplicate(true)
			site.id = "proto_%d" % (k + 1)
			site.proto = true
			site.mode = "fall"
			site.colours = 4
			site.title = "%d %s" % [k + 1, site.name]
			if k < PROTO_ENERGY.size():
				site.energy = PROTO_ENERGY[k]
			_protos.append(site)
	return _protos


## The prototype picker's buttons: [title, campaign index].
static func proto_list() -> Array:
	var out := []
	for i in protos().size():
		out.append([String(protos()[i].title), LIST.size() + i])
	return out


static func goal_text(g: Dictionary) -> String:
	match g.type:
		"ore": return "Extract %d %s" % [g.n, Economy.RES_NAMES[g.ore]]
		"rock": return "Break %d rock" % g.n
		"chunks": return "Extract %d ore" % g.n
		"crystal": return "Recover %d crystal%s" % [g.n, "" if g.n == 1 else "s"]
		"blast": return "Set off %d blast%s" % [g.n, "" if g.n == 1 else "s"]
		"generator": return "Switch on %d generator%s" % [g.n, "" if g.n == 1 else "s"]
		"core": return "Deliver %d energy core%s" % [g.n, "" if g.n == 1 else "s"]
		"cage": return "Break %d cage%s" % [g.n, "" if g.n == 1 else "s"]
		"web": return "Clear %d web%s" % [g.n, "" if g.n == 1 else "s"]
	return "?"


## The number a dig is known by (gold rush bonus digs sit between digs and have none, so
## inserting one does not renumber the campaign); 0 for a gold rush.
static func dig_number(i: int) -> int:
	if i >= LIST.size() or LIST[clampi(i, 0, LIST.size() - 1)].get("gold_rush", false):
		return 0
	var n := 0
	for j in mini(i + 1, LIST.size()):
		if not LIST[j].get("gold_rush", false):
			n += 1
	return n


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1
