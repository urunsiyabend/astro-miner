class_name ColonyView
extends Control

## The colony map (GDD v3 §4): a 2:1 isometric grid of build sites joined by paths, the habitat
## dome on the big hub site in the middle (Colony.PLOTS gives each plot its grid cell). A
## building stands on its site once its star milestone unlocks it; a decoration appears when its
## cosmetic milestone is reached; a site still to come shows a dashed outline and the stars it
## needs. Every plot is a tap target (plot_tapped), which the colony screen turns into a
## building card, and which the onboarding spotlight can point at.
## Sites and paths are drawn here in the planet's own colours: a site is one plain tile a shade
## off the ground, a path a soft lighter trail. Each painted sprite stands on its site by its
## measured foot (ColonySockets, from tools/art/sockets.py), so nothing has to be lined up by
## eye. Brought to life in code: a slow breath, pulsing battery light, chimney smoke, a
## blinking beacon, a glint across the dome.

signal plot_tapped(i: int)
## A building being built hit the ground (for dust, shake and sound on the screen).
signal landed(i: int)

## How wide a sprite's base is drawn against its site's width.
const FIT := 1.04
## Where each building's level badge sits (fraction of its sprite canvas): low and to the side.

var levels := [0, 0, 0, 0]
var star := 0
var debug_sites := false   # dev: draw every site centre (DevShot ASTRO_SITES)
var _time := 0.0
var _pop := {}       # plot index -> remaining celebration time (s)
var _nudge := {}     # plot index -> 1..0 after a tap on a locked plot (it shakes and bounces)
var _buttons := []   # one invisible Button per plot
var _font: Font
var _smoke := []     # chimney puffs: {p, t}
var _smoke_t := 0.0
var _badges := []    # level badges collected while drawing, drawn last over everything
var _build := {}     # plot index -> seconds since its build / upgrade animation started
var _build_new := {} # plot index -> true for a first build (drop in), false for an upgrade
var _bubble_tops := {}  # plot index -> top-centre of its drawn sprite (bubbles float over it)
var _poke := {}      # plot index -> 1..0 after a tap on a built building (a happy squash-hop)
var made := [0, 0, 0, 0]  # boosters waiting on each building (Game.made): a bubble over it
var _bubble_pop := {}  # plot index -> 0..1 while its bubble bursts (collected)
const BUILD_T := 1.15
const LAND_AT := 0.42   # seconds into a build when the building hits the ground


func _ready() -> void:
	custom_minimum_size = Vector2(0, 760)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = Widgets.game_font()
	for i in Colony.PLOTS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func(): plot_tapped.emit(i))
		add_child(b)
		_buttons.append(b)
	resized.connect(_layout)


func set_state(l: Array, s: int, m: Array = [0, 0, 0, 0]) -> void:
	levels = l.duplicate()
	star = s
	made = m.duplicate()
	queue_redraw()


## A locked plot was tapped: it shakes, bounces and flashes.
func nudge(i: int) -> void:
	_nudge[i] = 1.0


## A built building was tapped: it squashes down and springs up (before its card opens).
func poke(i: int) -> void:
	_poke[i] = 1.0


## The booster bubble over plot i bursts (its boosters were collected).
func pop_bubble(i: int) -> void:
	_bubble_pop[i] = 0.0


## Where the bubble over plot i floats (global), for the collect fx.
func bubble_global(i: int) -> Vector2:
	return get_global_transform() * _bubble_at(i)


func celebrate(i: int) -> void:
	if i >= 0:
		_pop[i] = 1.2


## The juicy build: a fresh building drops in, squashes on landing and settles; an upgrade
## hops and grows. landed(i) fires on the impact.
func build_anim(i: int, fresh: bool) -> void:
	if i < 0:
		return
	_build[i] = 0.0
	_build_new[i] = fresh


# --- grid ---------------------------------------------------------------------

## The paths layer (assets/colony/paths.png: the dirt plots and the paths between them, its
## own sprite over the sky background) is drawn PATHS_W of the map wide, its hub at HUB_AT.
## Site positions are measured in its pixels (ColonySockets.SITES, tools/art/sockets.py) and
## mapped through the same rect, so buildings always stand on their plots.
const PATHS_W := 0.98
const HUB_AT := Vector2(0.5, 0.73)
## The robot's pad stands on its own spot above the colony (map share), not on the paths layer.
const PAD_AT := Vector2(0.5, 0.415)


func _paths_tex() -> Texture2D:
	return Art.tex("res://assets/colony/paths.png")


func _paths_scale() -> float:
	var t := _paths_tex()
	return size.x * PATHS_W / t.get_width() if t != null else 1.0


func _paths_rect() -> Rect2:
	var t := _paths_tex()
	if t == null:
		return Rect2(Vector2.ZERO, size)
	var k := _paths_scale()
	var hub: Vector3 = ColonySockets.SITES.hub
	var pos := Vector2(size.x * HUB_AT.x, size.y * HUB_AT.y) - Vector2(hub.x, hub.y) * k
	return Rect2(pos, Vector2(t.get_width(), t.get_height()) * k)


## Local point of a pixel of the paths layer.
func bg_point(p: Vector2) -> Vector2:
	return _paths_rect().position + p * _paths_scale()


func _bg_scale() -> float:
	return _paths_scale()


func _site_of(id: String) -> Vector3:
	return ColonySockets.SITES.get(id, Vector3(512, 768, 260))


func _site_center(id: String) -> Vector2:
	if id == "pad":
		return Vector2(size.x * PAD_AT.x, size.y * PAD_AT.y)
	var v := _site_of(id)
	return bg_point(Vector2(v.x, v.y))


## Half width of a site on screen (a free-standing decoration gets a standard plot's).
func _site_half_of(id: String) -> float:
	return _site_of(id).z * 0.5 * _bg_scale()


func _site_half(hub: bool) -> float:
	return _site_half_of("hub" if hub else "power")


## Centre of plot i's site.
func plot_center(i: int) -> Vector2:
	return _site_center(Colony.PLOTS[i].id)


func plot_global(i: int) -> Vector2:
	return get_global_transform_with_canvas() * plot_center(i)


func plot_button(i: int) -> Button:
	return _buttons[i] if i >= 0 and i < _buttons.size() else null


func building_global(b: int) -> Vector2:
	return plot_global(Colony.building_plot(b))


## The tap/spotlight size of a plot.
func _plot_size() -> float:
	return _site_half(false) * 2.2


## Each plot's tap button covers its diamond exactly (the spotlight lights that diamond).
func _layout() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		var half := _site_half_of(Colony.PLOTS[i].id) * 1.05
		var sz := Vector2(half * 2.0, half * 2.0 / ColonySockets.PLOT_ASPECT)
		btn.position = plot_center(i) - sz * 0.5
		btn.size = sz
		btn.set_meta("spot_shape", "diamond")


func _process(delta: float) -> void:
	_time += delta
	_layout()   # cheap, and keeps the tap areas on the plots whatever moved the map
	for k in _pop.keys():
		_pop[k] -= delta
		if _pop[k] <= 0.0:
			_pop.erase(k)
	for k in _build.keys():
		var before: float = _build[k]
		_build[k] += delta
		var hit: float = LAND_AT if _build_new[k] else 0.18
		if before < hit and _build[k] >= hit:
			landed.emit(k)
		if _build[k] >= BUILD_T:
			_build.erase(k)
			_build_new.erase(k)
	for k in _nudge.keys():
		_nudge[k] -= delta / 0.5
		if _nudge[k] <= 0.0:
			_nudge.erase(k)
	for k in _poke.keys():
		_poke[k] -= delta / 0.45
		if _poke[k] <= 0.0:
			_poke.erase(k)
	for k in _bubble_pop.keys():
		_bubble_pop[k] += delta / 0.3
		if _bubble_pop[k] >= 1.0:
			_bubble_pop.erase(k)
	# chimney smoke from the workshop, a puff every ~0.7 s while it stands
	var wi := Colony.building_plot(1)
	if wi >= 0 and plot_state(wi) == "built":
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 0.7
			_smoke.append({"p": _chimney(wi), "t": 0.0})
	for p in _smoke:
		p.t += delta
	_smoke = _smoke.filter(func(p): return p.t < 2.2)
	queue_redraw()


## What stands on plot i right now: "built", "due" (unlocked building not built yet), "locked".
func plot_state(i: int) -> String:
	var plot: Dictionary = Colony.PLOTS[i]
	if plot.has("building"):
		var b: int = plot.building
		if levels[b] > 0:
			return "built"
		return "due" if star >= Economy.STAR_UNLOCK[b] else "locked"
	return "built" if star >= Colony.plot_stars(i) else "locked"


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var pt := _paths_tex()
	if pt != null:
		draw_texture_rect(pt, _paths_rect(), false)
	# everything standing on the plots, back to front
	_badges = []
	var order := []
	for i in Colony.PLOTS.size():
		order.append([plot_center(i).y, i])
	order.append([_site_center("hub").y, -1])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for o in order:
		if o[1] == -1:
			var r := _sprite("dome", _site_center("hub"), _site_half(true), 0.0)
			_dome_glint(r)
		else:
			_plot(o[1])
	for b in _badges:
		_badge(b[0], b[1], b[2])
	for i in Colony.PLOTS.size():
		var plot: Dictionary = Colony.PLOTS[i]
		if plot.has("building") and plot_state(i) == "built" and (made[plot.building] > 0 or _bubble_pop.has(i)):
			_bubble(i, plot.building)
	var s := _plot_size()
	for p in _smoke:
		var k: float = p.t / 2.2
		var at: Vector2 = p.p + Vector2(sin(p.t * 2.0) * s * 0.03, -s * 0.35 * k)
		draw_circle(at, s * (0.025 + 0.05 * k), Color(0.92, 0.9, 1.0, 0.45 * (1.0 - k)), true, -1.0, true)
	if debug_sites:
		for i in Colony.PLOTS.size():
			var c := plot_center(i)
			draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(1, 0, 0), 3.0)
			draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(1, 0, 0), 3.0)


## A colony sprite standing on a site by its measured foot, its base as wide as the site; `ph`
## offsets its breathing; `lift` raises it above the ground and `sq` squashes it (build anim).
## Returns the sprite's drawn rect.
func _sprite(id: String, site_c: Vector2, half: float, ph: float, lift := 0.0, sq := Vector2.ONE, alpha := 1.0) -> Rect2:
	var tex := Art.tex("res://assets/colony/%s.png" % id)
	var bw: float = ColonySockets.BASE_W.get(id, 0.95)
	var sz := half * 2.0 * FIT / bw
	var foot: Vector2 = ColonySockets.FOOT.get(id, Vector2(0.5, 0.7))
	var r := Rect2(site_c - foot * sz, Vector2(sz, sz))
	if tex == null:
		draw_rect(r, Color(1, 1, 1, 0.15))
		return r
	# breathe from the foot: a touch taller and narrower, then back
	var breath := sin(_time * 1.6 + ph) * 0.012
	var k := Vector2(1.0 - breath * 0.5, 1.0 + breath) * sq
	# contact shadow: the sprite's own silhouette, a little lower, in a few light passes spread
	# to the left and right so it hugs the base and fades out sideways
	# the shadow stays on the ground and shrinks while the building is up in the air
	var shk := 1.0 / (1.0 + lift / maxf(1.0, sz) * 2.5)
	for ox in [-0.03, -0.01, 0.01, 0.03]:
		var sh := Vector2(sz * (0.012 + ox), sz * 0.028)
		draw_set_transform(site_c + sh, 0.0, Vector2(k.x * 1.03, 0.985) * Vector2(shk, shk))
		draw_texture_rect(tex, Rect2(r.position - site_c, r.size), false, Color(0.1, 0.03, 0.2, 0.085 * alpha))
	draw_set_transform(site_c - Vector2(0, lift), 0.0, k)
	draw_texture_rect(tex, Rect2(r.position - site_c, r.size), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)
	return r


func _plot(i: int) -> void:
	var c := plot_center(i)
	var plot: Dictionary = Colony.PLOTS[i]
	var st := plot_state(i)
	var half := _site_half_of(plot.id)
	var pop: float = _pop.get(i, 0.0)
	if pop > 0.0:
		draw_arc(c, half * (0.8 + (1.2 - pop) * 1.0), 0, TAU, 48, Color(Pal.GOOD, pop / 1.2), 8.0, true)
	if st == "locked":
		var n: float = _nudge.get(i, 0.0)
		var shake := Vector2(sin(n * 40.0) * half * 0.08 * n, 0.0)
		var bump := 1.0 + 0.18 * sin(PI * (1.0 - n)) * n
		var col := Color(0.8, 0.85, 1.0, 0.5).lerp(Color(1.0, 0.95, 0.6, 1.0), n)
		_dashed_plot(c + shake, half * 0.98 * bump, col)
		draw_set_transform(c + shake - Vector2(0, half * 0.14 * sin(PI * (1.0 - n)) * n), 0.0, Vector2(bump, bump))
		_star_need(Vector2.ZERO, Colony.plot_stars(i))
		draw_set_transform(Vector2.ZERO)
		return
	if st == "due":
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		_dashed_plot(c, half * 0.98, Color(Pal.GOOD, 0.6 + 0.4 * pulse))
		_label(c, "BUILD", 44, Pal.GOOD)
		return
	var lift := 0.0
	var sq := Vector2.ONE
	var alpha := 1.0
	if _build.has(i):
		var t: float = _build[i]
		if _build_new[i]:
			# glow on the plot while it falls, then a drop, a squash and a springy settle
			if t < LAND_AT:
				var f := t / LAND_AT
				lift = half * 3.2 * (1.0 - f * f)
				alpha = clampf(f * 3.0, 0.0, 1.0)
				sq = Vector2(0.92, 1.1)
				draw_circle(c, half * (0.5 + 0.4 * f), Color(1.0, 0.95, 0.6, 0.25 * f), true, -1.0, true)
			else:
				var u := (t - LAND_AT) / (BUILD_T - LAND_AT)
				var w := exp(-u * 6.0) * cos(u * 22.0)
				sq = Vector2(1.0 + 0.22 * w, 1.0 - 0.22 * w)
		else:
			var u := t / BUILD_T
			lift = half * 0.35 * sin(minf(u / 0.3, 1.0) * PI)
			var w := exp(-u * 5.0) * sin(u * 18.0)
			sq = Vector2(1.0 + 0.12 * w, 1.0 + 0.12 * w) * (1.0 + 0.08 * sin(minf(u / 0.3, 1.0) * PI))
	elif _poke.has(i):
		# squash on the tap, spring up with a little hop, wobble to rest
		var u: float = 1.0 - _poke[i]
		var w := exp(-u * 5.5) * cos(u * 20.0)
		sq = Vector2(1.0 + 0.14 * w, 1.0 - 0.14 * w)
		lift = half * 0.22 * maxf(0.0, sin(minf(u / 0.45, 1.0) * PI))
		draw_circle(c, half * (0.55 + 0.5 * u), Color(1.0, 0.96, 0.7, 0.22 * (1.0 - u)), true, -1.0, true)
	var r := _sprite(plot.id, c, half, i * 1.3, lift, sq, alpha)
	_bubble_tops[i] = Vector2(r.get_center().x, r.position.y + r.size.y * 0.12)
	match plot.id:
		"power": _battery_glow(r)
		"antenna": _beacon(r)
		"lab": _windows(r)
	if plot.has("building"):
		var bk := 1.0
		if _build.has(i):
			var hit: float = LAND_AT if _build_new[i] else 0.18
			var bt: float = _build[i] - hit - 0.15
			bk = 0.0 if bt < 0.0 else Widgets.back_out(bt / 0.3, 3.5)
		if bk > 0.0:
			# every building wears its level in the same place: the outer corner of its plot (the
			# paths join the inner corners, and nothing floats over the outer ones)
			var side := -1.0 if c.x < _site_center("hub").x else 1.0
			var tip := c + Vector2(side * half * 0.8, 0)
			_badges.append([tip, half * 0.25 * bk, levels[plot.building]])


func _bubble_at(i: int) -> Vector2:
	var top: Vector2 = _bubble_tops.get(i, plot_center(i))
	return top - Vector2(0, _plot_size() * 0.26 - _plot_size() * 0.03 * sin(_time * 3.0 + i))


## A booster is ready on this building: a glossy speech-bubble over it with the booster's icon
## (and the count when it holds more than one); it bobs, and bursts when collected.
func _bubble(i: int, b: int) -> void:
	var s := _plot_size()
	var c := _bubble_at(i)
	var r := s * 0.27
	var pop: float = _bubble_pop.get(i, -1.0)
	var sc := 1.0 + 0.06 * sin(_time * 5.0 + i)
	var a := 1.0
	if pop >= 0.0:
		sc = 1.0 + 0.6 * pop
		a = 1.0 - pop
	r *= sc
	# the bubble art is a disc of 0.88 of its width with the tail below: centre the disc on c
	var bw := r * 2.0 / 0.88
	var bh := bw * 300.0 / 256.0
	draw_texture_rect(Art.tex("res://assets/ui/bubble_round.png"), Rect2(c - Vector2(bw * 0.5, bw * 0.5), Vector2(bw, bh)), false, Color(1, 1, 1, a))
	var tex := Art.tex("res://assets/ui/boosters/%s.png" % Widgets.BoosterBar.ICONS[Economy.BUILDINGS[b].booster])
	var w := r * 1.6
	draw_texture_rect(tex, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false, Color(1, 1, 1, a))


## Numbered round level badge, as in the mockup.
func _badge(c: Vector2, rad: float, n: int) -> void:
	var w := rad * 2.4
	draw_texture_rect(Art.tex("res://assets/ui/badge_level.png"), Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false)
	Widgets.ink_text(self, _font, c, str(n), int(rad * 1.3), Color.WHITE)


## The four battery cells breathe orange light.
func _battery_glow(r: Rect2) -> void:
	var spots := [Vector2(0.27, 0.32), Vector2(0.47, 0.22), Vector2(0.66, 0.32), Vector2(0.45, 0.45)]
	for k in spots.size():
		var g := 0.5 + 0.5 * sin(_time * 2.6 + k * 1.4)
		var p: Vector2 = r.position + r.size * spots[k]
		draw_circle(p, r.size.x * (0.07 + 0.015 * g), Color(1.0, 0.7, 0.2, 0.10 + 0.14 * g), true, -1.0, true)


func _beacon(r: Rect2) -> void:
	if fmod(_time, 1.4) < 0.5:
		var p := r.position + r.size * Vector2(0.5, 0.04)
		draw_circle(p, r.size.x * 0.06, Color(1.0, 0.25, 0.2, 0.35), true, -1.0, true)
		draw_circle(p, r.size.x * 0.025, Color(1.0, 0.8, 0.7, 0.9), true, -1.0, true)


func _windows(r: Rect2) -> void:
	var g := 0.5 + 0.5 * sin(_time * 1.8)
	var p := r.position + r.size * Vector2(0.73, 0.55)
	draw_circle(p, r.size.x * 0.06, Color(0.4, 0.95, 1.0, 0.10 + 0.12 * g), true, -1.0, true)


## The workshop's chimney top (its sprite's chimney, as a share of its canvas).
func _chimney(i: int) -> Vector2:
	var half := _site_half(false)
	var bw: float = ColonySockets.BASE_W.get("workshop", 0.95)
	var sz := half * 2.0 * FIT / bw
	var foot: Vector2 = ColonySockets.FOOT.get("workshop", Vector2(0.5, 0.7))
	return plot_center(i) - foot * sz + Vector2(0.8, 0.12) * sz


## A light streak sweeping across the dome glass every few seconds.
func _dome_glint(r: Rect2) -> void:
	var t := fmod(_time, 4.5)
	if t > 0.7:
		return
	var k := t / 0.7
	var p := r.position + r.size * Vector2(lerpf(0.2, 0.8, k), lerpf(0.12, 0.32, k))
	var a := sin(k * PI)
	draw_circle(p, r.size.x * 0.05 * a, Color(1, 1, 1, 0.5 * a), true, -1.0, true)
	draw_circle(p, r.size.x * 0.02 * a, Color(1, 1, 1, 0.9 * a), true, -1.0, true)


## "8 <star>" on a locked plot, with the game's star icon.
func _star_need(c: Vector2, n: int) -> void:
	var t := str(n)
	var fs := 46
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon := 26.0
	var total := tw + 8.0 + icon * 2.0
	Widgets.shadow_text(self, _font, Vector2(c.x - total * 0.5 + tw * 0.5, c.y), t, fs, Color.WHITE)
	Widgets.draw_currency_icon(self, Vector2(c.x + total * 0.5 - icon, c.y), icon, true)


func _label(p: Vector2, t: String, fs: int, col: Color) -> void:
	Widgets.shadow_text(self, _font, p, t, fs, col)


## A site still to build: a dashed diamond inside the plot, in the plot's own proportion.
func _dashed_plot(c: Vector2, half: float, col: Color) -> void:
	var hh := half / ColonySockets.PLOT_ASPECT
	var pts := [c + Vector2(0, -hh), c + Vector2(half, 0), c + Vector2(0, hh), c + Vector2(-half, 0)]
	for e in 4:
		var a: Vector2 = pts[e]
		var b: Vector2 = pts[(e + 1) % 4]
		var n := int(a.distance_to(b) / 20.0)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 5.0, true)
