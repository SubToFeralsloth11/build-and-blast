extends Node
## Developer harness. Run headless with:
##   godot --headless --fixed-fps 60 --path . -- --simtest
## to drive every preset (and random builds) through scripted inputs and print
## physics results, or windowed with `-- --shots` to save screenshots.

var main: Node


func run(m: Node, args: PackedStringArray) -> void:
	main = m
	await _frames(5)
	if "--simtest" in args:
		await _simtest(args)
	else:
		await _shots()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _kind(d: Dictionary) -> String:
	var wings := 0
	for b in d.blocks:
		match b.id:
			"rotor":
				return "heli"
			"boatprop":
				return "boat"
			"balloon":
				return "barge"
			"wing":
				wings += 1
	return "plane" if wings >= 6 else "car"


func _up(v: Node) -> float:
	return v.global_basis.y.y


func _simtest(args: PackedStringArray) -> void:
	var list: Array = Designs.presets()
	var n_random := 14
	for a in args:
		if a.begins_with("--random="):
			n_random = int(a.substr(9))
	for i in n_random:
		var r: Dictionary = Designs.random_design()
		r.name = "RANDOM %d %s" % [i, r.name]
		list.append(r)
	var fails := 0
	for d in list:
		var res: Dictionary = await _sim(d)
		var ok: bool = res.ok
		if not ok:
			fails += 1
		print("%s %-34s %-6s %s" % ["PASS" if ok else "FAIL", d.name, res.kind, res.msg])
	await _tnt_test()
	print("SIMTEST DONE fails=%d" % fails)


func _sim(d: Dictionary) -> Dictionary:
	var kind := _kind(d)
	var loc: String = {"car": "desert", "plane": "runway", "heli": "desert", "boat": "sea", "barge": "desert"}[kind]
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
			Controls.sim = {"throttle": 1.0}
			var ground_y: float = p0.y
			var max_gain := 0.0
			var vmax := 0.0
			for i in 60 * 30:
				if i == 60 * 14:
					Controls.sim = {"throttle": 1.0, "pitch": 0.7}
				if i == 60 * 17:
					Controls.sim = {"throttle": 1.0, "pitch": 0.15}
				await get_tree().physics_frame
				if not v.alive:
					break
				max_gain = maxf(max_gain, v.com_world().y - ground_y)
				vmax = maxf(vmax, v.linear_velocity.length())
			msg = "vmax=%.1f climb=%.0f up=%.2f alive=%s" % [vmax, max_gain, _up(v), v.alive]
			ok = max_gain > 25.0 and v.alive
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
