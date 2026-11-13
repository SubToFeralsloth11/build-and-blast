extends Node
## Developer harness. Run headless with:
##   godot --headless --fixed-fps 60 --path . -- --simtest
## to drive every preset (and random builds) through scripted inputs and print
## physics results, or windowed with `-- --shots` to save screenshots.

var main: Node
var verbose := false
var only := ""


func run(m: Node, args: PackedStringArray) -> void:
	main = m
	await _frames(5)
	if "--simtest" in args:
		await _simtest(args)
	elif "--worldshots" in args:
		await _world_shots()
	else:
		await _shots()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if verbose and main.vehicle and is_instance_valid(main.vehicle) and Engine.get_physics_frames() % 30 == 0:
			var v: RigidBody3D = main.vehicle
			print("  t=%d spd=%.1f vel=%s y=%.2f up=%.2f fwd=%s grounded=%d mass=%.0f sleep=%s freeze=%s inertia=%s" % [Engine.get_physics_frames(), v.linear_velocity.length(), v.linear_velocity.snapped(Vector3.ONE * 0.1), v.com_world().y, v.global_basis.y.y, (-v.global_basis.z).snapped(Vector3.ONE * 0.01), v.grounded, v.mass, v.sleeping, v.freeze, v.inertia])


func _kind(d: Dictionary) -> String:
	var wings := 0
	for b in d.blocks:
		match b.id:
			"leg_servo":
				return "walker"
			"rotor":
				return "heli"
			"boatprop":
				return "boat"
			"balloon":
				return "barge"
			"wing", "deltawing", "sweptwing":
				wings += 1
	return "plane" if wings >= 6 else "car"


func _up(v: Node) -> float:
	return v.global_basis.y.y


func _simtest(args: PackedStringArray) -> void:
	var list: Array = Designs.presets()
	var n_random := 14
	verbose = "--verbose" in args
	for a in args:
		if a.begins_with("--random="):
			n_random = int(a.substr(9))
		if a.begins_with("--only="):
			only = a.substr(7)
	for i in n_random:
		var r: Dictionary = Designs.random_design()
		r.name = "RANDOM %d %s" % [i, r.name]
		list.append(r)
	var fails := 0
	if "--worldtest" in args:
		fails += await _world_test()
		fails += await _missile_test()
		fails += await _engine_test()
		print("SIMTEST DONE fails=%d" % fails)
		return
	for d in list:
		if only != "" and not d.name.contains(only):
			continue
		var res: Dictionary = await _sim(d)
		var ok: bool = res.ok
		if not ok:
			fails += 1
		print("%s %-34s %-6s %s" % ["PASS" if ok else "FAIL", d.name, res.kind, res.msg])
		if not ok:
			var st: Dictionary = Designs.stats(d)
			var ids := {}
			for b in d.blocks:
				ids[b.id] = ids.get(b.id, 0) + 1
			print("     mass=%d wheels=%d %s" % [st.mass, st.wheels, ids])
	await _tnt_test()
	await _crash_test()
	fails += await _mech_test()
	fails += await _catalog_test()
	fails += await _dive_test()
	fails += _builder_test()
	fails += await _world_test()
	fails += await _missile_test()
	fails += await _engine_test()
	print("SIMTEST DONE fails=%d" % fails)


func _check(cond: bool, what: String) -> int:
	print("%s builder: %s" % ["PASS" if cond else "FAIL", what])
	return 0 if cond else 1


func _wcheck(cond: bool, what: String) -> int:
	print("%s world: %s" % ["PASS" if cond else "FAIL", what])
	return 0 if cond else 1


## Race track, carrier and test zone: spawn there, stay put, drive, time a lap.
func _world_test() -> int:
	var f := 0
	var w: Node = main.world
	var buggy: Dictionary = Designs.presets()[0]
	for loc in ["track", "carrier", "testzone"]:
		main.builder.load_design(buggy, false)
		main.start_test(loc)
		var v: RigidBody3D = main.vehicle
		Controls.sim = {"always": 1.0}
		await _frames(90)
		var info: Dictionary = w.spawn_info(loc)
		var dy: float = v.com_world().y - info.pos.y
		f += _wcheck(v.alive and dy > -0.5 and dy < 3.0, "%s spawn rests on the surface (com %.2f m above)" % [loc, dy])
		Controls.sim = {"throttle": 1.0, "always": 1.0}
		await _frames(240)
		var spd := v.linear_velocity.length()
		var dy2: float = v.com_world().y - info.pos.y
		f += _wcheck(spd > 8.0 and dy2 > -0.5 and dy2 < 3.0, "%s drives (%.1f m/s, com %.2f m above)" % [loc, spd, dy2])
		Controls.sim = {"always": 1.0}
		main.back_to_builder()
		await _frames(2)
	# a lap: slide the car along the centre line and check the timing events
	main.builder.load_design(buggy, false)
	main.start_test("track")
	var car: RigidBody3D = main.vehicle
	var seen := []
	var rec := func(kind: String, _t: String) -> void: seen.append(kind)
	Fx.event.connect(rec)
	var tr: PackedVector3Array = w.track
	var m := tr.size()
	var path := range(m - 4, m) + range(0, m) + range(0, 4)
	for k: int in path:
		car.global_position = tr[k] + Vector3(0, 1.0, 0)
		car.linear_velocity = Vector3.ZERO
		await _frames(1)
	Fx.event.disconnect(rec)
	f += _wcheck(seen.count("race_start") == 1 and seen.count("race_sector") == 3 and seen.count("race_lap") == 1 and w.race_best > 0.0,
		"lap timing %s (track %d samples)" % [seen, m])
	# cutting the course does not count as a lap
	seen.clear()
	Fx.event.connect(rec)
	for k: int in range(m - 4, m) + range(0, 4) + range(m - 4, m) + range(0, 4):
		car.global_position = tr[k] + Vector3(0, 1.0, 0)
		await _frames(1)
	Fx.event.disconnect(rec)
	f += _wcheck(not seen.has("race_lap"), "skipping the sectors gives no lap %s" % [seen])
	main.back_to_builder()
	await _frames(2)
	return f


## The same buggy with no engine, the weakest, a mid and the strongest engine:
## no engine must not move, and more power must mean more speed.
func _engine_test() -> int:
	var f := 0
	var speeds := {}
	for eng in ["", "mower_engine", "i4_engine", "v10_engine"]:
		var d: Dictionary = Designs.presets()[0].duplicate(true)
		var blocks := []
		for b in d.blocks:
			if Blocks.defs[b.id].kind == "motor":
				if eng != "":
					var nb: Dictionary = b.duplicate(true)
					nb.id = eng
					blocks.append(nb)
			else:
				blocks.append(b)
		d.blocks = blocks
		main.builder.load_design(d, false)
		main.start_test("testzone")
		Controls.sim = {"always": 1.0}
		await _frames(30)
		Controls.sim = {"throttle": 1.0, "always": 1.0}
		await _frames(240)
		speeds[eng] = main.vehicle.linear_velocity.length()
		Controls.sim = {"always": 1.0}
		main.back_to_builder()
		await _frames(2)
	print("ENGINES 4s speed: none %.1f  mower %.1f  inline-4 %.1f  V10 %.1f" % [speeds[""], speeds["mower_engine"], speeds["i4_engine"], speeds["v10_engine"]])
	f += _wcheck(speeds[""] < 1.0, "no engine: driven wheels stay still")
	f += _wcheck(speeds["mower_engine"] > 1.0 and speeds["mower_engine"] < speeds["i4_engine"] - 3.0, "mower engine is weak")
	f += _wcheck(speeds["v10_engine"] > speeds["i4_engine"] + 2.0, "racing V10 beats the inline-4")
	return f


## Holding fire on missiles must not pile up particle systems or materials
## (that stalled the GPU and crashed the game on macOS).
func _missile_test() -> int:
	var f := 0
	var mech: Dictionary = Designs.presets()[17]
	main.builder.load_design(mech, false)
	main.start_test("testzone")
	var v: RigidBody3D = main.vehicle
	var pm0: int = Fx._pm_cache.size()
	var dc0: int = Fx._draw_cache.size()
	var peak := 0
	var fired := 0
	var seen := {}
	for i in 60 * 12:
		# swing the camera (and so the crosshair aim) around so missiles turn every way
		main.cam_yaw = i * 0.02
		main.cam_pitch = -0.2 + sin(i * 0.013) * 0.4
		Controls.sim = {"always": 1.0, "fire2": 1.0, "fire1": 1.0}
		await get_tree().physics_frame
		var n := 0
		for c in Fx.root.get_children():
			if c is GPUParticles3D:
				n += 1
			elif c.get("kind") == "missile" and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				fired += 1
		peak = maxi(peak, n)
	Controls.sim = {"always": 1.0}
	var pm_new: int = Fx._pm_cache.size() - pm0
	var dc_new: int = Fx._draw_cache.size() - dc0
	print("MISSILE fired=%d peak_particle_nodes=%d new_process_mats=%d new_draw_meshes=%d alive=%s" % [fired, peak, pm_new, dc_new, v.alive])
	f += _wcheck(fired >= 6, "missiles were fired (%d)" % fired)
	f += _wcheck(peak <= Fx.MAX_BURSTS + 40, "particle systems stay bounded (peak %d)" % peak)
	f += _wcheck(pm_new < 30 and dc_new < 30, "particle materials are reused (%d process, %d draw)" % [pm_new, dc_new])
	main.back_to_builder()
	await _frames(2)
	return f


func _builder_test() -> int:
	var f := 0
	var b: Node = main.builder
	b.load_design(Designs.empty_design())
	b.mirror = true
	b.set_block("cube")
	b.place(Vector3i(0, 0, -1))
	f += _check(b.cells.size() == 2, "center block placed once with mirror on")
	b.place(Vector3i(1, 0, 0))
	f += _check(b.cells.size() == 4 and b.cells.has(Vector3i(-1, 0, 0)), "mirror places the twin")
	b.set_block("thruster")
	b.rot_step = 90.0
	b.rotate_block(Vector3.UP)
	b.place(Vector3i(2, 0, 0))
	var r1: int = b.cells[Vector3i(2, 0, 0)].r
	var r2: int = b.cells[Vector3i(-2, 0, 0)].r
	var d1: Vector3 = Blocks.rots[r1] * Vector3.FORWARD
	var d2: Vector3 = Blocks.rots[r2] * Vector3.FORWARD
	f += _check(d1.is_equal_approx(Vector3(-d2.x, d2.y, d2.z)), "mirrored thruster points the mirrored way")
	b.undo()
	f += _check(b.cells.size() == 4, "undo removes the last placement")
	b.redo()
	f += _check(b.cells.size() == 6, "redo restores it")
	b.remove(Vector3i(0, 0, 0))
	f += _check(b.cells.has(Vector3i.ZERO), "seat can't be deleted")
	b.remove(Vector3i(1, 0, 0))
	var st: Dictionary = Designs.stats(b.to_design())
	f += _check(st.loose == 2, "removing a bridge leaves loose blocks flagged (%d)" % st.loose)
	b.paint_color = Color("#e53935")
	b.paint(Vector3i(0, 0, -1))
	f += _check(b.cells[Vector3i(0, 0, -1)].c == "e53935", "paint sets color")
	b.paint_color = null
	b.set_block("mg")
	b.place(Vector3i(0, 1, -1))
	b.set_cfg(Vector3i(0, 1, -1), "ch", "act1")
	var d: Dictionary = b.to_design()
	d.name = "zz selftest"
	Designs.save_design(d)
	var back := Designs.load_design("zz selftest")
	f += _check(back.get("blocks", []).size() == d.blocks.size(), "save/load roundtrip keeps blocks")
	var cfg_ok := false
	for blk in back.get("blocks", []):
		if blk.id == "mg" and blk.cfg.get("ch", "") == "act1":
			cfg_ok = true
	f += _check(cfg_ok, "save/load keeps key bindings")
	Designs.delete_design("zz selftest")
	f += _geometry_test()
	# drive every UI panel once so script errors surface in the log
	var ui: Node = main.bui
	for c in Blocks.CATS:
		ui._select_cat(c)
	b.set_tool("paint")
	b.set_tool("config")
	for cell in [Vector3i(0, 1, -1), Vector3i(2, 0, 0), Vector3i(0, 0, 0)]:
		if b.cells.has(cell):
			b._select(cell)
	b.load_design(Designs.presets()[0])
	for cell in b.cells:
		if b.cells[cell].id == "wheel":
			b._select(cell)
			break
	b.set_tool("build")
	ui._on_random()
	ui._fill_load_menu()
	main._set_paused(true)
	main._set_paused(false)
	var loose := 0
	for i in 200:
		loose += Designs.stats(Designs.random_design()).loose
	for p in Designs.presets():
		loose += Designs.stats(p).loose
	f += _check(loose == 0, "every preset and 200 random builds are fully connected")
	return f


## Flush placement on half blocks, 45 degree turns, resized blocks, and that a
## vehicle built from them stays in one piece with the right mass.
func _geometry_test() -> int:
	var f := 0
	var b: Node = main.builder
	b.load_design(Designs.empty_design())
	b.mirror = false
	b.set_block("half")
	b.place(Vector3i(0, 0, -1))
	b.set_block("cube")
	var t: Array = b.target_for(Vector3i(0, 0, -1), Vector3(0.2, 0.0, -1.1), Vector3.UP)
	f += _check((t[0] as Vector3).is_equal_approx(Vector3(0, 0.5, -1)), "block snaps flush on top of a half block (%s)" % t[0])
	b.place_at(t[0], t[1])
	b.set_block("half")
	b.rot = Blocks.rots[Blocks.rot_toward(Vector3.FORWARD, Vector3.RIGHT)]
	var ts: Array = b.target_for(Vector3i.ZERO, Vector3(0.5, 0, 0), Vector3.RIGHT)
	f += _check((ts[0] as Vector3).is_equal_approx(Vector3(1, 0, 0)), "sideways half block sits flush on a side (%s)" % ts[0])
	b.place_at(ts[0], ts[1])
	b.set_block("cube")
	var tw: Array = b.target_for(Vector3i(1, 0, 0), Vector3(1.0, 0.1, 0.1), Vector3.RIGHT)
	f += _check((tw[0] as Vector3).is_equal_approx(Vector3(1.5, 0, 0)), "block snaps flush onto a sideways half block (%s)" % tw[0])
	b.place_at(tw[0], tw[1])
	# 45 degrees, under the seat
	b.set_block("wedge")
	b.rot_step = 45.0
	b.rotate_block(Vector3.UP)
	f += _check(Blocks.grid_index(b.rot) < 0, "R turns 45 degrees")
	b.place(Vector3i(0, -1, 0))
	var tb: Dictionary = b.cells.get(Vector3i(0, -1, 0), {})
	f += _check(tb.has("q"), "45 degree block stores its free rotation")
	var bw := Blocks.basis_of(tb)
	var c45 := Vector3(0, -1, 0)
	var tn: Array = b.target_for(Vector3i(0, -1, 0), c45 + bw * Vector3(0.5, 0, 0), bw * Vector3.RIGHT)
	f += _check((tn[0] as Vector3).is_equal_approx(c45 + bw * Vector3.RIGHT) and (tn[1] as Basis).y.is_equal_approx(Vector3.UP)
		and absf((tn[1] as Basis).x.dot(bw.x)) > 0.99, "blocks attach flush and aligned to a 45 degree block (%s)" % tn[0])
	# resized blocks
	b.rot = Basis.IDENTITY
	b.set_block("cube")
	b.set_size(Vector3(3, 1, 1))
	var before: int = b.cells.size()
	var tr: Array = b.target_for(Vector3i.ZERO, Vector3(0.1, 0, 0.5), Vector3.BACK)
	b.place_at(tr[0], tr[1])
	f += _check(b.cells.size() == before + 1 and (tr[0] as Vector3).is_equal_approx(Vector3(0, 0, 1)), "3-wide block placed behind the seat (%s)" % tr[0])
	var lk := Vector3i(0, 0, 1)
	f += _check(Blocks.size_of(b.cells.get(lk, {"id": "cube", "p": [0, 0, 1]})).is_equal_approx(Vector3(3, 1, 1)), "placed block keeps its size")
	b.set_size(Vector3.ONE)
	var te: Array = b.target_for(lk, Vector3(1.4, 0.2, 1.5), Vector3.BACK)
	f += _check((te[0] as Vector3).is_equal_approx(Vector3(1, 0, 2)), "small block slides to the end of a long one (%s)" % te[0])
	b.place_at(te[0], te[1])
	var d: Dictionary = b.to_design()
	var st: Dictionary = Designs.stats(d)
	f += _check(st.loose == 0, "flush, turned and resized blocks all connect (%d loose)" % st.loose)
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))
	var v: RigidBody3D = preload("res://scripts/vehicle.gd").new()
	main.arena.add_child(v)
	v.build(back)
	f += _check(v.alive_count == d.blocks.size(), "vehicle keeps every block (%d/%d)" % [v.alive_count, d.blocks.size()])
	f += _check(absf(v.mass - st.mass) < 0.5, "resized blocks weigh more (vehicle %.0f, garage %.0f)" % [v.mass, st.mass])
	v.queue_free()
	b.mirror = true
	return f


func _sim(d: Dictionary) -> Dictionary:
	var kind := _kind(d)
	var loc: String = {"car": "desert", "plane": "runway", "heli": "desert", "boat": "sea", "barge": "desert", "walker": "desert"}[kind]
	main.builder.load_design(d, false)
	main.start_test(loc)
	var v: RigidBody3D = main.vehicle
	Controls.sim = {"always": 1.0}
	await _frames(45)
	var p0: Vector3 = v.com_world()
	var msg := ""
	var ok := true
	match kind:
		"car":
			Controls.sim = {"throttle": 1.0}
			await _frames(300)
			var spd := v.linear_velocity.length()
			var dist := Vector2(v.com_world().x - p0.x, v.com_world().z - p0.z).length()
			Controls.sim = {"throttle": 1.0, "steer": 1.0}
			await _frames(90)
			var yawrate := absf(v.angular_velocity.y)
			msg = "speed5s=%.1f dist=%.0f turn=%.2f up=%.2f" % [spd, dist, yawrate, _up(v)]
			ok = spd > 12.0 and dist > 30.0
		"plane":
			# a simple autopilot plays the role of the pilot: hold the runway
			# heading, rotate at speed, then hold a 12 degree climb wings-level
			var ground_y: float = p0.y
			var max_gain := 0.0
			var vmax := 0.0
			for i in 60 * 30:
				var f: Vector3 = -v.global_basis.z
				var right: Vector3 = v.global_basis.x
				var yaw_err := atan2(-f.x, -f.z)
				var pitch_ang := asin(clampf(f.y, -1.0, 1.0))
				var spd := v.linear_velocity.length()
				var target := deg_to_rad(12.0) if spd > 30.0 else 0.0
				Controls.sim = {
					"throttle": 1.0,
					"steer": clampf(yaw_err * 2.0, -1.0, 1.0),
					"pitch": clampf((target - pitch_ang) * 3.0, -1.0, 1.0),
					"roll": clampf(right.y * 3.0, -1.0, 1.0),
				}
				await _frames(1)
				if not v.alive:
					break
				max_gain = maxf(max_gain, v.com_world().y - ground_y)
				vmax = maxf(vmax, v.linear_velocity.length())
			msg = "vmax=%.1f climb=%.0f up=%.2f alive=%s" % [vmax, max_gain, _up(v), v.alive]
			ok = max_gain > 40.0 and v.alive
		"heli":
			Controls.sim = {"lift": 1.0}
			await _frames(240)
			var gain: float = v.com_world().y - p0.y
			Controls.sim = {}
			Controls.sim = {"always": 1.0}
			await _frames(180)
			var vy := v.linear_velocity.y
			Controls.sim = {"throttle": 1.0}
			await _frames(240)
			var hs := Vector2(v.linear_velocity.x, v.linear_velocity.z).length()
			msg = "climb4s=%.1f hover_vy=%.2f fwd=%.1f up=%.2f" % [gain, vy, hs, _up(v)]
			ok = gain > 10.0 and absf(vy) < 1.5 and hs > 5.0 and _up(v) > 0.8
		"boat":
			Controls.sim = {"throttle": 1.0}
			await _frames(600)
			var spd := v.linear_velocity.length()
			var y: float = v.com_world().y
			Controls.sim = {"throttle": 1.0, "steer": 1.0}
			await _frames(120)
			msg = "speed10s=%.1f y=%.2f turn=%.2f up=%.2f" % [spd, y, absf(v.angular_velocity.y), _up(v)]
			ok = spd > 8.0 and y > -1.5 and _up(v) > 0.6
		"barge":
			Controls.sim = {"lift": 1.0, "throttle": 1.0}
			await _frames(360)
			var gain: float = v.com_world().y - p0.y
			msg = "climb6s=%.1f up=%.2f" % [gain, _up(v)]
			ok = gain > 8.0 and _up(v) > 0.8
		"walker":
			var fwd0: Vector3 = -v.global_basis.z
			Controls.sim = {"throttle": 1.0}
			await _frames(600)
			var walked: float = (v.com_world() - p0).dot(fwd0)
			var spd := Vector2(v.linear_velocity.x, v.linear_velocity.z).length()
			var up_walk := _up(v)
			# sprint (Shift) on designs where Shift isn't a rocket pounce
			var run_spd := -1.0
			if not d.blocks.any(func(bb): return bb.id == "rocket"):
				Controls.sim = {"throttle": 1.0, "boost": 1.0}
				await _frames(120)
				var pr: Vector3 = v.com_world()
				await _frames(180)
				run_spd = Vector2(v.com_world().x - pr.x, v.com_world().z - pr.z).length() / 3.0
				up_walk = minf(up_walk, _up(v))
			var yaw0: Vector3 = -v.global_basis.z
			Controls.sim = {"steer": -1.0}
			var turned := 0.0
			for k in 240:
				await _frames(1)
				var yaw1: Vector3 = -v.global_basis.z
				turned += rad_to_deg(atan2(yaw0.cross(yaw1).y, yaw0.dot(yaw1)))
				yaw0 = yaw1
			var p1: Vector3 = v.com_world()
			Controls.sim = {"throttle": -1.0}
			await _frames(300)
			var back: float = -(v.com_world() - p1).dot(-v.global_basis.z)
			msg = "walk10s=%.1f spd=%.1f run=%.1f turnL4s=%.0fdeg back5s=%.1f up=%.2f/%.2f" % [walked, spd, run_spd, turned, back, up_walk, _up(v)]
			ok = walked > 10.0 and turned > 30.0 and back > 4.0 and up_walk > 0.85 and _up(v) > 0.85 and (run_spd < 0.0 or run_spd > walked / 10.0 * 1.3)
	# fire every weapon for a second
	Controls.sim = {"fire1": 1.0, "fire2": 1.0, "fire3": 1.0, "always": 1.0}
	await _frames(60)
	Controls.sim = {"always": 1.0}
	var lv: Vector3 = v.linear_velocity if v.alive else Vector3.ZERO
	if is_nan(lv.x) or lv.length() > 400.0:
		ok = false
		msg += " UNSTABLE"
	msg += " intact=%.2f" % v.intact()
	main.back_to_builder()
	await _frames(2)
	return {"ok": ok, "kind": kind, "msg": msg}


func _crash_test() -> void:
	for idx in [0, 2, 3]:
		var d: Dictionary = Designs.presets()[idx]
		main.builder.load_design(d, false)
		main.start_test("sky")
		var v: RigidBody3D = main.vehicle
		Controls.sim = {"always": 1.0}
		await _frames(60 * 9)
		print("CRASH drop %-18s intact=%.2f alive=%s" % [d.name, v.intact(), v.alive])
		main.back_to_builder()
		await _frames(2)
	# full-speed rocket car into the mesa wall
	main.builder.load_design(Designs.presets()[4], false)
	main.start_test("desert")
	var rc: RigidBody3D = main.vehicle
	rc.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), Vector3(-200, 12, -180))
	Controls.sim = {"throttle": 1.0, "boost": 1.0}
	await _frames(60 * 6)
	print("CRASH rocket car into mesa intact=%.2f alive=%s" % [rc.intact(), rc.alive])
	Controls.sim = {"always": 1.0}
	main.back_to_builder()
	await _frames(2)


## Spawns every block in the catalog (one test vehicle per category) and pulses
## every control channel, so each block's behaviour code runs at least once.
func _catalog_test() -> int:
	var f := 0
	print("CATALOG blocks=%d" % Blocks.order.size())
	for cat in Blocks.CATS:
		var ids := Blocks.ids_in(cat)
		var b := Designs.DB.new()
		var n := ids.size()
		for z in range(-1, n + 1):
			for x in range(-1, 2):
				b.add("cube", x, 0, z * 2)
				if z < n:
					b.add("cube", x, 0, z * 2 + 1)
		b.put("seat", 0, 0, -2)
		var k := 0
		for id in ids:
			if id == "seat":
				continue
			b.add(id, 0, 1, k * 2)
			k += 1
		for x in [-1, 1]:
			b.add("wheel", x * 2, 0, 0)
			b.add("wheel", x * 2, 0, n * 2)
		var d := b.done("CAT " + cat)
		main.builder.load_design(d, false)
		main.start_test("desert")
		var v: RigidBody3D = main.vehicle
		var seq := [{"throttle": 1.0, "always": 1.0}, {"lift": 1.0, "fire1": 1.0, "always": 1.0}, {"lift": -1.0, "fire2": 1.0, "steer": 1.0, "always": 1.0},
			{"act1": 1.0, "act2": 1.0, "act3": 1.0, "fire3": 1.0, "boost": 1.0, "always": 1.0}, {"pitch": 1.0, "roll": -1.0, "yaw": 1.0, "horn": 1.0, "always": 1.0},
			{"throttle": -1.0, "always": 1.0}]
		for st in seq:
			Controls.sim = st
			await _frames(30)
		Controls.sim = {"always": 1.0}
		await _frames(30)
		var lv: Vector3 = v.linear_velocity
		var ok := not is_nan(lv.x) and lv.length() < 400.0
		print("%s catalog %-11s blocks=%d intact=%.2f alive=%s" % ["PASS" if ok else "FAIL", cat, k, v.intact(), v.alive])
		if not ok:
			f += 1
		main.back_to_builder()
		await _frames(2)
	return f


## The submarine preset must sink with flooded tanks and come back up when blown.
func _dive_test() -> int:
	var d: Dictionary = Designs.presets()[15]
	main.builder.load_design(d, false)
	main.start_test("sea")
	var v: RigidBody3D = main.vehicle
	Controls.sim = {"lift": -1.0, "always": 1.0}
	await _frames(60 * 7)
	var low: float = v.com_world().y
	Controls.sim = {"lift": 1.0, "always": 1.0}
	await _frames(60 * 8)
	var up: float = v.com_world().y
	Controls.sim = {"always": 1.0}
	main.back_to_builder()
	await _frames(2)
	return _check(low < -3.0 and up > -1.0, "submarine dives (y=%.1f) and resurfaces (y=%.1f)" % [low, up])


## Pistons, hinges and rotators must carry what is attached to their output
## face, and a mechanism whose moving side touches the chassis stays jammed.
func _mech_test() -> int:
	var f := 0
	var b := Designs.DB.new()
	for z in range(-2, 3):
		for x in range(-1, 2):
			b.add("cube", x, 0, z)
	b.put("seat", 0, 0, 0)
	for x in [-2, 2]:
		b.add("wheel", x, 0, -2)
		b.add("wheel", x, 0, 2)
	b.add("piston", 0, 1, -2)
	b.add("cube", 0, 2, -2)
	b.add("servo", 1, 1, 2, 0, "", {"ch": "pitch", "inv": false, "pow": 100, "mode": "hold"})
	b.add("cube", 1, 2, 2)
	b.add("spinner", -1, 1, 2)
	b.add("wedge", -1, 2, 2)
	b.add("piston", 0, 1, 0)        # its top block also touches the seat's neighbour: jammed
	b.add("cube", 0, 2, 0)
	b.add("cube", 0, 2, 1)
	b.add("cube", 0, 1, 1)
	var d := b.done("MECH test")
	main.builder.load_design(d, false)
	main.start_test("desert")
	var v: RigidBody3D = main.vehicle
	var idx := func(c: Vector3i) -> Dictionary: return v.parts[v.by_cell[c]]
	Controls.sim = {"always": 1.0}
	await _frames(30)
	Controls.sim = {"lift": 1.0, "pitch": 1.0, "yaw": 1.0, "always": 1.0}
	await _frames(90)
	var top: Dictionary = idx.call(Vector3i(0, 2, -2))
	var hinged: Dictionary = idx.call(Vector3i(1, 2, 2))
	var spun: Dictionary = idx.call(Vector3i(-1, 2, 2))
	var jam: Dictionary = idx.call(Vector3i(0, 2, 0))
	f += _check(absf(top.pos.y - 4.0) < 0.15, "piston lifts its block 2 up (y=%.2f)" % top.pos.y)
	f += _check(hinged.pos.distance_to(Vector3(1, 2, 2)) > 0.5, "servo swings its block (moved %.2f)" % hinged.pos.distance_to(Vector3(1, 2, 2)))
	f += _check(spun.basis.z.distance_to(Vector3.BACK) > 0.3, "spinner turns its block")
	f += _check(jam.pos.is_equal_approx(Vector3(0, 2, 0)), "jammed piston does not move")
	Controls.sim = {"always": 1.0}
	await _frames(90)
	f += _check(absf(top.pos.y - 2.0) < 0.15, "return-mode piston retracts on release (y=%.2f)" % top.pos.y)
	f += _check(hinged.pos.distance_to(Vector3(1, 2, 2)) > 0.5, "hold-mode servo keeps its angle")
	f += _check(Designs.mech_status(d.blocks, Vector3i(0, 1, -2)) == 1 and Designs.mech_status(d.blocks, Vector3i(0, 1, 0)) == -1, "builder reports moved/jammed")
	main.back_to_builder()
	await _frames(2)
	return f


func _tnt_test() -> void:
	var d: Dictionary = Designs.presets()[3]
	main.builder.load_design(d, false)
	main.start_test("desert")
	var v: RigidBody3D = main.vehicle
	Controls.sim = {"always": 1.0}
	await _frames(30)
	Controls.sim = {"always": 1.0, "act4": 1.0}
	await _frames(30)
	Controls.sim = {"always": 1.0}
	print("TNT test: intact=%.2f alive=%s" % [v.intact(), v.alive])
	main.back_to_builder()
	await _frames(2)


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	FileAccess.open(ProjectSettings.globalize_path("res://tools/out/.gdignore"), FileAccess.WRITE).store_string("")
	var path := ProjectSettings.globalize_path("res://tools/out/%s.png" % nm)
	img.save_png(path)
	print("SHOT ", path)


func _process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shots() -> void:
	var p: Array = Designs.presets()
	main.builder.load_design(p[6], false)
	await _process_frames(40)
	await _shot("01_garage_jet")
	main.builder.set_tool("config")
	main.builder._select(Vector3i(0, 0, 3))
	await _process_frames(10)
	await _shot("02_garage_config")
	main.builder.load_design(p[1], false)
	main.start_test("desert")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(100)
	Controls.sim = {"throttle": 1.0, "fire1": 1.0, "always": 1.0}
	await _frames(20)
	await _shot("03_desert_buggy")
	Controls.sim = {}
	main.back_to_builder()
	main.builder.load_design(p[10], false)
	main.start_test("sea")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(240)
	await _shot("04_sea_gunboat")
	main.back_to_builder()
	main.builder.load_design(p[6], false)
	main.start_test("sky")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(120)
	await _shot("05_sky_jet")
	Controls.sim = {"throttle": 1.0, "fire2": 1.0, "always": 1.0}
	await _frames(40)
	await _shot("06_sky_rockets")
	main.back_to_builder()
	main.builder.load_design(p[8], false)
	main.start_test("desert")
	Controls.sim = {"lift": 1.0, "always": 1.0}
	await _frames(150)
	await _shot("07_chopper")
	Controls.sim = {}
	main.back_to_builder()
	# mechanisms and the new parts
	main.builder.load_design(p[12], false)
	main.bui._select_cat("Mechanical")
	await _process_frames(30)
	await _shot("08_garage_crane")
	main.start_test("desert")
	Controls.sim = {"lift": 1.0, "pitch": 1.0, "yaw": 1.0, "act3": 1.0, "always": 1.0}
	await _frames(150)
	await _shot("09_crane_arm")
	main.back_to_builder()
	main.builder.load_design(p[13], false)
	main.start_test("desert")
	Controls.sim = {"lift": 1.0, "always": 1.0}
	await _frames(90)
	await _shot("10_lowrider_up")
	main.back_to_builder()
	main.builder.load_design(p[14], false)
	main.start_test("sea")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(180)
	await _shot("11_hover_sea")
	main.back_to_builder()
	main.builder.load_design(p[15], false)
	main.start_test("sea")
	Controls.sim = {"throttle": 1.0, "lift": -1.0, "always": 1.0}
	await _frames(240)
	await _shot("12_sub_dive")
	Controls.sim = {}
	main.back_to_builder()
	main.builder.load_design(p[16], false)
	await _process_frames(40)
	await _shot("13_garage_spider")
	main.start_test("desert")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(200)
	await _shot("14_spider_walk")
	Controls.sim = {"throttle": 1.0, "fire1": 1.0, "fire3": 1.0, "always": 1.0}
	await _frames(40)
	await _shot("15_spider_fire")
	Controls.sim = {"boost": 1.0, "always": 1.0}
	await _frames(70)
	await _shot("16_spider_pounce")
	Controls.sim = {}
	main.back_to_builder()
	main.builder.load_design(p[17], false)
	main.start_test("desert")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(150)
	await _shot("17_mech_walk")
	Controls.sim = {"throttle": 1.0, "boost": 1.0, "always": 1.0}
	await _frames(100)
	await _shot("18_mech_sprint")
	main.back_to_builder()
	main.builder.load_design(p[18], false)
	main.start_test("sky")
	Controls.sim = {"throttle": 1.0, "boost": 1.0, "always": 1.0}
	await _frames(120)
	await _shot("19_blackbird")
	main.back_to_builder()
	main.builder.load_design(p[19], false)
	main.start_test("sea")
	Controls.sim = {"throttle": 1.0, "boost": 1.0, "always": 1.0}
	await _frames(300)
	await _shot("20_speedboat")
	Controls.sim = {}
	main.back_to_builder()


## Screenshots of the race track, the carrier and the test zone
## (windowed: `-- --shots --worldshots`).
func _world_shots() -> void:
	var p: Array = Designs.presets()
	await _process_frames(20)
	await _shot("20b_garage_bar")
	main.builder.load_design(p[4], false)
	main.start_test("track")
	Controls.sim = {"always": 1.0}
	await _frames(60)
	await _shot("21_track_start")
	Controls.sim = {"throttle": 1.0, "always": 1.0}
	await _frames(240)
	await _shot("22_track_drive")
	main.back_to_builder()
	main.builder.load_design(p[6], false)
	main.start_test("carrier")
	Controls.sim = {"always": 1.0}
	main.cam_dist = 60.0
	main.cam_pitch = -0.35
	await _frames(60)
	await _shot("23_carrier_deck")
	main.cam_yaw = PI * 0.8
	main.cam_dist = 80.0
	await _frames(30)
	await _shot("24_carrier_side")
	main.back_to_builder()
	main.builder.load_design(p[17], false)
	main.start_test("testzone")
	Controls.sim = {"always": 1.0}
	await _frames(60)
	await _shot("25_test_zone")
	Controls.sim = {"always": 1.0, "fire2": 1.0}
	await _frames(90)
	await _shot("26_test_zone_missiles")
	Controls.sim = {}
	main.back_to_builder()
