extends RigidBody3D
## A drivable vehicle assembled from a design: one rigid body, one collider and
## visual per block. Blocks are simulated individually (wheels, thrust, aero,
## buoyancy, weapons) and can be shot off. Pistons, hinges and rotators carry
## the blocks attached to their output face by moving those blocks' colliders
## and visuals inside the body.

signal wrecked

const FWD := Vector3(0, 0, -1)
const WHEEL_VMAX := 46.0
const WHEEL_VREV := 16.0
const Models := preload("res://scripts/block_models.gd")
const NODE_NAMES := ["spin", "flame", "flap", "canopy", "beam", "particles", "lamp", "lamp2", "field", "led", "led2",
	"yaw", "recoil", "bomb", "coil", "mov", "rod", "hglow", "barrels"]

var design := {}
var parts: Array = []
var by_cell := {}
var adj: Array = []           # part index -> neighbouring part indices (touching footprints)
var seat_idx := -1
var alive := true
var aim_point := Vector3.INF
var com_local := Vector3.ZERO
var extent2 := 1.0
var wheel_count := 0
var rotor_count := 0
var hover_count := 0
var foot_count := 0
var airbags := 0
var start_count := 0
var alive_count := 0
var activity := 0.0
var grounded := 0
var dmg_mult := 1.0
var mechs: Array[int] = []      # mover part indices, outermost first
var _mech_dirty := 0.0
var _time := 0.0
var _dirty_split := false
var _crash: Array = []        # [local_pos, dv] collected in _integrate_forces
var _crash_cd := 0.0
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
	can_sleep = false
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
	contact_monitor = true
	max_contacts_reported = 6
	_rids = [get_rid()]
	var blist := []
	for b in d.get("blocks", []):
		var def := Blocks.get_def(b.id)
		if def.is_empty():
			continue
		var cell := Vector3i(int(b.p[0]), int(b.p[1]), int(b.p[2]))
		if by_cell.has(cell):
			continue
		var basis := Blocks.basis_of(b)
		var size := Blocks.size_of(b)
		var vol := size.x * size.y * size.z
		var cs: String = b.get("c", "")
		var col: Color = Color(cs) if cs != "" else def.color
		var cfg: Dictionary = def.cfg.duplicate()
		cfg.merge(b.get("cfg", {}), true)
		var pos := Blocks.center_of(b)
		var vis := Blocks.make_visual(b.id, col)
		vis.transform = Transform3D(basis * Basis.from_scale(size), pos)
		add_child(vis)
		var sh := Blocks.shape_scaled(b.id, size)
		var col_shape := CollisionShape3D.new()
		col_shape.shape = sh[0]
		col_shape.transform = Transform3D(basis, pos) * sh[1]
		col_shape.set_meta("pi", parts.size())
		add_child(col_shape)
		var cb := Blocks.cell_box(b)
		var p := {
			"id": b.id, "def": def, "kind": def.kind, "cell": cell, "basis": basis, "pos": pos, "basis0": basis, "pos0": pos,
			"scale": size, "mass": float(def.mass) * vol, "hy": cb.size.y * 0.5,
			"shape_local": sh[1], "color": col, "cfg": cfg, "hp": float(def.hp) * maxf(vol, 0.25), "alive": true, "node": vis, "shape": col_shape,
			"hp_max": float(def.hp) * maxf(vol, 0.25), "idx": parts.size(),
			"buoy": float(def.buoy) * vol, "gov": -1, "susp": -1,
			"st": {"cd": randf() * 0.1, "fl": 0.0, "spin": 0.0, "side": 0, "v": 0.0, "ph": 0.0, "ext": 0.0, "h": 0.0,
				"fuel": float(def.get("fuel", 0.0)), "burn": 0.0, "ammo": int(def.get("mag", 0)), "fill": 0.0},
		}
		for nm in NODE_NAMES:
			var n := vis.find_child(nm, true, false)
			if n:
				p[nm] = n
		var pt := vis.find_child("pitch", true, false)
		if pt:
			p["pitch"] = pt
		if p.has("coil"):
			p.st["coil_s"] = (p.coil as Node3D).scale
		if def.kind == "wheel":
			p["dust"] = _emitter(pos + Vector3(0, -def.radius, 0.3), Color("#d8b98c"))
		elif def.get("hull", false):
			p["dust"] = _emitter(pos + Vector3(0, 0.9, 1.0), Color(0.9, 0.97, 1.0))
			p.dust.amount = 48
		if def.kind == "seat" and seat_idx < 0:
			seat_idx = parts.size()
		by_cell[cell] = parts.size()
		parts.append(p)
		blist.append(b)
	adj = Blocks.adjacency(blist)
	start_count = parts.size()
	_setup_mechs()
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


# ---------------------------------------------------------------- mechanisms

## Part indices reachable from `starts` without passing through part `block`.
func _flood_without(starts: Array, block: int) -> Dictionary:
	var seen := {}
	var stack := []
	for s: int in starts:
		seen[s] = true
		stack.append(s)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for j: int in adj[i]:
			if j == block or seen.has(j):
				continue
			seen[j] = true
			stack.append(j)
	return seen


func _setup_mechs() -> void:
	for i in parts.size():
		var p: Dictionary = parts[i]
		var kind: String = p.kind
		if kind == "susp":
			for j: int in adj[i]:
				if parts[j].kind == "wheel" and parts[j].susp < 0:
					parts[j].susp = i
			continue
		if not kind in Blocks.MOVERS:
			continue
		var fb := Models.mech_frame(p.def)
		var out: Vector3 = p.basis * fb.y
		var axis: Vector3 = p.basis * (fb.x if kind == "hinge" else fb.y)
		var pivot: Vector3 = p.pos + out * 0.5 if kind == "hinge" else p.pos
		p["mech"] = {"out": out, "axis": axis, "pivot": pivot, "locked": false, "parent": -1, "W": Transform3D.IDENTITY, "set": []}
		mechs.append(i)
		# every block touching the striped output face
		var seeds := []
		for j: int in adj[i]:
			if (parts[j].pos - p.pos).dot(out) > 0.3:
				seeds.append(j)
		if seeds.is_empty():
			continue
		var seen := _flood_without(seeds, i)
		if seen.has(seat_idx):
			p.mech.locked = true
			continue
		p.mech.set = seen.keys()
	# outermost (largest moved set) first; parents always come before children
	mechs.sort_custom(func(a, b): return parts[a].mech.set.size() > parts[b].mech.set.size())
	for k in mechs:
		for j in parts[k].mech.set:
			# later (smaller, inner) mechs overwrite: gov ends as the innermost
			parts[j].gov = k
	for k in mechs:
		parts[k].mech.parent = parts[k].gov


func _mech_target(p: Dictionary, input: float, delta: float) -> bool:
	var def: Dictionary = p.def
	var st: Dictionary = p.st
	var pw: float = p.cfg.get("pow", 100) / 100.0
	var mode: String = p.cfg.get("mode", "return")
	var old: float = st.v
	var spd: float = def.speed * pw
	match p.kind:
		"piston":
			var lim: float = def.stroke
			if mode == "osc":
				if input > 0.5:
					st.ph += delta * spd
				st.v = (0.5 - 0.5 * cos(st.ph)) * lim
			elif mode == "hold":
				st.v = clampf(st.v + input * spd * delta, 0.0, lim)
			else:
				st.v = move_toward(st.v, clampf(input, 0.0, 1.0) * lim, spd * delta)
		"hinge":
			var lim: float = def.max
			if mode == "osc":
				if input > 0.5:
					st.ph += delta * spd
				st.v = sin(st.ph) * lim
			elif mode == "hold":
				st.v = clampf(st.v + input * spd * delta, -lim, lim)
			else:
				st.v = move_toward(st.v, clampf(input, -1.0, 1.0) * lim, spd * delta)
		"rotator":
			st.v = fmod(st.v + input * spd * delta, TAU)
	return absf(st.v - old) > 0.00001


func _update_mechs(delta: float) -> void:
	if mechs.is_empty():
		return
	var moved := false
	for k in mechs:
		var p: Dictionary = parts[k]
		var m: Dictionary = p.mech
		if p.alive and not m.locked:
			var ch: String = p.cfg.get("ch", "always")
			var input := Controls.value(ch) * (-1.0 if p.cfg.get("inv", false) else 1.0)
			if _mech_target(p, input, delta):
				moved = true
		var v: float = p.st.v
		var local := Transform3D.IDENTITY
		match p.kind:
			"piston":
				local = Transform3D(Basis.IDENTITY, m.out * v)
				if p.has("mov"):
					p.mov.position = Vector3(0, v, 0)
				if p.has("rod"):
					p.rod.position.y = (0.1 + 0.45 + v) * 0.5
					p.rod.scale.y = 0.35 + v
			"hinge", "rotator":
				var rb := Basis(m.axis, v)
				local = Transform3D(rb, m.pivot - rb * m.pivot)
				if p.has("mov"):
					if p.kind == "hinge":
						p.mov.rotation.x = v
					else:
						p.mov.rotation.y = v
		var parent_w: Transform3D = parts[m.parent].mech.W if m.parent >= 0 else Transform3D.IDENTITY
		m.W = parent_w * local
	if not moved:
		return
	for p in parts:
		if p.gov < 0 or not p.alive:
			continue
		var t: Transform3D = parts[p.gov].mech.W
		p.pos = t * p.pos0
		p.basis = t.basis * p.basis0
		var tr := Transform3D(p.basis, p.pos)
		p.node.transform = Transform3D(p.basis * Basis.from_scale(p.scale), p.pos)
		p.shape.transform = tr * p.shape_local
	_mech_dirty = 0.15


func _recompute() -> void:
	var m := 0.0
	var c := Vector3.ZERO
	wheel_count = 0
	rotor_count = 0
	hover_count = 0
	foot_count = 0
	airbags = 0
	alive_count = 0
	for p in parts:
		if not p.alive:
			continue
		alive_count += 1
		m += p.mass
		c += p.pos * p.mass
		match p.kind:
			"wheel": wheel_count += 1
			"rotor": rotor_count += 1
			"hover": hover_count += 1
			"airbag": airbags += 1
			"susp":
				if not _has_wheel(p):
					foot_count += 1
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
		var pm: float = p.mass
		ix += pm * (r.y * r.y + r.z * r.z + 0.17)
		iy += pm * (r.x * r.x + r.z * r.z + 0.17)
		iz += pm * (r.x * r.x + r.y * r.y + 0.17)
		e += r.length_squared() * pm
	inertia = Vector3(ix, iy, iz)
	extent2 = maxf(1.0, e / m)


func _has_wheel(sp: Dictionary) -> bool:
	for j: int in adj[sp.idx]:
		if parts[j].alive and parts[j].kind == "wheel":
			return true
	return false


func com_world() -> Vector3:
	return global_transform * com_local


func _pv(wp: Vector3, com_w: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(wp - com_w)


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	_crash_cd -= delta
	if not _crash.is_empty():
		_apply_crash()
		if not alive:
			return
	if _dirty_split:
		_dirty_split = false
		_split_disconnected()
		_recompute()
		if not alive:
			return
	_update_mechs(delta)
	if _mech_dirty > 0.0:
		_mech_dirty -= delta
		if _mech_dirty <= 0.0:
			_recompute()
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
	var shield := false
	grounded = 0
	for i in parts.size():
		var p: Dictionary = parts[i]
		if not p.alive:
			continue
		var def: Dictionary = p.def
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
			if def.has("keel"):
				var side: Vector3 = gb * (p.basis * Vector3.RIGHT)
				var vs := v.dot(side)
				drag -= side * vs * (absf(vs) * 12.0 + 120.0) * def.keel / 70.0 * wet
			apply_force(Vector3.UP * sub * 9800.0 * p.buoy + drag, off)
		var cfg: Dictionary = p.cfg
		var pw: float = cfg.get("pow", 100) / 100.0
		var ch: String = cfg.get("ch", "always")
		var inv: bool = cfg.get("inv", false)
		var input := Controls.value(ch) * (-1.0 if inv else 1.0)
		match p.kind:
			"wheel":
				_wheel(p, wp, gb, com_w, space, thr, steer, speed, delta)
			"susp":
				_susp(p, wp, gb, com_w, space, input, delta)
			"engine":
				var amt := _engine_block(p, wp, off, gb, com_w, lv, input, pw, steer, delta)
				act += absf(amt) * (2.0 if def.thrust > 10000.0 else 1.0)
				if def.get("loud", false):
					jet_act += absf(amt)
			"rotor":
				_rotor(p, wp, off, gb, lv, input, pw, delta, thr)
				act += 0.7
			"hover":
				_hover(p, wp, off, gb, com_w, space, pw, delta)
				act += 0.3
			"balloon":
				var lift: float = def.lift * pw
				var on := input > 0.5
				if def.get("ctrl", false):
					lift *= clampf(0.62 + 0.4 * input, 0.15, 1.0)
					on = true
					if p.has("led"):
						p.led.visible = input > 0.1
				if on and wp.y < def.get("cap", 700.0):
					apply_force(Vector3.UP * lift, off)
				if p.has("spin"):
					p.spin.rotate_object_local(Vector3(0.3, 1, 0.2).normalized(), 2.0 * delta)
			"wing", "flap":
				_aero(p, wp, off, gb, com_w, want_torque, pw)
			"airbrake":
				var open := input > 0.3
				var fl: Node3D = p.flap
				fl.rotation.x = lerpf(fl.rotation.x, -1.2 if open else 0.0, 0.2)
				if open and speed > 1.0:
					var v := _pv(wp, com_w)
					apply_force(-v * minf(v.length() * def.drag * 1.6 * pw, mass * 12.0 / maxf(v.length(), 1.0)), off)
			"rudder":
				var fl: Node3D = p.flap
				fl.rotation.y = lerpf(fl.rotation.y, -input * 0.5, 0.2)
				if wp.y < Fx.WATER - 0.1:
					var v := _pv(wp, com_w)
					var fwd: Vector3 = gb * (p.basis * FWD)
					var vc := v.dot(fwd)
					var rside: Vector3 = gb * (p.basis * Vector3.RIGHT)
					apply_force(-rside * input * vc * absf(vc) * 30.0 * pw, off)
			"keel":
				pass
			"ballast":
				p.st.fill = clampf(p.st.fill - input * delta * 0.35, 0.0, 1.0)
				p.buoy = def.buoy * (1.0 - p.st.fill) - 1.6 * p.st.fill
				if p.has("led"):
					(p.led as MeshInstance3D).material_override = Blocks.glow_mat(Color("#3ddc84") if p.st.fill < 0.5 else Color("#ff4f5e"), 4.0)
			"anchor":
				_anchor(p, wp, off, com_w, space, input > 0.5, delta)
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
					var f := -vdir * minf(speed * speed * 70.0 * pw * def.drag, mass * 28.0)
					apply_force(f, off)
					cn.global_basis = Basis(Quaternion(Vector3.UP, -vdir)).orthonormalized().scaled(Vector3.ONE * def.vs)
			"magnet":
				var on := input > 0.5
				p.field.visible = on
				if on:
					_magnet(p, wp, off, pw)
			"tnt":
				p.st.cd -= delta
				if p.st.cd <= 0.0:
					p.st.cd = 0.6
					p.led.visible = not p.led.visible
				if Controls.just(ch):
					destroy_part(i)
			"decoupler", "dropweight":
				if Controls.just(ch):
					Sfx.play("pop", wp, 2.0, 0.5)
					Fx.burst(wp, Color(0.9, 0.9, 0.9, 0.8), 12, 4.0, 0.3, 0.8, Vector3(0, 1, 0), 180.0, Vector3.UP, false)
					if p.kind == "dropweight":
						_make_debris([p], Vector3.ZERO)
						_dirty_split = true
					else:
						destroy_part(i, true)
			"jump":
				p.st.cd -= delta
				if input > 0.5 and Controls.just(ch) and p.st.cd <= 0.0:
					p.st.cd = 1.4
					var up: Vector3 = gb * (p.basis * Vector3.UP)
					apply_impulse(up * mass * def.impulse * pw, off)
					Sfx.play("jump", wp, 0.0)
					Fx.burst(wp - up * 0.5, Color(0.9, 0.85, 0.7, 0.8), 14, 5.0, 0.3, 0.8, Vector3(0, -4, 0), 80.0, -up, false)
					var coil: Node3D = p.coil
					var base_s: Vector3 = p.st.coil_s
					coil.scale = base_s * Vector3(1, 1.8, 1)
					coil.position = -Vector3.UP * 0.3 * def.vs
					var tw := coil.create_tween().set_parallel()
					tw.tween_property(coil, "scale", base_s, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tw.tween_property(coil, "position", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			"smoke":
				var em := input > 0.5
				p.particles.emitting = em
				if em and def.get("rainbow", false):
					var ppm := (p.particles as GPUParticles3D).process_material as ParticleProcessMaterial
					ppm.color = Color.from_hsv(fmod(_time * 0.35, 1.0), 0.85, 1.0)
			"light":
				var on := input > 0.5
				if def.get("brake", false):
					on = input > 0.2 or (thr < -0.05)
				if p.has("lamp"):
					p.lamp.visible = on
				if p.has("led"):
					p.led.visible = on
			"blinker":
				_blinker(p, wp, input > 0.5, delta)
			"horn":
				if Controls.just(ch):
					Sfx.play("horn", wp, 4.0 + def.get("vol", 0.0), def.get("pitch", 1.0))
			"shield":
				var on := input > 0.5
				p.field.visible = on
				if on:
					shield = true
					(p.field as Node3D).rotate_y(delta * 0.5)
			"repair":
				if input > 0.5:
					_repair(def.heal * pw * delta)
					p.spin.rotate_object_local(Vector3.UP, 3.0 * delta)
					p.led.visible = fmod(_time, 0.5) < 0.25
			"nitro":
				var on: bool = input > 0.5 and p.st.fuel > 0.0
				if on:
					p.st.fuel -= delta
					apply_central_force(-gb.z * mass * def.push * pw)
					act += 1.0
				else:
					p.st.fuel = minf(p.st.fuel + delta * 0.3, def.fuel)
				p.st.fl = lerpf(p.st.fl, 1.0 if on else 0.0, 0.3)
				var fl: Node3D = p.flame
				fl.visible = p.st.fl > 0.03
				fl.scale.z = maxf(0.001, p.st.fl * 2.0 * randf_range(0.8, 1.15))
			"selfrighter":
				p.spin.rotate_object_local(Vector3.UP, (1.0 + (4.0 if gb.y.y < 0.3 else 0.0)) * delta)
				if input > 0.5 and gb.y.y < 0.3 and speed < 8.0:
					var axis := gb.y.cross(Vector3.UP)
					if axis.length() < 0.2:
						axis = gb.z
					apply_torque(axis.normalized() * mass * extent2 * 6.0 * pw - angular_velocity * mass * extent2 * 1.5)
			"blink":
				p.st.cd -= delta
				p.led.visible = p.st.cd <= 0.0 or fmod(_time, 0.3) < 0.15
				p.spin.rotate_object_local(Vector3.UP, 2.0 * delta)
				if Controls.just(ch) and p.st.cd <= 0.0:
					p.st.cd = 4.0
					_blink()
					return
			"flares":
				p.st.cd -= delta
				if input > 0.5 and p.st.cd <= 0.0:
					p.st.cd = 1.5
					for k in 6:
						var d: Vector3 = gb * (p.basis * Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.2, 0.6))).normalized()
						Fx.spawn_projectile("flare", wp + d, lv + d * 22.0, _rids)
					Sfx.play("rocket", wp, -2.0, 1.4)
			"flag":
				var fl: Node3D = p.flap
				fl.rotation.y = sin(_time * (4.0 + speed * 0.3)) * (0.15 + minf(speed / 60.0, 0.3))
			"discoball":
				var on := input > 0.5
				p.spin.rotate_object_local(Vector3.UP, (2.0 if on else 0.2) * delta)
				for nm in ["lamp", "lamp1", "lamp2"]:
					var l := (p.node as Node3D).find_child(nm, true, false)
					if l:
						l.visible = on
			"gun", "launcher", "laser", "flamer", "turret", "tesla", "watercannon", "confetti":
				p.st.cd -= delta
				var firing := input > 0.5
				match p.kind:
					"laser":
						laser_on = _laser(p, wp, gb, firing, delta) or laser_on
					"flamer":
						var ptc: GPUParticles3D = p.particles
						ptc.emitting = firing
						if firing:
							flame_on = true
							var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, 0, -0.7 * def.vs))
							Fx.cone_damage(mz, gb * (p.basis * FWD), def.range, def.dps * delta * pw, _rids)
					"turret":
						_turret(p, wp, firing, delta, pw)
					"watercannon":
						var ptc: GPUParticles3D = p.particles
						ptc.emitting = firing
						if firing:
							var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, -0.05, -0.7))
							var dir: Vector3 = gb * (p.basis * FWD)
							Fx.cone_push(mz, dir, 26.0, 1800.0 * delta * pw, _rids)
							apply_force(-dir * 2500.0 * pw, mz - gpos)
					_:
						if p.st.get("reload", 0.0) > 0.0:
							p.st.reload -= delta
						elif firing and p.st.cd <= 0.0:
							match p.kind:
								"tesla":
									p.st.cd = def.rate
									_tesla(p, wp, pw)
								"confetti":
									p.st.cd = 0.35
									_confetti(p, wp, gb)
								_:
									_fire(p, wp, gb, pw)
						if p.kind == "tesla" and p.has("led"):
							p.led.visible = not firing or randf() < 0.6
			"melee":
				_melee(p, wp, gb, com_w, pw, delta)
	dmg_mult = 0.25 if shield else 1.0
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


func _engine_block(p: Dictionary, wp: Vector3, off: Vector3, gb: Basis, com_w: Vector3, lv: Vector3, input: float, pw: float, steer: float, delta: float) -> float:
	var def: Dictionary = p.def
	var st: Dictionary = p.st
	var amt := clampf(input, -0.5 if def.get("reverse", false) else 0.0, 1.0)
	if def.has("fuel"):
		# solid booster: ignite once, burn to the end
		if st.burn == 0.0 and input > 0.5:
			st.burn = def.fuel
		if st.burn > 0.0:
			st.burn -= delta
			if st.burn <= 0.0:
				st.burn = -1.0
			amt = 1.0
		else:
			amt = 0.0
	match def.get("medium", "any"):
		"air":
			if wp.y < Fx.WATER + 0.1:
				amt = 0.0
		"water":
			if wp.y > Fx.WATER - 0.05:
				amt = 0.0
		"surface":
			if wp.y > Fx.WATER + 0.6:
				amt = 0.0
	var t: float = def.thrust * pw * amt
	if def.has("afterburn") and amt > 0.0 and Controls.value("boost") > 0.5:
		t *= def.afterburn
		amt = 1.6
	var tdir: Vector3 = def.get("tdir", FWD)
	var lb: Basis = p.basis
	if def.has("steer_deg"):
		var ang := -steer * deg_to_rad(def.steer_deg)
		lb = lb * Basis(Vector3.UP, ang)
		if p.has("yaw"):
			p.yaw.rotation.y = ang
	var dir: Vector3 = gb * (lb * tdir)
	if def.has("propfall"):
		t *= 1.0 - clampf(lv.dot(dir) / def.propfall, 0.0, 0.85)
	if def.get("ram", false):
		t *= clampf(lv.dot(dir) / 50.0, 0.15, 2.2)
	if def.get("pulse", false):
		t *= 0.3 + (0.7 if fmod(_time * 9.0, 1.0) < 0.5 else 0.0)
	if absf(t) > 0.0:
		if def.get("hull", false):
			# push at the hull's height so boats don't backflip
			var rel := wp - com_w
			apply_force(dir * t, com_w + rel - gb.y * rel.dot(gb.y) * 0.85 - global_position)
		else:
			apply_force(dir * t, off)
	st.fl = lerpf(st.fl, absf(amt), 0.25)
	if p.has("dust"):
		p.dust.emitting = absf(amt) > 0.1
	if p.has("flame"):
		var fl: Node3D = p.flame
		fl.visible = st.fl > 0.03
		var pulse := 1.0 if not def.get("pulse", false) else (1.0 if fmod(_time * 9.0, 1.0) < 0.5 else 0.3)
		fl.scale.z = maxf(0.001, st.fl * def.get("flame", 1.0) * randf_range(0.8, 1.15) * pulse)
	if p.has("spin"):
		var ax: Vector3 = Vector3.RIGHT if def.vis == "paddle" else Vector3.BACK
		p.spin.rotate_object_local(ax, (6.0 + st.fl * 40.0) * delta * signf(amt + 0.001))
	return amt


func _wheel(p: Dictionary, wp: Vector3, gb: Basis, com_w: Vector3, space: PhysicsDirectSpaceState3D, thr: float, steer: float, speed: float, delta: float) -> void:
	var def: Dictionary = p.def
	var up: Vector3 = gb * p.basis.y
	var rad: float = def.radius
	var travel: float = def.travel
	var stiff: float = def.get("stiff", 1.0)
	var damp := 1.0
	var ride := 0.0
	var sp: Dictionary = parts[p.susp] if p.susp >= 0 and parts[p.susp].alive else {}
	if not sp.is_empty():
		travel += sp.def.travel
		stiff *= sp.def.stiff
		damp *= sp.def.damp
		ride = sp.st.h
	var ray_len := rad + travel + ride
	var cfg: Dictionary = p.cfg
	var sgn := 0.0
	var mode: String = cfg.get("steer", "auto")
	match mode:
		"auto":
			sgn = 1.0 if p.pos.z < com_local.z - 0.6 else (-0.35 if p.pos.z > com_local.z + 2.5 else 0.0)
		"on":
			sgn = 1.0
		"inv":
			sgn = -1.0
	var ang := -steer * sgn * deg_to_rad(34.0) / (1.0 + speed / 24.0)
	var wthr := thr
	if mode == "tank":
		var side_sign := 1.0 if p.pos.x > com_local.x + 0.1 else (-1.0 if p.pos.x < com_local.x - 0.1 else 0.0)
		wthr = clampf(thr - steer * side_sign, -1.0, 1.0)
	var q := PhysicsRayQueryParameters3D.create(wp, wp - up * ray_len, Fx.L_WORLD | Fx.L_PROPS | Fx.L_TARGET, _rids)
	var h := space.intersect_ray(q)
	var dist := ray_len
	var vf := 0.0
	if not h.is_empty():
		dist = wp.distance_to(h.position)
		var comp := ray_len - dist
		var v := _pv(h.position, com_w)
		var share := mass / maxf(1.0, wheel_count + foot_count)
		var k := share * 9.8 / (travel * 0.5) * stiff
		var c := 2.0 * sqrt(k * share) * 0.45 * damp
		var load := clampf(k * comp - c * v.dot(up), 0.0, mass * 40.0)
		var n: Vector3 = h.normal
		apply_force(up * load, h.position - global_position)
		var fwd: Vector3 = (gb * (p.basis * FWD)).rotated(up, ang)
		var side := fwd.cross(up)
		var fg := (fwd - n * fwd.dot(n)).normalized()
		var sg := (side - n * side.dot(n)).normalized()
		vf = v.dot(fg)
		var vs := v.dot(sg)
		var lat := -vs * share / delta * float(def.get("lat", 0.32))
		var lon := 0.0
		var drives: bool = cfg.get("drive", true) and def.drive > 0.0
		if drives and ((wthr > 0.05 and vf < -0.8) or (wthr < -0.05 and vf > 0.8)) and mode != "tank":
			lon = -signf(vf) * share * 12.0 * absf(wthr)
		elif drives and absf(wthr) > 0.05:
			var dp: float = def.drive * cfg.get("pow", 100) / 100.0
			var lim: float = def.get("vmax", WHEEL_VMAX) if wthr > 0.0 else WHEEL_VREV
			var dirv := vf * signf(wthr)
			lon = dp * wthr * clampf(1.0 - maxf(dirv, 0.0) / lim, 0.0, 1.0)
		lon -= vf * share * float(def.get("roll", 0.015))
		if drives and absf(wthr) < 0.05 and absf(vf) < 2.0:
			lon -= vf * share / delta * 0.25
		var f := sg * lat + fg * lon
		var grip: float = load * 1.3 * float(def.get("grip", 1.0))
		if f.length() > grip:
			f = f.normalized() * grip
		apply_force(f, h.position + up * rad * 0.6 - global_position)
		grounded += 1
		p.dust.emitting = absf(vf) > 7.0 and h.collider is StaticBody3D and h.position.y > 1.0
	else:
		p.dust.emitting = false
	if not sp.is_empty():
		sp.st.ext = clampf(dist - rad - ride, 0.0, travel)
	p.st.spin += vf / rad * delta
	var node: Node3D = p.node
	node.transform = Transform3D(p.basis * Basis(Vector3.UP, ang), p.pos - p.basis.y * (dist - rad))
	p.spin.rotation.x = -p.st.spin


## Suspension block: boosts touching wheels; with no wheel it is a springy leg.
func _susp(p: Dictionary, wp: Vector3, gb: Basis, com_w: Vector3, space: PhysicsDirectSpaceState3D, input: float, delta: float) -> void:
	var def: Dictionary = p.def
	if def.has("ride"):
		p.st.h = clampf(p.st.h + input * delta * 2.5, 0.0, def.ride)
	var out: Vector3 = gb * (p.basis * def.out)
	var travel: float = def.travel
	var ext := 0.0
	if _has_wheel(p):
		ext = p.st.ext + p.st.h
	else:
		var ray_len: float = 0.5 + travel + p.st.h
		var q := PhysicsRayQueryParameters3D.create(wp, wp + out * ray_len, Fx.L_WORLD | Fx.L_PROPS | Fx.L_TARGET, _rids)
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		ext = travel + p.st.h
		if not h.is_empty():
			var dist := wp.distance_to(h.position)
			var comp := ray_len - dist
			var v := _pv(h.position, com_w)
			var share := mass / maxf(1.0, wheel_count + foot_count)
			var k: float = share * 9.8 / (travel * 0.5) * def.stiff
			var c: float = 2.0 * sqrt(k * share) * 0.45 * def.damp
			var load := clampf(k * comp + c * v.dot(out), 0.0, mass * 40.0)
			apply_force(-out * load, h.position - global_position)
			var vl := v - out * v.dot(out)
			var f := -vl * share / delta * 0.2
			if f.length() > load * 0.9:
				f = f.normalized() * load * 0.9
			apply_force(f, h.position - global_position)
			ext = maxf(dist - 0.5, 0.0)
			grounded += 1
	if p.has("mov"):
		p.mov.position.y = lerpf(p.mov.position.y, ext * 0.8, 0.5)
	if p.has("rod"):
		var top: float = p.mov.position.y + 0.42
		p.rod.position.y = (top - 0.2) * 0.5
		p.rod.scale.y = top + 0.2


func _hover(p: Dictionary, wp: Vector3, off: Vector3, gb: Basis, com_w: Vector3, space: PhysicsDirectSpaceState3D, pw: float, delta: float) -> void:
	var def: Dictionary = p.def
	var up: Vector3 = gb * (p.basis * Vector3.UP)
	var hgt: float = def.height
	var ray_len := hgt * 2.0
	var q := PhysicsRayQueryParameters3D.create(wp, wp - up * ray_len, Fx.L_WORLD | Fx.L_PROPS | Fx.L_TARGET, _rids)
	var h := space.intersect_ray(q)
	var dist := ray_len
	if not h.is_empty():
		dist = wp.distance_to(h.position)
	if up.y > 0.3 and wp.y > Fx.WATER:
		var dw := (wp.y - Fx.WATER) / up.y
		if dw < dist:
			dist = dw
	if dist < ray_len:
		var v := _pv(wp, com_w)
		var share := mass / maxf(1.0, hover_count)
		var k := share * 9.8 / (hgt * 0.5)
		var c := 2.0 * sqrt(k * share) * 0.6
		var f := clampf(k * (hgt - dist) + share * 9.8 * 0.5 - c * v.dot(up), 0.0, def.force * pw)
		apply_force(up * f, off)
		var vh := v - up * v.dot(up)
		apply_force(-vh * share * 0.25, off)
	if p.has("hglow"):
		var g: Node3D = p.hglow
		g.scale = Vector3.ONE * (0.85 + 0.15 * sin(_time * 12.0 + p.pos.x))


func _anchor(p: Dictionary, wp: Vector3, off: Vector3, com_w: Vector3, space: PhysicsDirectSpaceState3D, on: bool, delta: float) -> void:
	var an: Node3D = p.bomb
	var ch: Node3D = p.beam
	var target_y := -3.0 if on else 0.0
	an.position.y = move_toward(an.position.y, target_y, delta * 6.0)
	ch.visible = an.position.y < -0.2
	ch.scale.y = maxf(0.01, -an.position.y + 0.3)
	ch.position.y = 0.3
	if not on:
		return
	var holds := wp.y < Fx.WATER + 1.5
	if not holds:
		var q := PhysicsRayQueryParameters3D.create(wp, wp + Vector3.DOWN * 5.0, Fx.L_WORLD, _rids)
		holds = not space.intersect_ray(q).is_empty()
	if holds:
		var v := _pv(wp, com_w)
		var f := -v * mass * 2.0
		if f.length() > mass * 30.0:
			f = f.normalized() * mass * 30.0
		apply_force(f, off)
		apply_torque(-angular_velocity * mass * extent2 * 1.5)


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
	var def: Dictionary = p.def
	if def.get("water_only", false) and wp.y > Fx.WATER:
		return
	var v := _pv(wp, com_w)
	var sp := v.length()
	var deflect := 0.0
	var nrm: Vector3 = def.get("nrm", Vector3.UP)
	if p.kind == "flap":
		var wt := want_torque
		match def.get("only", ""):
			"pitch": wt = Vector3(want_torque.x, 0, 0)
			"roll": wt = Vector3(0, 0, want_torque.z)
			"yaw": wt = Vector3(0, want_torque.y, 0)
		var r: Vector3 = p.pos - com_local
		var a := r.cross(p.basis * nrm)
		var al := a.length()
		if al > 0.3:
			deflect = clampf(a.dot(wt) / al * 1.4, -1.0, 1.0)
		var fl: Node3D = p.flap
		fl.rotation.x = lerpf(fl.rotation.x, deflect * 0.5, 0.2)
	if sp < 0.5:
		return
	var n: Vector3 = gb * (p.basis * nrm)
	var chord: Vector3 = gb * (p.basis * FWD)
	var dens := 1.0 if wp.y > Fx.WATER else 6.0
	var vn := v.dot(n)
	var vc := v.dot(chord)
	var f: Vector3 = -n * vn * sp * 2.6
	if p.kind == "wing" and vc > 0.0:
		f += n * def.get("lift", 0.26) * vc * vc
	if p.kind == "flap":
		f += n * deflect * def.get("fp", 1.4) * vc * absf(vc) * pw
	f *= dens
	if f.length() > 30000.0:
		f = f.normalized() * 30000.0
	apply_force(f, off)


func _gyro(p: Dictionary, gb: Basis, want_torque: Vector3, pitch: float, roll: float, pw: float, delta: float) -> void:
	var def: Dictionary = p.def
	var s: float = pw * mass * extent2 * def.get("str", 1.0)
	var wt := Vector3.ZERO if def.get("level_only", false) else want_torque
	var lev_l := gb.inverse() * gb.y.cross(Vector3.UP)
	if not def.get("level_only", false):
		lev_l.x *= 1.0 - absf(pitch)
		lev_l.z *= 1.0 - absf(roll)
	var t := gb * (wt * 3.0 * s) + gb * lev_l * 9.0 * s - angular_velocity * 2.5 * s
	apply_torque(t)
	p.spin.rotate_object_local(Vector3(0.3, 1, 0.2).normalized(), 9.0 * delta)


func _magnet(p: Dictionary, wp: Vector3, off: Vector3, pw: float) -> void:
	var def: Dictionary = p.def
	var rng: float = def.get("range", 18.0)
	var strength: float = def.get("str", 1.0)
	var grip: bool = def.get("grip", false)
	for b in get_tree().get_nodes_in_group("magnetic"):
		if not is_instance_valid(b) or b == self or not (b is RigidBody3D):
			continue
		var d: Vector3 = wp - b.global_position
		var dl := d.length()
		if dl > rng or dl < 0.1:
			continue
		var f := d / dl * minf(b.mass, 300.0) * 32.0 * pw * strength * (1.0 - dl / (rng * 1.1))
		if dl < 2.2 or grip:
			b.linear_velocity = b.linear_velocity.lerp(_pv(wp, com_world()), 0.6 if grip else 0.25)
			if grip:
				b.angular_velocity *= 0.8
		b.sleeping = false
		b.apply_central_force(f)
		apply_force(-f * 0.5, off)


func _blinker(p: Dictionary, wp: Vector3, on: bool, delta: float) -> void:
	var def: Dictionary = p.def
	p.st.cd -= delta
	if p.st.cd <= 0.0:
		p.st.cd = def.rate
		p.st.side = 1 - int(p.st.side)
		if on and def.get("siren", false):
			Sfx.play("horn", wp, -4.0, 1.5 if p.st.side == 0 else 1.15)
	var a: bool = on and p.st.side == 0
	var b: bool = on and p.st.side == 1
	if p.has("led"):
		p.led.visible = a
	if p.has("lamp"):
		p.lamp.visible = a
	if p.has("led2"):
		p.led2.visible = b
	if p.has("lamp2"):
		p.lamp2.visible = b


func _repair(amount: float) -> void:
	for q in parts:
		if q.alive and q.hp < q.hp_max:
			q.hp = minf(q.hp_max, q.hp + amount)


func _blink() -> void:
	var fwd := -global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	var from := com_world()
	var to := from + fwd.normalized() * 30.0
	var gh := Fx.ground_height(to.x, to.z)
	to.y = maxf(to.y, maxf(gh, Fx.WATER) + 3.0)
	Fx.burst(from, Color("#c05cff"), 30, 8.0, 0.3, 0.6, Vector3.ZERO, 180.0, Vector3.UP, true)
	global_position += to - from
	Fx.burst(to, Color("#e0b3ff"), 30, 8.0, 0.3, 0.6, Vector3.ZERO, 180.0, Vector3.UP, true)
	Sfx.play("jump", to, 2.0, 2.0)


func _aim_dir(p: Dictionary, gb: Basis, muzzle_local: Vector3) -> Array:
	var mz: Vector3 = global_transform * (p.pos + p.basis * (muzzle_local * p.def.vs))
	var dir: Vector3 = gb * (p.basis * FWD)
	if aim_point != Vector3.INF and not p.def.get("noaim", false):
		var to := (aim_point - mz).normalized()
		if dir.angle_to(to) < deg_to_rad(15.0):
			dir = to
	return [mz, dir]


func _fire(p: Dictionary, wp: Vector3, gb: Basis, pw: float) -> void:
	var def: Dictionary = p.def
	var st: Dictionary = p.st
	st.cd = def.rate
	if def.has("mag"):
		st.ammo -= 1
		if st.ammo <= 0:
			st.ammo = def.mag
			st["reload"] = def.reload
	var muzzle: Vector3 = def.get("muzzle", Vector3(0, 0, -0.8))
	if def.has("barrels"):
		var bl: Array = def.barrels
		st.side = (int(st.side) + 1) % bl.size()
		muzzle = bl[st.side]
	var a := _aim_dir(p, gb, muzzle)
	var mz: Vector3 = a[0]
	var dir: Vector3 = a[1]
	if p.kind == "gun":
		var col := Color(def.get("tcol", "#ffd27a"))
		var rng: float = def.get("range", 600.0)
		var spread: float = def.get("spread", 0.0)
		for k in int(def.get("pellets", 1)):
			var d := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread).normalized()
			if def.has("pierce"):
				var ex: Array[RID] = _rids.duplicate()
				var from := mz
				for n in int(def.pierce):
					var h := Fx.hitscan(from, d, rng, def.dmg * pw, ex, col)
					if h.is_empty():
						break
					ex.append(h.rid)
					from = h.position
				Fx.tracer(mz, mz + d * 6.0, col)
			else:
				Fx.hitscan(mz, d, rng, def.dmg * pw, _rids, col)
		Fx.muzzle_flash(mz, dir, 0.8 if def.rate < 0.3 else 1.8)
		Sfx.play(def.get("snd", "mg"), mz, -6.0 if def.rate < 0.3 else -1.0, def.get("pitch", 1.0) * randf_range(0.95, 1.05))
		if p.has("spin"):
			p.spin.rotate_object_local(Vector3.BACK, 0.6)
	else:
		var proj: String = def.proj
		if def.get("drop", false):
			var down := -gb.y
			var bp: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, -0.7, 0))
			var pr := Fx.spawn_projectile(proj, bp, linear_velocity + down * 3.0, _rids, Vector3.INF, pw)
			pr.global_basis = gb * p.basis
			Sfx.play("pop", bp, -2.0, 0.5)
		else:
			if def.has("loft"):
				dir = (dir + gb.y * float(def.loft)).normalized()
			if def.has("spread"):
				dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(def.spread)).normalized()
			var tgt := aim_point if def.get("homing", false) or proj == "flak" else Vector3.INF
			var pr := Fx.spawn_projectile(proj, mz, dir * float(def.get("pspeed", 100.0)) + linear_velocity, _rids, tgt, def.get("power", 1.0) * pw)
			match proj:
				"rocket", "missile", "firework", "torpedo":
					Sfx.play("rocket", mz, -2.0, 0.8 if proj == "missile" else 1.0)
				"pbolt":
					Sfx.play("laser", mz, -8.0, 1.6)
					Sfx.play("hit", mz, -4.0, 0.5)
				_:
					Fx.muzzle_flash(mz, dir, 2.5 * def.get("power", 1.0))
					Fx.burst(mz, Color(0.6, 0.6, 0.6, 0.6), 10, 3.0, 0.5, 1.5, Vector3(0, 1, 0), 30.0, dir, false)
					Sfx.play("cannon", mz, 0.0, 1.3 / sqrt(def.get("power", 1.0)))
			pr.set_meta("owner", self)
		if def.has("recoil"):
			apply_impulse(-dir * def.recoil * pw, mz - global_position)
		if p.has("recoil"):
			var rc: Node3D = p.recoil
			rc.position.z = 0.4
			rc.create_tween().tween_property(rc, "position:z", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if p.has("bomb") and p.kind == "launcher":
		var bn: Node3D = p.bomb
		bn.visible = false
		get_tree().create_timer(minf(def.rate * 0.85, 1.1)).timeout.connect(bn.show)


func _laser(p: Dictionary, wp: Vector3, gb: Basis, firing: bool, delta: float) -> bool:
	var def: Dictionary = p.def
	var beam: Node3D = p.beam
	if firing and def.get("pulse", false):
		firing = fmod(_time * 5.0, 1.0) < 0.55
	beam.visible = firing
	if not firing:
		return false
	var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, -0.05, -0.65) * def.vs)
	var dir: Vector3 = gb * (p.basis * FWD)
	var q := PhysicsRayQueryParameters3D.create(mz, mz + dir * 350.0, Fx.MASK_SHOT, _rids)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	var len := 350.0
	if not h.is_empty():
		len = mz.distance_to(h.position)
		var c = h.collider
		var pw: float = p.cfg.get("pow", 100) / 100.0
		if c.has_method("take_hit"):
			c.take_hit(def.get("dps", 85.0) * delta * pw, h.position, h.shape, dir * 0.05)
		if randf() < 0.5:
			Fx.burst(h.position, Color(def.get("lcol", "#ff2244")), 3, 5.0, 0.06, 0.3, Vector3(0, -8, 0), 70.0, h.normal, true)
	var w: float = def.vs * (1.0 + randf() * 0.3)
	beam.scale = Vector3(w, w, len)
	return true


func _turret(p: Dictionary, wp: Vector3, firing: bool, delta: float, pw: float) -> void:
	var def: Dictionary = p.def
	var yaw: Node3D = p.yaw
	var pt: Node3D = p.pitch
	if aim_point != Vector3.INF:
		var frame: Basis = global_basis * p.basis
		var lt: Vector3 = frame.inverse() * (aim_point - yaw.global_position)
		var want_yaw := atan2(-lt.x, -lt.z)
		var want_pitch := clampf(atan2(lt.y, Vector2(lt.x, lt.z).length()), -0.35, 1.35)
		var rs := 5.0 if not def.has("proj") else 2.5
		yaw.rotation.y = rotate_toward(yaw.rotation.y, want_yaw, rs * delta)
		pt.rotation.x = move_toward(pt.rotation.x, want_pitch, rs * 0.8 * delta)
	if firing and p.st.cd <= 0.0:
		p.st.cd = def.rate
		var dir := -pt.global_basis.z
		if def.has("proj"):
			var mz := pt.global_transform * Vector3(0, 0, -1.35)
			Fx.spawn_projectile(def.proj, mz, dir * float(def.pspeed) + linear_velocity, _rids, Vector3.INF, def.get("power", 1.0) * pw)
			apply_impulse(-dir * 900.0 * pw, mz - global_position)
			Fx.muzzle_flash(mz, dir, 2.0)
			Sfx.play("cannon", mz, 0.0, 1.2)
			return
		var x := 0.0
		if def.id == "turret":
			p.st.side = 1 - int(p.st.side)
			x = -0.13 if p.st.side == 0 else 0.13
		var mz := pt.global_transform * Vector3(x, 0, -1.05)
		var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.01
		Fx.hitscan(mz, (dir + spread).normalized(), 600.0, def.dmg * pw, _rids, Color(def.get("tcol", "#9dff7a")))
		Fx.muzzle_flash(mz, dir, 0.7)
		Sfx.play("mg", mz, -8.0, 1.2 if def.id == "turret" else 1.8)


## Tesla coil: zap the nearest damageable things, chaining between them.
func _tesla(p: Dictionary, wp: Vector3, pw: float) -> void:
	var def: Dictionary = p.def
	var top: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, 0.4, 0))
	var from := top
	var hit := {}
	for n in 3:
		var best: Node3D = null
		var bd: float = def.radius
		for g in ["damageable", "props"]:
			for b in get_tree().get_nodes_in_group(g):
				if b == self or hit.has(b) or not (b is Node3D) or not is_instance_valid(b):
					continue
				var d: float = (b as Node3D).global_position.distance_to(from)
				if d < bd:
					bd = d
					best = b
		if best == null:
			break
		hit[best] = true
		var to := best.global_position
		_bolt(from, to)
		if best.has_method("take_hit"):
			best.take_hit(def.dmg * pw / (n + 1), to, 0, (to - from).normalized())
		elif best is RigidBody3D:
			(best as RigidBody3D).apply_central_impulse((to - from).normalized() * 200.0)
		from = to
	if hit.is_empty():
		var a := randf() * TAU
		_bolt(top, top + Vector3(cos(a) * 2.0, randf_range(-1.5, 0.5), sin(a) * 2.0))
	else:
		Sfx.play("hit", top, 0.0, 2.2)
		Sfx.play("laser", top, -6.0, 2.5)


func _confetti(p: Dictionary, wp: Vector3, gb: Basis) -> void:
	var mz: Vector3 = global_transform * (p.pos + p.basis * Vector3(0, 0, -0.6))
	var dir: Vector3 = gb * (p.basis * FWD)
	for k in 4:
		Fx.burst(mz, Color.from_hsv(randf(), 0.85, 1.0), 14, 14.0, 0.1, 1.6, Vector3(0, -6, 0), 25.0, (dir + Vector3.UP * 0.3).normalized(), false, true)
	Sfx.play("pop", mz, 2.0, randf_range(1.2, 1.6))


func _bolt(a: Vector3, b: Vector3) -> void:
	var segs := 6
	var prev := a
	for k in range(1, segs + 1):
		var t := float(k) / segs
		var pnt := a.lerp(b, t)
		if k < segs:
			pnt += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * a.distance_to(b) * 0.06
		Fx.tracer(prev, pnt, Color("#9fd8ff"))
		prev = pnt


func _melee(p: Dictionary, wp: Vector3, gb: Basis, com_w: Vector3, pw: float, delta: float) -> void:
	var def: Dictionary = p.def
	if p.has("spin"):
		p.spin.rotate_object_local(Vector3.BACK, def.get("spin", 0.0) * delta)
	p.st.cd -= delta
	var dir: Vector3 = gb * (p.basis * FWD)
	var reach: float = def.reach * def.vs
	var ups: Vector3 = gb * (p.basis * Vector3.UP)
	var rt: Vector3 = gb * (p.basis * Vector3.RIGHT)
	for o in [Vector3.ZERO, ups * 0.3, -ups * 0.3, rt * 0.3, -rt * 0.3]:
		var from: Vector3 = wp + o
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Fx.MASK_SHOT, _rids)
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty():
			continue
		var c = h.collider
		var dmg: float = def.dps * delta * pw
		if def.get("ram", 0.0) > 0.0 and p.st.cd <= 0.0:
			var closing := _pv(wp, com_w).dot(dir)
			if c is RigidBody3D:
				closing -= (c as RigidBody3D).linear_velocity.dot(dir)
			if closing > 3.0:
				dmg += def.ram * closing * pw
				p.st.cd = 0.3
				Sfx.play("hit", h.position, 2.0, 0.6)
		if dmg > 0.0:
			if c.has_method("take_hit"):
				c.take_hit(dmg, h.position, h.shape, dir)
			elif c is RigidBody3D:
				c.apply_impulse(dir * dmg * 3.0, h.position - c.global_position)
			if randf() < 0.5:
				Fx.sparks(h.position, h.normal)
		break


# ---------------------------------------------------------------- damage

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not alive or _crash_cd > 0.0:
		return
	var inv := state.transform.affine_inverse()
	for i in state.get_contact_count():
		var dv := state.get_contact_impulse(i).length() / maxf(mass, 1.0)
		if dv > 8.0:
			_crash.append([inv * state.get_contact_local_position(i), dv])


## Hard impacts break the blocks closest to the contact point.
func _apply_crash() -> void:
	var worst := 0.0
	var soft := 1.0 / (1.0 + 0.6 * airbags)
	for c in _crash:
		var lp: Vector3 = c[0]
		var dv: float = c[1]
		worst = maxf(worst, dv)
		var hits := []
		var cushion := 1.0
		for i in parts.size():
			if parts[i].alive:
				var d2: float = lp.distance_squared_to(parts[i].pos)
				hits.append([d2, i])
				if d2 < 2.5 and parts[i].def.get("absorb", false):
					cushion = 0.25
		hits.sort_custom(func(a, b): return a[0] < b[0])
		for k in mini(3, hits.size()):
			damage_part(hits[k][1], (dv - 8.0) * 22.0 / (k + 1) * soft * cushion / dmg_mult)
			if not alive:
				break
		if not alive:
			break
	_crash.clear()
	_crash_cd = 0.25
	if worst > 12.0:
		Sfx.play("hit", com_world(), 4.0, 0.45)
		Fx.shake.emit(com_world(), worst * 0.04)


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
	p.hp -= dmg * dmg_mult
	if p.hp <= 0.0:
		destroy_part(i)


func destroy_part(i: int, quiet := false) -> void:
	var p: Dictionary = parts[i]
	if not p.alive:
		return
	p.alive = false
	var wp: Vector3 = global_transform * p.pos
	if not quiet:
		Fx.debris_burst(wp, p.color)
		Sfx.play("pop" if p.kind == "balloon" else "hit", wp, 0.0, 0.6)
	p.node.queue_free()
	p.shape.queue_free()
	if p.has("dust"):
		p.dust.queue_free()
		p.erase("dust")
	if p.def.has("boom"):
		Fx.explode.call_deferred(wp, p.def.boom, p.def.bdmg)
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


## Cells of the living parts connected to the part at cell `start`.
func _flood(start: Vector3i) -> Dictionary:
	var i0: int = by_cell[start]
	var seen := {start: true}
	var done := {i0: true}
	var stack := [i0]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for j: int in adj[i]:
			if done.has(j) or not parts[j].alive:
				continue
			done[j] = true
			seen[parts[j].cell] = true
			stack.append(j)
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
		m += p.mass
		c += p.pos * p.mass
		var node: Node3D = p.node
		for nm in ["flame", "beam", "canopy", "lamp", "lamp2", "field", "led", "led2"]:
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
		var r: float = p.hy
		if p.kind == "wheel":
			r = p.def.radius + p.def.travel * 0.5
			if p.susp >= 0:
				r += parts[p.susp].def.travel * 0.5
		elif p.kind == "hover":
			r = p.def.height
		lo = minf(lo, p.pos.y - r)
	return lo
