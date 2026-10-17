class_name Pal
extends RefCounted

## Single source of colours and type sizes.

const BG := Color("120d18")
const PANEL := Color("1f1729")
const PANEL_HI := Color("2c2139")
const LINE := Color("3d3050")
const TEXT := Color("f3ecff")
# Secondary text. Both stay light: all text also gets a dark outline (Ui.label), so it reads on
# the painted panels and straight on the night sky.
const DIM := Color("dcd2f0")
const MUTED := Color("b9add2")
const OUTLINE := Color("2a1830")
const GOOD := Color("7dff9b")
const WARN := Color("ffb347")
const BAD := Color("ff5c7a")
const ACCENT := Color("5ad1e6")

const ORE := [Color("ff8a3d"), Color("4fd8ff"), Color("ffe14d"), Color("ff4f6a")]
const ORE_DARK := [Color("9c4517"), Color("1f7896"), Color("a08414"), Color("8a1a2c")]
const CRYSTAL := Color("c88bff")
const CRYSTAL_DARK := Color("6d3aa8")
const CELL := Color("6dff8a")
const CHARGE := Color("ff4f6d")
const RES := [Color("ff8a3d"), Color("4fd8ff"), Color("ffe14d"), Color("ff4f6a"), Color("c88bff")]

# Board (art-v2): the hero B1 board earth, colour-picked. Cells sit on this; dug depth is a
# darker tint of it; the panel has a lavender rim like the hero.
const BOARD_EARTH := Color("5c2b22")     # earth between the cells: toward the board edges
const BOARD_EARTH_HI := Color("8a4535")  # earth: the softly lit middle of the board
const BOARD_LIP := Color("622e23")       # inner lip between the rim and the cells
const BOARD_LINE := Color("391534")      # thin dark line just inside the rim
const BOARD_RIM := Color("b080d3")       # rim: light lavender body (outer part)
const BOARD_RIM_DARK := Color("8357a7")  # rim: darker inner edge, next to the dark line
const BOARD_RIM_HI := Color("d696f6")    # rim: glossy highlight along the top

# Currencies (GDD v3): Coin is the soft spent currency, Star the scarce progress counter.
const COIN := Color("ffd24d")
const COIN_DARK := Color("b5861a")
const STAR := Color("c88bff")

# Ground by elevation: surface first, then each layer dug below it (a pit reads darker
# *and* is drawn with stepped walls, so depth never relies on tone alone).
const GROUND_LEVELS := [Color("74546d"), Color("5a4058"), Color("443047"), Color("322337"), Color("241a29")]
const FLOOR_BARE := Color("2c2732")   # vein exhausted
const VEIN := Color("ffc970")         # reserve pips
const ROCK := [Color("000000"), Color("b3a9c2"), Color("75698f"), Color("3e3452")]
const BEDROCK := Color("0b0810")
const ROBOT := Color("e9f6ff")
const ROBOT_DARK := Color("5b7a99")

const FS_HUGE := 72
const FS_BIG := 52
const FS := 40
const FS_SMALL := 32
const FS_TINY := 30


static func ground_level(level: int) -> Color:
	return GROUND_LEVELS[clampi(level, 0, GROUND_LEVELS.size() - 1)]
