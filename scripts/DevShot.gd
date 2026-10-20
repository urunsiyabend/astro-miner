extends Node

## Dev-only screenshot harness (inert unless ASTRO_SHOT is set).
##   ASTRO_SHOT=out.png ASTRO_SCENE=colony|dig ASTRO_MOVES="RRDL" godot --path .
## Plays the scripted moves on site ASTRO_SITE (default 0) with a fixed seed, then saves.

func _ready() -> void:
	Game.save_path = "user://shot_save.json"
	Game.show_fps = OS.has_environment("ASTRO_FPS")
	if OS.has_environment("ASTRO_NEWTIPS"):  # play every lesson as if for the first time
		Game.tips_seen.clear()
	if OS.has_environment("ASTRO_CLEARED"):
		for i in int(OS.get_environment("ASTRO_CLEARED")):
			Game.cleared[i] = true
	if OS.has_environment("ASTRO_BANK"):
		Game.coin = 9999
		Game.star = 999
		Game.levels = [1, 1, 1, 1]
		Game.unlocked = Sites.count()
	# colony states: ASTRO_STAR=<stars>, ASTRO_LEVELS=<p,w,l>; milestones count as celebrated
	# unless ASTRO_FRESH is set (then the colony plays its milestone/unlock walkthrough)
	if OS.has_environment("ASTRO_STAR"):
		Game.star = int(OS.get_environment("ASTRO_STAR"))
		Game.coin = maxi(Game.coin, 200)
		if not OS.has_environment("ASTRO_FRESH"):
			Game.milestones_seen = Game.milestones_reached()
			for b in Economy.BUILDINGS.size():
				Game.tips_seen["unlock_%d" % b] = true
	if OS.has_environment("ASTRO_BOOST"):  # ASTRO_BOOST=b,w,l,m: booster counts (-1: still locked)
		var bc := OS.get_environment("ASTRO_BOOST").split(",")
		for k in mini(4, bc.size()):
			var n := int(bc[k])
			Game.boosters[k] = maxi(0, n)
			Game.levels[Economy.BOOSTERS[k].building] = 0 if n < 0 else maxi(1, Game.levels[Economy.BOOSTERS[k].building])
	if OS.has_environment("ASTRO_MADE"):  # ASTRO_MADE=p,w,l,t: boosters waiting on each building
		var md := OS.get_environment("ASTRO_MADE").split(",")
		for k in mini(4, md.size()):
			Game.made[k] = int(md[k])
	if OS.has_environment("ASTRO_LEVELS"):
		var lv := OS.get_environment("ASTRO_LEVELS").split(",")
		for b in mini(Economy.BUILDINGS.size(), lv.size()):
			Game.levels[b] = int(lv[b])
	_run.call_deferred()


func _run() -> void:
	var main := get_parent()
	var scene := OS.get_environment("ASTRO_SCENE")
	if OS.has_environment("ASTRO_PLANET"):
		Art.planet = OS.get_environment("ASTRO_PLANET")
	await get_tree().create_timer(0.3).timeout
	if scene == "dig":
		var site := int(OS.get_environment("ASTRO_SITE")) if OS.has_environment("ASTRO_SITE") else 0
		main.colony.visible = false
		main.dig.visible = true
		Sfx.music("dig")
		main.dig.force_treasure = OS.has_environment("ASTRO_TREASURE")  # hide a chest in this dig
		main.dig.start(site, false, 12345)
		if OS.has_environment("ASTRO_WEBTEX"):  # ASTRO_WEBTEX=/abs/file.png: a web design to try
			main.dig.view.web_tex_override = ImageTexture.create_from_image(Image.load_from_file(OS.get_environment("ASTRO_WEBTEX")))
		await get_tree().create_timer(0.4).timeout
		# ASTRO_TALK=n: tap through the goal card and n of Mira's lines first (all if unset)
		var talk := int(OS.get_environment("ASTRO_TALK")) if OS.has_environment("ASTRO_TALK") else 99
		if talk >= 0:
			main.dig._close_mission(true)
		for k in talk * 2:
			if not main.dig._dialog.visible:
				break
			main.dig._dialog._advance()
		await get_tree().create_timer(0.3).timeout
		if OS.has_environment("ASTRO_ENERGY"):  # ASTRO_ENERGY=n: moves left (e.g. the low-moves banner, before the moves)
			main.dig.board.energy = int(OS.get_environment("ASTRO_ENERGY"))
			main.dig._hud.set_energy(main.dig.board.energy, main.dig.board.cfg.capacity)
		var map := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
		if OS.has_environment("ASTRO_CALLOUT"):  # ASTRO_CALLOUT=n: the cascade callout for chain n
			main.dig._on_fx("chain", {"n": int(OS.get_environment("ASTRO_CALLOUT")), "pos": Vector2.ZERO})
		if OS.has_environment("ASTRO_CRYSTAL"):  # ASTRO_CRYSTAL=cell: an open crystal there
			main.dig.board.token[int(OS.get_environment("ASTRO_CRYSTAL"))] = Board.Token.CRYSTAL
			main.dig.view.show_snap(main.dig.board.snapshot())
		if OS.has_environment("ASTRO_SPECIAL"):  # ASTRO_SPECIAL="cell:kind;...": place moved-specials
			for e in OS.get_environment("ASTRO_SPECIAL").split(";", false):
				var ck := e.split(":")
				main.dig.board.token[int(ck[0])] = Board.Token.CHARGE
				main.dig.board.spec[int(ck[0])] = int(ck[1])
			main.dig.view.show_snap(main.dig.board.snapshot())
		for e in OS.get_environment("ASTRO_SWAPS").split(",", false):  # classic: "cell:U,cell:L"
			var cd := e.split(":")
			main.dig._on_swap(int(cd[0]), map[cd[1]])
			await get_tree().create_timer(float(OS.get_environment("ASTRO_MOVEWAIT")) if OS.has_environment("ASTRO_MOVEWAIT") else 0.7).timeout
		if OS.has_environment("ASTRO_TOUCHDRAG"):  # "x,y,dx,dy": a real drag through DigScreen._input
			var tv := OS.get_environment("ASTRO_TOUCHDRAG").split(",")
			var p0 := Vector2(float(tv[0]), float(tv[1]))
			var d0 := Vector2(float(tv[2]), float(tv[3]))
			var ev := InputEventScreenTouch.new()
			ev.pressed = true
			ev.position = p0
			Input.parse_input_event(ev)
			await get_tree().process_frame
			for k in 20:
				var dr := InputEventScreenDrag.new()
				dr.position = p0 + d0 * (k + 1) / 20.0
				Input.parse_input_event(dr)
				await get_tree().process_frame
			await get_tree().create_timer(0.4).timeout
		if OS.has_environment("ASTRO_DRAWPATH"):  # "RRD": hold the robot and draw (no release)
			var v: BoardView = main.dig.view
			v._drawing = true
			v._path_real = v.snap
			v._path_dirs = []
			v._path_cells = [v.snap.robot]
			for ch in OS.get_environment("ASTRO_DRAWPATH"):
				if OS.has_environment("ASTRO_DRAWWAIT"):  # draw slowly (movies)
					var from := v._finger if v._path_dirs.size() > 0 else v.cell_center(v._path_cells[-1])
					var to := v.cell_center(Board.idx(Board.pos(v._path_cells[-1]) + map[ch]))
					var dt := float(OS.get_environment("ASTRO_DRAWWAIT"))
					var t0 := 0.0
					while t0 < dt:
						await get_tree().process_frame
						t0 += get_process_delta_time()
						v._finger = from.lerp(to, minf(1.0, t0 / dt))
						v._path_extend(v._cell_at(v._finger))
				v._path_extend(Board.pos(v._path_cells[-1]) + map[ch])
				v._finger = v.cell_center(v._path_cells[-1])
			if OS.has_environment("ASTRO_HOLD"):
				await get_tree().create_timer(float(OS.get_environment("ASTRO_HOLD"))).timeout
			if OS.has_environment("ASTRO_RELEASE"):
				v._drawing = false
				v._finish_path()
				await get_tree().create_timer(float(OS.get_environment("ASTRO_RELEASE"))).timeout
				await RenderingServer.frame_post_draw  # shoot exactly this far after the release
				get_viewport().get_texture().get_image().save_png(OS.get_environment("ASTRO_SHOT"))
				get_tree().quit()
				return
		if OS.has_environment("ASTRO_AUTOMOVE"):  # ASTRO_AUTOMOVE=n: the planner plays n moves
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in int(OS.get_environment("ASTRO_AUTOMOVE")):
				while main.dig.view.is_busy():
					await get_tree().process_frame
				if main.dig.board.over:
					break
				if OS.has_environment("ASTRO_GAP"):  # seconds of "thinking" before each move
					await get_tree().create_timer(float(OS.get_environment("ASTRO_GAP"))).timeout
				if main.dig.board.cfg.path_max > 1:
					main.dig._on_path(Bots.choose_path(main.dig.board, Bots.Kind.PLANNER, rng))
				else:
					main.dig._on_move(Bots.choose(main.dig.board, Bots.Kind.PLANNER, rng))
				if k < int(OS.get_environment("ASTRO_AUTOMOVE")) - 1:
					while main.dig.view.is_busy():
						await get_tree().process_frame
			if OS.has_environment("ASTRO_FRAMES"):  # "0.05,0.1,...": shots that far after the last move
				var t0 := Time.get_ticks_msec()
				var base := OS.get_environment("ASTRO_SHOT").get_basename()
				var n := 0
				for f in OS.get_environment("ASTRO_FRAMES").split(","):
					while Time.get_ticks_msec() - t0 < float(f) * 1000.0:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, n])
					n += 1
				get_tree().quit()
				return
			await get_tree().create_timer(float(OS.get_environment("ASTRO_MOVEWAIT")) if OS.has_environment("ASTRO_MOVEWAIT") else 0.1).timeout
		for ch in OS.get_environment("ASTRO_MOVES"):
			if map.has(ch):
				main.dig._on_move(map[ch])
				await get_tree().create_timer(float(OS.get_environment("ASTRO_MOVEWAIT")) if OS.has_environment("ASTRO_MOVEWAIT") else 0.7).timeout
		if OS.has_environment("ASTRO_ARM"):  # ASTRO_ARM=k: arm booster k; ASTRO_USE=target: use it
			main.dig._on_booster(int(OS.get_environment("ASTRO_ARM")))
			if OS.has_environment("ASTRO_USE"):
				main.dig._use_booster(int(OS.get_environment("ASTRO_USE")))
				await get_tree().create_timer(float(OS.get_environment("ASTRO_USEWAIT")) if OS.has_environment("ASTRO_USEWAIT") else 0.15).timeout
		if OS.has_environment("ASTRO_LOCKTAP"):  # ASTRO_LOCKTAP=k: tap a locked slot
			main.dig._boosters._on_slot(int(OS.get_environment("ASTRO_LOCKTAP")))
			await get_tree().create_timer(0.15).timeout
		if OS.has_environment("ASTRO_HAUL"):
			main.dig._toggle_haul()
		if OS.has_environment("ASTRO_HINT"):
			main.dig._on_hint()
		if OS.has_environment("ASTRO_FOCUS"):  # ASTRO_FOCUS="x,y;x,y": frame those cells
			var cells := []
			for p in OS.get_environment("ASTRO_FOCUS").split(";"):
				var xy := p.split(",")
				cells.append(Vector2i(int(xy[0]), int(xy[1])))
			main.dig.view.focus = cells
		if OS.has_environment("ASTRO_HINTDIR"):  # ASTRO_HINTDIR=0..3: frame the hinted step
			main.dig.view.hint_dir = int(OS.get_environment("ASTRO_HINTDIR"))
		if OS.has_environment("ASTRO_RESULT"):  # ASTRO_RESULT=complete|recall|bonus: end the dig now
			var how := OS.get_environment("ASTRO_RESULT")
			main.dig.board.complete = how != "recall"
			main.dig.board.over = true
			if how == "bonus":  # play the moves-left -> Coin payout first
				main.dig._on_settled()
			else:
				main.dig._show_result()
		var mid := float(OS.get_environment("ASTRO_MID")) if OS.has_environment("ASTRO_MID") else 0.0
		await get_tree().create_timer(0.6 if mid <= 0.0 else mid).timeout
	else:
		main.colony._view.debug_sites = OS.has_environment("ASTRO_SITES")
		main.colony.refresh()
		await get_tree().create_timer(0.5).timeout
		# ASTRO_TALK=n taps through n of Mira's colony lines; ASTRO_BUY=b then buys building b
		var talk := int(OS.get_environment("ASTRO_TALK")) if OS.has_environment("ASTRO_TALK") else 0
		for k in talk * 2:
			if main.colony._dialog.visible:
				main.colony._dialog._advance()
		await get_tree().create_timer(0.4).timeout
		if OS.has_environment("ASTRO_BUY"):
			main.colony._spot.close()
			main.colony._buy(int(OS.get_environment("ASTRO_BUY")))
			# ASTRO_BUYWAIT=<s>: shoot that far into the build animation
			if OS.has_environment("ASTRO_BUYWAIT"):
				await get_tree().create_timer(float(OS.get_environment("ASTRO_BUYWAIT"))).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OS.get_environment("ASTRO_SHOT"))
				get_tree().quit()
				return
			await get_tree().create_timer(0.3).timeout
			for k in 8:
				if main.colony._dialog.visible:
					main.colony._dialog._advance()
		if OS.has_environment("ASTRO_SPOT"):  # ASTRO_SPOT=b: the "build it" spotlight on building b
			main.colony._dialog.visible = false
			main.colony._spot_build(int(OS.get_environment("ASTRO_SPOT")))
			await get_tree().create_timer(0.3).timeout
			if OS.has_environment("ASTRO_SPOT_TAP"):  # tap the lit plot like a finger would: press, release
				var at: Vector2 = main.colony._view.plot_global(Colony.building_plot(int(OS.get_environment("ASTRO_SPOT"))))
				for down in [true, false]:
					var e := InputEventMouseButton.new()
					e.button_index = MOUSE_BUTTON_LEFT
					e.pressed = down
					e.position = at
					e.global_position = at
					get_viewport().push_input(e, true)
					await get_tree().process_frame
				await get_tree().create_timer(float(OS.get_environment("ASTRO_SPOT_TAP"))).timeout
		if OS.has_environment("ASTRO_SPOT_DIG"):
			main.colony._spot_dig()
			await get_tree().create_timer(0.3).timeout
		if OS.has_environment("ASTRO_TAB"):  # ASTRO_TAB=0..4: open that tab-bar page
			main.colony._on_tab(int(OS.get_environment("ASTRO_TAB")))
		if OS.has_environment("ASTRO_PROTOS"):  # the Prototypes picker
			main.colony._open_protos()
		if OS.has_environment("ASTRO_DEV"):  # dev mode on, and Dig pressed (the level list)
			Game.dev_mode = true
			main.colony.refresh()
			main.colony._on_go()
		if OS.has_environment("ASTRO_CARD"):  # ASTRO_CARD=b: tap building b's plot
			main.colony.refresh()
			main.colony._on_plot(Colony.building_plot(int(OS.get_environment("ASTRO_CARD"))))
			if OS.has_environment("ASTRO_TAPWAIT"):  # shoot this far into the tap's answer
				await get_tree().create_timer(float(OS.get_environment("ASTRO_TAPWAIT"))).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OS.get_environment("ASTRO_SHOT"))
				get_tree().quit()
				return
		await get_tree().create_timer(0.6).timeout
	if OS.has_environment("ASTRO_PERF"):  # ASTRO_PERF=s: measure frame times for s seconds
		await _perf(float(OS.get_environment("ASTRO_PERF")))
		get_tree().quit()
		return
	if OS.has_environment("ASTRO_DUMP"):  # print every visible control's global rect
		var stack: Array = [main]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Control and (n as Control).is_visible_in_tree():
				print(n.get_path(), " ", n.get_class(), " ", (n as Control).get_global_rect())
			stack.append_array(n.get_children())
	print("main size ", main.size, " colony ", main.colony.size, " vis ", main.colony.visible)
	if OS.has_environment("ASTRO_WAIT"):  # ASTRO_WAIT=s: let animations run this long first
		await get_tree().create_timer(float(OS.get_environment("ASTRO_WAIT"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("ASTRO_SHOT"))
	get_tree().quit()


## Frame cost of what is on screen now: CPU and GPU render time of the main viewport and the
## script/process time, averaged and at the 95th percentile (vsync off for a clean read).
func _perf(secs: float) -> void:
	# ASTRO_HIDE=a,b: hide parts of the dig screen to see what each costs on the GPU
	var dig = get_parent().dig
	for part in OS.get_environment("ASTRO_HIDE").split(",", false):
		match part:
			"bar": dig._boosters.visible = false
			"hud": dig._hud.visible = false
			"board": dig.view.visible = false
			"sky": dig.get_child(1).visible = false
			"fx": dig.fxl.visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for k in 30:
		await get_tree().process_frame
	var cpu := []
	var gpu := []
	var proc := []
	var wall := []
	var first := _Stamp.new()
	first.process_priority = -100000
	var last := _Stamp.new()
	last.process_priority = 100000
	get_tree().root.add_child(first)
	get_tree().root.add_child(last)
	var scr := []
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await get_tree().process_frame
		frames += 1
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		wall.append(get_process_delta_time() * 1000.0)
		scr.append((last.at - first.at) / 1000.0)
	var fps := frames / secs
	print("SCRIPTS (all _process) %s" % _stat(scr))
	print("PERF fps %.0f | frame %s | gpu %s | render-cpu %s | process %s" % [fps, _stat(wall), _stat(gpu), _stat(cpu), _stat(proc)])


func _stat(a: Array) -> String:
	a.sort()
	var sum := 0.0
	for v in a:
		sum += v
	return "avg %.2f p95 %.2f ms" % [sum / maxf(1, a.size()), a[int(a.size() * 0.95)] if not a.is_empty() else 0.0]


class _Stamp extends Node:
	var at := 0
	func _process(_d: float) -> void:
		at = Time.get_ticks_usec()
