class_name Pal
extends RefCounted

## Single source of colours and type sizes.

const BG := Color("120d18")
const PANEL := Color("1f1729")
const PANEL_HI := Color("2c2139")
const LINE := Color("3d3050")
const TEXT := Color("f3ecff")
const DIM := Color("a596bd")
const MUTED := Color("6c5f80")
const GOOD := Color("7dff9b")
const WARN := Color("ffb347")
const BAD := Color("ff5c7a")
const ACCENT := Color("5ad1e6")

const ORE := [Color("ff8a3d"), Color("4fd8ff"), Color("ffe14d")]
const ORE_DARK := [Color("9c4517"), Color("1f7896"), Color("a08414")]
const CRYSTAL := Color("c88bff")
const CRYSTAL_DARK := Color("6d3aa8")
const CELL := Color("6dff8a")
const CHARGE := Color("ff4f6d")
const RES := [Color("ff8a3d"), Color("4fd8ff"), Color("ffe14d"), Color("c88bff")]

const GROUND_FULL := Color("6a4a63")   # reserve 4+
const GROUND_EMPTY := Color("241a2c")  # exhausted
const ROCK := [Color("000000"), Color("b3a9c2"), Color("75698f"), Color("3e3452")]
const BEDROCK := Color("0b0810")
const ROBOT := Color("e9f6ff")
const ROBOT_DARK := Color("5b7a99")

const FS_HUGE := 72
const FS_BIG := 52
const FS := 40
const FS_SMALL := 32
const FS_TINY := 26


static func ground(reserve: int) -> Color:
	var t := clampf(reserve / 4.0, 0.0, 1.0)
	return GROUND_EMPTY.lerp(GROUND_FULL, 0.25 + 0.75 * t) if reserve > 0 else GROUND_EMPTY
