extends RigidBody3D
## A drivable vehicle assembled from a design: one rigid body, one collider and
## visual per block. Blocks are simulated individually (wheels, thrust, aero,
## buoyancy, weapons) and can be shot off.

signal wrecked

const FWD := Vector3(0, 0, -1)
const NEIGHBORS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const WHEEL_VMAX := 46.0
const WHEEL_VREV := 16.0

var design := {}
var parts: Array = []
var by_cell := {}
var seat_idx := -1
var alive := true
var aim_point := Vector3.INF
var com_local := Vector3.ZERO
var extent2 := 1.0
var wheel_count := 0
var rotor_count := 0
var start_count := 0
var alive_count := 0
var activity := 0.0
var grounded := 0
var _dirty_split := false
var _rids: Array[RID] = []
var _engine: AudioStreamPlayer3D
var _laser_snd: AudioStreamPlayer3D
var _flame_snd: AudioStreamPlayer3D
var _jet_snd: AudioStreamPlayer3D


func build(d: Dictionary) -> void:
	design = d
	collision_layer = Fx.L_VEHICLE
	collision_mask = Fx.L_WORLD | Fx.L_VEHICLE | Fx.L_PROPS | Fx.L_TARGET
	continuous_cd = true
	# the project default damping (0.1) would act like a hidden brake
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.05
	physics_material_override = pm
	add_to_group("damageable")
	add_to_group("vehicle")
	_rids = [get_rid()]
	for b in d.get("blocks", []):
		var def := Blocks.get_def(b.id)
		if def.is_empty():
			continue
		var cell := Vector3i(int(b.p[0]), int(b.p[1]), int(b.p[2]))
		if by_cell.has(cell):
			continue
		var basis := Basis.IDENTITY if def.auto_rot else Blocks.rots[clampi(int(b.get("r", 0)), 0, 23)]
		var cs: String = b.get("c", "")
		var col: Color = Color(cs) if cs != "" else def.color
		var cfg: Dictionary = def.cfg.duplicate()
		cfg.merge(b.get("cfg", {}), true)
		var pos := Vector3(cell)
		var vis := Blocks.make_visual(b.id, col)
		vis.transform = Transform3D(basis, pos)
		add_child(vis)
		var sh := Blocks.shape_for(b.id)
		var col_shape := CollisionShape3D.new()
		col_shape.shape = sh[0]
		col_shape.transform = Transform3D(basis, pos) * sh[1]
		col_shape.set_meta("pi", parts.size())
		add_child(col_shape)
		var p := {
			"id": b.id, "def": def, "cell": cell, "basis": basis, "pos": pos, "color": col,
			"cfg": cfg, "hp": float(def.hp), "alive": true, "node": vis, "shape": col_shape,
			"st": {"cd": randf() * 0.1, "fl": 0.0, "spin": 0.0, "side": 0},
		}
		for nm in ["spin", "flame", "flap", "canopy", "beam", "particles", "lamp", "field", "led", "yaw", "recoil", "bomb", "coil"]:
			var n := vis.get_node_or_null(nm)
			if n:
				p[nm] = n
		if vis.get_node_or_null("yaw/pitch"):
			p["pitch"] = vis.get_node("yaw/pitch")
		if def.has("radius"):
			p["dust"] = _emitter(pos + Vector3(0, -def.radius, 0.3), Color("#d8b98c"))
		elif b.id == "boatprop":
			p["dust"] = _emitter(pos + Vector3(0, 0, 0.8), Color(0.9, 0.97, 1.0))
		if b.id == "seat" and seat_idx < 0:
			seat_idx = parts.size()
		by_cell[cell] = parts.size()
		parts.append(p)
	start_count = parts.size()
	_split_disconnected()
	_recompute()
	_engine = Sfx.loop_player("engine", self)
	_laser_snd = Sfx.loop_player("laser", self)
	_flame_snd = Sfx.loop_player("flame", self)
	_jet_snd = Sfx.loop_player("jet", self)


func _emitter(pos: Vector3, col: Color) -> GPUParticles3D:
	var e := Blocks._particles(self, "fx", pos, Vector3(0, 1, 0.6), col, false)
	e.amount = 24
	e.lifetime = 1.4
	return e


func _recompute() -> void:
	var m := 0.0
	var c := Vector3.ZERO
	wheel_count = 0
	rotor_count = 0
	alive_count = 0
	for p in parts:
		if not p.alive:
			continue
		alive_count += 1
		m += p.def.mass
		c += p.pos * p.def.mass
		if p.id == "wheel" or p.id == "bigwheel":
			wheel_count += 1
		elif p.id == "rotor":
			rotor_count += 1
	if m <= 0.0:
		return
	com_local = c / m
	mass = m
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com_local
	var ix := 0.0
	var iy := 0.0
	var iz := 0.0
	var e := 0.0
	for p in parts:
		if not p.alive:
			continue
		var r: Vector3 = p.pos - com_local
		var pm: float = p.def.mass
		ix += pm * (r.y * r.y + r.z * r.z + 0.17)
		iy += pm * (r.x * r.x + r.z * r.z + 0.17)
		iz += pm * (r.x * r.x + r.y * r.y + 0.17)
		e += r.length_squared() * pm
	inertia = Vector3(ix, iy, iz)
	extent2 = maxf(1.0, e / m)


func com_world() -> Vector3:
	return global_transform * com_local


func _pv(wp: Vector3, com_w: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(wp - com_w)


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _dirty_split:
		_dirty_split = false
		_split_disconnected()
		_recompute()
		if not alive:
			return
	var gb := global_basis
	var gpos := global_position
	var com_w := com_world()
	var lv := linear_velocity
	var speed := lv.length()
	var space := get_world_3d().direct_space_state
	var thr := Controls.value("throttle")
	var steer := Controls.value("steer")
	var pitch := Controls.value("pitch")
	var roll := Controls.value("roll")
	var yaw_total := clampf(Controls.value("yaw") + steer, -1.0, 1.0)
	var want_torque := Vector3(pitch, -yaw_total, -roll)
	var act := 0.0
	var jet_act := 0.0
	var laser_on := false
	var flame_on := false
	grounded = 0
	for i in parts.size():
		var p: Dictionary = parts[i]
		if not p.alive:
			continue
		var wp: Vector3 = global_transform * p.pos
		var off := wp - gpos
		# buoyancy + water drag for every block
		var depth := Fx.WATER - (wp.y - 0.5)
		if depth > 0.0:
			var sub := minf(depth, 1.0)
			# hull contact: even a shallow draft gets full planing drag
			var wet := minf(depth * 4.0, 1.0)
			var v := _pv(wp, com_w)
			var vh := Vector3(v.x, 0.0, v.z)
			var drag := -vh * (vh.length() * 1.2 + 10.0) * wet - Vector3(0.0, v.y, 0.0) * (v.length() * 4.0 + 90.0) * wet
			apply_force(Vector3.UP * sub * 9800.0 * p.def.buoy + drag, off)
		var cfg: Dictionary = p.cfg
		var pw: float = cfg.get("pow", 100) / 100.0
		var ch: String = cfg.get("ch", "always")
		var inv: bool = cfg.get("inv", false)
		var input := Controls.value(ch) * (-1.0 if inv else 1.0)
		match p.id:
			"wheel", "bigwheel":
				_wheel(p, wp, gb, com_w, space, thr, steer, speed, delta)
			"thruster", "jet", "rocket", "prop", "boatprop":
				var amt := clampf(input, -0.5 if p.id == "boatprop" else 0.0, 1.0)
				var medium: String = p.def.get("medium", "any")
				if medium == "air" and wp.y < Fx.WATER + 0.1:
					amt = 0.0
				elif medium == "water" and wp.y > Fx.WATER - 0.05:
					amt = 0.0
				var t: float = p.def.thrust * pw * amt
				var dir: Vector3 = gb * (p.basis * FWD)
				if p.id == "prop":
					t *= 1.0 - clampf(lv.dot(dir) / 95.0, 0.0, 0.85)
				if absf(t) > 0.0:
					if p.id == "boatprop":
						# push at the hull's height so boats don't backflip
						var rel := wp - com_w
						apply_force(dir * t, com_w + rel - gb.y * rel.dot(gb.y) * 0.85 - gpos)
					else:
						apply_force(dir * t, off)
				act += absf(amt) * (2.0 if p.id == "rocket" else 1.0)
				if p.id == "jet" or p.id == "rocket":
					jet_act += absf(amt)
				p.st.fl = lerpf(p.st.fl, absf(amt), 0.25)
				if p.has("dust"):
					p.dust.emitting = absf(amt) > 0.1
				if p.has("flame"):
					var fl: Node3D = p.flame
					fl.visible = p.st.fl > 0.03
					fl.scale.z = maxf(0.001, p.st.fl * p.def.get("flame", 1.0) * randf_range(0.8, 1.15))
				if p.has("spin"):
					p.spin.rotate_object_local(Vector3.BACK, (6.0 + p.st.fl * 40.0) * delta * signf(amt + 0.001))
			"rotor":
				_rotor(p, wp, off, gb, lv, input, pw, delta, thr)
				act += 0.7
			"balloon":
				if wp.y < 700.0 and input > 0.5:
					apply_force(Vector3.UP * p.def.lift * pw, off)
			"wing", "flap":
				_aero(p, wp, off, gb, com_w, want_torque, pw)
			"gyro":
				_gyro(p, gb, want_torque, pitch, roll, pw, delta)
			"parachute":
				var open := input > 0.5 and speed > 2.0 and wp.y > Fx.WATER - 0.5
				var cn: Node3D = p.canopy
				if open and not cn.visible:
					Sfx.play("pop", wp, -4.0, 0.6)
				cn.visible = open
				if open:
					var vdir := lv.normalized()
					var f := -vdir * minf(speed * speed * 70.0 * pw, mass * 28.0)
					apply_force(f, off)
					cn.global_basis = Basis(Quaternion(Vector3.UP, -vdir)).orthonormalized()
			"magnet":
				var on := input > 0.5
				p.field.visible = on
				if on:
					_magnet(wp, off, pw)
			"tnt":
				p.st.cd -= delta
				if p.st.cd <= 0.0:
					p.st.cd = 0.6
					p.led.visible = not p.led.visible
				if Controls.just(ch):
					destroy_part(i)
			"jump":
				p.st.cd -= delta
				if input > 0.5 and Controls.just(ch) and p.st.cd <= 0.0:
					p.st.cd = 1.4
					var up: Vector3 = gb * (p.basis * Vector3.UP)
					apply_impulse(up * mass * 7.5 * pw, off)
					Sfx.play("jump", wp, 0.0)
					Fx.burst(wp - up * 0.5, Color(0.9, 0.85, 0.7, 0.8), 14, 5.0, 0.3, 0.8, Vector3(0, -4, 0), 80.0, -up, false)
					var coil: Node3D = p.coil
					coil.scale = Vector3(1, 1.8, 1)
					coil.position = -Vector3.UP * 0.3
					var tw := coil.create_tween().set_parallel()
					tw.tween_property(coil, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tw.tween_property(coil, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			"smoke":
				p.particles.emitting = input > 0.5
			"light":
				p.lamp.visible = input > 0.5
			"horn":
				if Controls.just(ch):
					Sfx.play("horn", wp, 4.0)
			"mg", "cannon", "rockets", "laser", "flamer", "bombs", "turret":
				p.st.cd -= delta
				var firing := input > 0.5
				if p.id == "laser":
					laser_on = _laser(p, wp, gb, firing, delta) or laser_on
				elif p.id == "flamer":
					var pt: GPUParticles3D = p.particles
					pt.emitting = firing
					if firing:
						flame_on = true
						var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, 0, -0.7))
						Fx.cone_damage(mz, gb * (p.basis * FWD), 11.0, 70.0 * delta * pw, _rids)
				elif p.id == "turret":
					_turret(p, wp, firing, delta, pw)
				elif firing and p.st.cd <= 0.0:
					_fire(p, gb, pw)
	# air drag
	if speed > 0.1:
		apply_central_force(-lv * speed * 0.0045 * alive_count)
	activity = lerpf(activity, clampf(act / 3.0 + absf(thr) * 0.6, 0.0, 1.0), 0.1)
	_engine.volume_db = lerpf(-28.0, -6.0, activity) if activity > 0.02 else -60.0
	_engine.pitch_scale = clampf(0.6 + activity * 0.5 + speed / 60.0, 0.5, 2.6)
	_jet_snd.volume_db = -60.0 if jet_act < 0.05 else lerpf(-18.0, 0.0, clampf(jet_act, 0.0, 1.0))
	_jet_snd.pitch_scale = 0.8 + clampf(speed / 120.0, 0.0, 0.8)
	_laser_snd.volume_db = -6.0 if laser_on else -80.0
	_flame_snd.volume_db = -4.0 if flame_on else -80.0


func _wheel(p: Dictionary, wp: Vector3, gb: Basis, com_w: Vector3, space: PhysicsDirectSpaceState3D, thr: float, steer: float, speed: float, delta: float) -> void:
	var up := gb.y
	var rad: float = p.def.radius
	var travel: float = p.def.travel
	var ray_len := rad + travel
	var cfg: Dictionary = p.cfg
	var sgn := 0.0
	match cfg.get("steer", "auto"):
		"auto":
			sgn = 1.0 if p.pos.z < com_local.z - 0.6 else (-0.35 if p.pos.z > com_local.z + 2.5 else 0.0)
		"on":
			sgn = 1.0
		"inv":
			sgn = -1.0
	var ang := -steer * sgn * deg_to_rad(34.0) / (1.0 + speed / 24.0)
	var q := PhysicsRayQueryParameters3D.create(wp, wp - up * ray_len, Fx.L_WORLD | Fx.L_PROPS | Fx.L_TARGET, _rids)
	var h := space.intersect_ray(q)
	var dist := ray_len
	var vf := 0.0
	if not h.is_empty():
		dist = wp.distance_to(h.position)
		var comp := ray_len - dist
		var v := _pv(h.position, com_w)
		var share := mass / maxf(1.0, wheel_count)
		var k := share * 9.8 / (travel * 0.5)
		var c := 2.0 * sqrt(k * share) * 0.45
		var load := clampf(k * comp - c * v.dot(up), 0.0, mass * 40.0)
		var n: Vector3 = h.normal
		apply_force(up * load, h.position - global_position)
		var fwd := (gb * FWD).rotated(up, ang)
		var side := fwd.cross(up)
		var fg := (fwd - n * fwd.dot(n)).normalized()
		var sg := (side - n * side.dot(n)).normalized()
		vf = v.dot(fg)
		var vs := v.dot(sg)
		var lat := -vs * share / delta * 0.32
		var lon := 0.0
		if (thr > 0.05 and vf < -0.8) or (thr < -0.05 and vf > 0.8):
			lon = -signf(vf) * share * 12.0 * absf(thr)
		elif cfg.get("drive", true) and absf(thr) > 0.05:
			var dp: float = p.def.drive * cfg.get("pow", 100) / 100.0
			var lim := WHEEL_VMAX if thr > 0.0 else WHEEL_VREV
			lon = dp * thr * clampf(1.0 - absf(vf) / lim, 0.0, 1.0)
		lon -= vf * share * 0.015
		if absf(thr) < 0.05 and absf(vf) < 2.0:
			lon -= vf * share / delta * 0.25
		var f := sg * lat + fg * lon
		var grip := load * 1.3
		if f.length() > grip:
			f = f.normalized() * grip
		apply_force(f, h.position + up * rad * 0.6 - global_position)
		grounded += 1
		p.dust.emitting = absf(vf) > 7.0 and h.collider is StaticBody3D and h.position.y > 1.0
	else:
		p.dust.emitting = false
	p.st.spin += vf / rad * delta
	var node: Node3D = p.node
	node.transform = Transform3D(Basis(Vector3.UP, ang), p.pos + Vector3(0, -(dist - rad), 0))
	p.spin.rotation.x = -p.st.spin


func _rotor(p: Dictionary, wp: Vector3, off: Vector3, gb: Basis, lv: Vector3, input: float, pw: float, delta: float, thr: float) -> void:
	# W/S tilts the rotor disc so helicopters fly forward without nosing over
	var up_r: Vector3 = (gb * (p.basis * Vector3.UP) + gb * FWD * thr * 0.4).normalized()
	var share := mass / maxf(1.0, rotor_count)
	var target_vs := input * 9.0
	var want := share * 9.8 / maxf(up_r.y, 0.35) + (target_vs - lv.y) * share * 2.2
	var t := clampf(want, 0.0, p.def.thrust * pw)
	if wp.y < Fx.WATER + 0.3 or up_r.y < 0.0:
		t = 0.0 if wp.y < Fx.WATER + 0.3 else t * 0.3
	apply_force(up_r * t, off)
	p.spin.rotate_object_local(Vector3.UP, (18.0 + t / maxf(share, 1.0) * 0.5) * delta)


func _aero(p: Dictionary, wp: Vector3, off: Vector3, gb: Basis, com_w: Vector3, want_torque: Vector3, pw: float) -> void:
	var v := _pv(wp, com_w)
	var sp := v.length()
	var deflect := 0.0
	if p.id == "flap":
		var r: Vector3 = p.pos - com_local
		var a := r.cross(p.basis * Vector3.UP)
		var al := a.length()
		if al > 0.3:
			deflect = clampf(a.dot(want_torque) / al * 1.4, -1.0, 1.0)
		var fl: Node3D = p.flap
		fl.rotation.x = lerpf(fl.rotation.x, deflect * 0.5, 0.2)
	if sp < 0.5:
		return
	var n: Vector3 = gb * (p.basis * Vector3.UP)
	var chord: Vector3 = gb * (p.basis * FWD)
	var dens := 1.0 if wp.y > Fx.WATER else 6.0
	var vn := v.dot(n)
	var vc := v.dot(chord)
	var f: Vector3 = -n * vn * sp * 2.6
	if p.id == "wing" and vc > 0.0:
		f += n * 0.26 * vc * vc
	if p.id == "flap":
		f += n * deflect * 1.4 * vc * absf(vc) * pw
	f *= dens
	if f.length() > 30000.0:
		f = f.normalized() * 30000.0
	apply_force(f, off)


func _gyro(p: Dictionary, gb: Basis, want_torque: Vector3, pitch: float, roll: float, pw: float, delta: float) -> void:
	var s := pw * mass * extent2
	var lev_l := gb.inverse() * gb.y.cross(Vector3.UP)
	lev_l.x *= 1.0 - absf(pitch)
	lev_l.z *= 1.0 - absf(roll)
	var t := gb * (want_torque * 3.0 * s) + gb * lev_l * 9.0 * s - angular_velocity * 2.5 * s
	apply_torque(t)
	p.spin.rotate_object_local(Vector3(0.3, 1, 0.2).normalized(), 9.0 * delta)


func _magnet(wp: Vector3, off: Vector3, pw: float) -> void:
	for b in get_tree().get_nodes_in_group("magnetic"):
		if not is_instance_valid(b) or b == self or not (b is RigidBody3D):
			continue
		var d: Vector3 = wp - b.global_position
		var dl := d.length()
		if dl > 18.0 or dl < 0.1:
			continue
		var f := d / dl * minf(b.mass, 300.0) * 32.0 * pw * (1.0 - dl / 20.0)
		if dl < 2.2:
			b.linear_velocity = b.linear_velocity.lerp(linear_velocity, 0.25)
		b.sleeping = false
		b.apply_central_force(f)
		apply_force(-f * 0.5, off)


func _aim_dir(p: Dictionary, gb: Basis, muzzle_local: Vector3) -> Array:
	var mz: Vector3 = global_transform * (p.pos + p.basis * muzzle_local)
	var dir: Vector3 = gb * (p.basis * FWD)
	if aim_point != Vector3.INF:
		var to := (aim_point - mz).normalized()
		if dir.angle_to(to) < deg_to_rad(15.0):
			dir = to
	return [mz, dir]


func _fire(p: Dictionary, gb: Basis, pw: float) -> void:
	match p.id:
		"mg":
			p.st.cd = 0.07
			var a := _aim_dir(p, gb, Vector3(0, -0.06, -1.1))
			var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012
			Fx.hitscan(a[0], (a[1] + spread).normalized(), 600.0, 9.0 * pw, _rids)
			Fx.muzzle_flash(a[0], a[1], 0.8)
			Sfx.play("mg", a[0], -6.0)
		"cannon":
			p.st.cd = 1.1
			var a := _aim_dir(p, gb, Vector3(0, -0.02, -1.5))
			Fx.spawn_projectile("shell", a[0], a[1] * 190.0 + linear_velocity, _rids)
			apply_impulse(-a[1] * 1100.0 * pw, a[0] - global_position)
			Fx.muzzle_flash(a[0], a[1], 2.5)
			Fx.burst(a[0], Color(0.6, 0.6, 0.6, 0.6), 10, 3.0, 0.5, 1.5, Vector3(0, 1, 0), 30.0, a[1], false)
			Sfx.play("cannon", a[0], 0.0)
			var rc: Node3D = p.recoil
			rc.position.z = 0.4
			rc.create_tween().tween_property(rc, "position:z", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"rockets":
			p.st.cd = 0.32
			p.st.side = (int(p.st.side) + 1) % 4
			var ox := -0.2 if p.st.side % 2 == 0 else 0.2
			var oy := -0.2 if p.st.side < 2 else 0.2
			var a := _aim_dir(p, gb, Vector3(ox, oy, -0.7))
			Fx.spawn_projectile("rocket", a[0], a[1] * 45.0 + linear_velocity, _rids, aim_point)
			Sfx.play("rocket", a[0], -2.0)
		"bombs":
			p.st.cd = 1.3
			var down := -gb.y
			var bp: Vector3 = global_transform * (p.pos + Vector3(0, -0.7, 0))
			var proj := Fx.spawn_projectile("bomb", bp, linear_velocity + down * 3.0, _rids)
			proj.global_basis = gb * p.basis
			var bn: Node3D = p.bomb
			bn.visible = false
			get_tree().create_timer(1.1).timeout.connect(bn.show)
			Sfx.play("pop", bp, -2.0, 0.5)


func _laser(p: Dictionary, wp: Vector3, gb: Basis, firing: bool, delta: float) -> bool:
	var beam: Node3D = p.beam
	beam.visible = firing
	if not firing:
		return false
	var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, -0.05, -0.65))
	var dir: Vector3 = gb * (p.basis * FWD)
	var q := PhysicsRayQueryParameters3D.create(mz, mz + dir * 350.0, Fx.MASK_SHOT, _rids)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	var len := 350.0
	if not h.is_empty():
		len = mz.distance_to(h.position)
		var c = h.collider
		var pw: float = p.cfg.get("pow", 100) / 100.0
		if c.has_method("take_hit"):
			c.take_hit(85.0 * delta * pw, h.position, h.shape, dir * 0.05)
		if randf() < 0.5:
			Fx.burst(h.position, Color(1.0, 0.3, 0.3), 3, 5.0, 0.06, 0.3, Vector3(0, -8, 0), 70.0, h.normal, true)
	beam.scale = Vector3(1.0 + randf() * 0.3, 1.0 + randf() * 0.3, len)
	return true


func _turret(p: Dictionary, wp: Vector3, firing: bool, delta: float, pw: float) -> void:
	var yaw: Node3D = p.yaw
	var pt: Node3D = p.pitch
	if aim_point != Vector3.INF:
		var frame: Basis = global_basis * p.basis
		var lt: Vector3 = frame.inverse() * (aim_point - yaw.global_position)
		var want_yaw := atan2(-lt.x, -lt.z)
		var want_pitch := clampf(atan2(lt.y, Vector2(lt.x, lt.z).length()), -0.35, 1.35)
		yaw.rotation.y = rotate_toward(yaw.rotation.y, want_yaw, 5.0 * delta)
		pt.rotation.x = move_toward(pt.rotation.x, want_pitch, 4.0 * delta)
	if firing and p.st.cd <= 0.0:
		p.st.cd = 0.085
		p.st.side = 1 - int(p.st.side)
		var mz := pt.global_transform * Vector3(-0.13 if p.st.side == 0 else 0.13, 0, -1.05)
		var dir := -pt.global_basis.z
		var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.01
		Fx.hitscan(mz, (dir + spread).normalized(), 600.0, 7.0 * pw, _rids, Color("#9dff7a"))
		Fx.muzzle_flash(mz, dir, 0.7)
		Sfx.play("mg", mz, -8.0, 1.2)


# ---------------------------------------------------------------- damage

func take_hit(dmg: float, pos: Vector3, shape_idx: int, dir: Vector3) -> void:
	if not alive:
		return
	var owner_id := shape_find_owner(shape_idx)
	var cs = shape_owner_get_owner(owner_id)
	if cs != null and cs.has_meta("pi"):
		damage_part(cs.get_meta("pi"), dmg)
	apply_impulse(dir * dmg * 2.0, pos - global_position)


func take_blast(pos: Vector3, radius: float, dmg: float) -> void:
	if not alive:
		return
	var com_w := com_world()
	var dc := com_w.distance_to(pos)
	if dc < radius * 2.0 + 3.0:
		var k := 1.0 - dc / (radius * 2.0 + 3.0)
		apply_impulse((com_w - pos).normalized() * dmg * 14.0 * k)
	for i in parts.size():
		var p: Dictionary = parts[i]
		if not p.alive:
			continue
		var d: float = (global_transform * p.pos).distance_to(pos)
		if d < radius:
			damage_part(i, dmg * (1.0 - d / radius))
			if not alive:
				return


func damage_part(i: int, dmg: float) -> void:
	var p: Dictionary = parts[i]
	if not p.alive:
		return
	p.hp -= dmg
	if p.hp <= 0.0:
		destroy_part(i)


func destroy_part(i: int) -> void:
	var p: Dictionary = parts[i]
	if not p.alive:
		return
	p.alive = false
	var wp: Vector3 = global_transform * p.pos
	Fx.debris_burst(wp, p.color)
	Sfx.play("pop" if p.id == "balloon" else "hit", wp, 0.0, 0.6)
	p.node.queue_free()
	p.shape.queue_free()
	if p.has("dust"):
		p.dust.queue_free()
		p.erase("dust")
	if p.id == "tnt":
		Fx.explode.call_deferred(wp, 8.0, 160.0)
	if i == seat_idx:
		_wreck(wp)
		return
	_dirty_split = true


func _split_disconnected() -> void:
	if seat_idx < 0 or not parts[seat_idx].alive:
		return
	var seen := _flood(parts[seat_idx].cell)
	var loose := []
	for p in parts:
		if p.alive and not seen.has(p.cell):
			loose.append(p)
	while not loose.is_empty():
		var group := _flood(loose[0].cell)
		var chunk := []
		var rest := []
		for p in loose:
			if group.has(p.cell):
				chunk.append(p)
			else:
				rest.append(p)
		_make_debris(chunk, Vector3.ZERO)
		loose = rest
	_recompute()


func _flood(start: Vector3i) -> Dictionary:
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		for d in NEIGHBORS:
			var n: Vector3i = c + d
			if seen.has(n) or not by_cell.has(n):
				continue
			if not parts[by_cell[n]].alive:
				continue
			seen[n] = true
			stack.append(n)
	return seen


func _make_debris(chunk: Array, extra_vel: Vector3) -> void:
	if chunk.is_empty() or Fx.root == null:
		return
	var body := RigidBody3D.new()
	body.collision_layer = Fx.L_PROPS
	body.collision_mask = Fx.L_WORLD | Fx.L_VEHICLE | Fx.L_PROPS | Fx.L_TARGET
	body.add_to_group("props")
	body.add_to_group("magnetic")
	Fx.root.add_child(body)
	body.global_transform = global_transform
	var m := 0.0
	var c := Vector3.ZERO
	for p in chunk:
		p.alive = false
		m += p.def.mass
		c += p.pos * p.def.mass
		var node: Node3D = p.node
		for nm in ["flame", "beam", "canopy", "lamp", "field"]:
			if p.has(nm):
				p[nm].visible = false
		for nm in ["particles", "dust"]:
			if p.has(nm):
				p[nm].emitting = false
		node.reparent(body)
		p.shape.reparent(body)
	body.mass = maxf(m, 1.0)
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = c / maxf(m, 1.0)
	var cw := global_transform * (c / maxf(m, 1.0))
	body.linear_velocity = _pv(cw, com_world()) + extra_vel
	body.angular_velocity = angular_velocity + extra_vel.cross(Vector3.UP) * 0.2
	get_tree().create_timer(40.0).timeout.connect(body.queue_free)


func _wreck(wp: Vector3) -> void:
	alive = false
	var left := []
	for p in parts:
		if p.alive:
			left.append(p)
	# blow every remaining block apart
	if left.size() > 40:
		var clusters := {}
		for p in left:
			var key := Vector3i(floori(p.cell.x / 2.0), floori(p.cell.y / 2.0), floori(p.cell.z / 2.0))
			if not clusters.has(key):
				clusters[key] = []
			clusters[key].append(p)
		for key in clusters:
			var cl: Array = clusters[key]
			var cw: Vector3 = global_transform * cl[0].pos
			_make_debris(cl, (cw - wp).normalized() * randf_range(5, 12) + Vector3.UP * 5.0)
	else:
		for p in left:
			var cw: Vector3 = global_transform * p.pos
			_make_debris([p], (cw - wp).normalized() * randf_range(5, 12) + Vector3.UP * 5.0)
	for s in [_engine, _laser_snd, _flame_snd, _jet_snd]:
		s.stop()
	Fx.explode.call_deferred(wp, 6.0, 30.0)
	collision_layer = 0
	collision_mask = 0
	freeze = true
	wrecked.emit()


# ---------------------------------------------------------------- queries

func intact() -> float:
	return float(alive_count) / maxf(1.0, start_count)


func lowest_point_local() -> float:
	var lo := 999.0
	for p in parts:
		if not p.alive:
			continue
		var r := 0.5
		if p.id == "wheel" or p.id == "bigwheel":
			r = p.def.radius + p.def.travel * 0.5
		lo = minf(lo, p.pos.y - r)
	return lo
