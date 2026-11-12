extends Node3D
## Ballistic projectile moved by ray sweeps: shells, rockets, missiles, bombs,
## grenades, torpedoes, mines, flak, fireworks, flares and enemy plasma.

var kind := "shell"
var vel := Vector3.ZERO
var exclude: Array[RID] = []
var target := Vector3.INF
var power := 1.0
var life := 8.0
var _age := 0.0
var _smoke_t := 0.0
var _bounces := 0
var _landed := false
var _fuse := INF


func _ready() -> void:
	var M := Blocks
	match kind:
		"shell", "flak", "bomblet":
			var m := M._mi(self, M.sphere_mesh(0.14 * clampf(sqrt(power), 0.7, 1.6)), Vector3.ZERO, M.glow_mat(Color("#ffcf6a"), 4.0))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind == "bomblet":
				life = 6.0
		"rocket", "missile":
			var s := 1.0 if kind == "rocket" else 1.8
			var body := Node3D.new()
			body.name = "body"
			add_child(body)
			M._mi(body, M.cyl_mesh(0.09 * s, 0.09 * s, 0.7 * s, 8), Vector3.ZERO, M.mat(Color("#e8e8e8"), 0.3, 0.4), Vector3(PI * 0.5, 0, 0))
			M._mi(body, M.cyl_mesh(0.0, 0.09 * s, 0.2 * s, 8), Vector3(0, 0, -0.45 * s), M.mat(Color("#e53935"), 0.3, 0.4), Vector3(-PI * 0.5, 0, 0))
			M._mi(body, M.sphere_mesh(0.14 * s), Vector3(0, 0, 0.42 * s), M.glow_mat(Color("#ffb347"), 5.0, true))
			life = 6.0 if kind == "rocket" else 9.0
		"bomb", "cluster", "bigbomb":
			var s := 1.0 if kind != "bigbomb" else 2.0
			var body := Node3D.new()
			body.name = "body"
			add_child(body)
			var c := Color("#2f3a28") if kind == "bomb" else (Color("#6d4c41") if kind == "cluster" else Color("#2b2f36"))
			M._mi(body, M.capsule_mesh(0.22 * s, 0.85 * s), Vector3.ZERO, M.mat(c, 0.4, 0.5), Vector3(PI * 0.5, 0, 0))
			M._mi(body, M.box_mesh(Vector3(0.4, 0.04, 0.2) * s), Vector3(0, 0, 0.42 * s), M.mat(Color("#2b2f36"), 0.4, 0.5))
			if kind == "bigbomb":
				M._mi(body, M.box_mesh(Vector3(0.46, 0.1, 0.3)), Vector3(0, 0, 0), M.mat(Color("#ffcc00"), 0.2, 0.5))
			life = 25.0
		"grenade":
			M._mi(self, M.sphere_mesh(0.16), Vector3.ZERO, M.mat(Color("#5c6b4a"), 0.4, 0.5))
			M._mi(self, M.sphere_mesh(0.05), Vector3(0, 0.15, 0), M.glow_mat(Color("#ff2020"), 4.0))
			_fuse = 2.2
		"torpedo":
			var body := Node3D.new()
			body.name = "body"
			add_child(body)
			M._mi(body, M.capsule_mesh(0.18, 1.2), Vector3.ZERO, M.mat(Color("#37474f"), 0.6, 0.35), Vector3(PI * 0.5, 0, 0))
			M._mi(body, M.sphere_mesh(0.14), Vector3(0, 0, -0.5), M.mat(Color("#ffcc00"), 0.4, 0.4))
			life = 14.0
		"mine":
			M._mi(self, M.cyl_mesh(0.3, 0.32, 0.14, 12), Vector3.ZERO, M.mat(Color("#5c6b4a"), 0.4, 0.5))
			var led := M._mi(self, M.sphere_mesh(0.05), Vector3(0, 0.08, 0), M.glow_mat(Color("#ff2020"), 5.0))
			led.name = "led"
			life = 60.0
		"pbolt", "plasma":
			var c := Color("#c05cff")
			M._mi(self, M.sphere_mesh(0.3), Vector3.ZERO, M.glow_mat(c, 5.0, true))
			M._mi(self, M.sphere_mesh(0.15), Vector3.ZERO, M.glow_mat(Color(1, 0.9, 1), 6.0))
			life = 6.0
		"firework":
			M._mi(self, M.cyl_mesh(0.06, 0.06, 0.4, 8), Vector3.ZERO, M.mat(Color.from_hsv(randf(), 0.8, 1.0), 0.2, 0.5), Vector3(PI * 0.5, 0, 0))
			M._mi(self, M.sphere_mesh(0.1), Vector3(0, 0, 0.22), M.glow_mat(Color("#ffd27a"), 5.0, true))
			_fuse = randf_range(1.1, 1.5)
		"flare":
			M._mi(self, M.sphere_mesh(0.18), Vector3.ZERO, M.glow_mat(Color("#ffe08a"), 8.0, true))
			var l := OmniLight3D.new()
			l.light_color = Color("#ffb347")
			l.light_energy = 3.0
			l.omni_range = 10.0
			add_child(l)
			life = 4.0


func _physics_process(delta: float) -> void:
	if kind == "flak" and _fuse == INF and target != Vector3.INF:
		# burst right where the crosshair is
		_fuse = maxf(global_position.distance_to(target) - 2.0, 3.0) / maxf(vel.length(), 1.0)
	_age += delta
	if _age > life:
		if kind in ["rocket", "missile", "grenade", "bomblet", "flak"]:
			_impact(global_position, {})
		else:
			queue_free()
		return
	if _age > _fuse:
		_impact(global_position, {})
		return
	if _landed:
		_mine_tick()
		return
	match kind:
		"shell", "grenade", "bomblet", "flak", "mine":
			vel.y -= 9.8 * delta
		"bomb", "cluster", "bigbomb":
			vel.y -= 9.8 * delta
			vel *= 1.0 - 0.02 * delta
			if kind == "cluster" and _age > 0.8:
				for k in 8:
					var v := vel + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)) * 9.0
					Fx.spawn_projectile("bomblet", global_position, v, exclude)
				Sfx.play("pop", global_position, 0.0, 0.6)
				queue_free()
				return
		"rocket", "missile":
			var acc := 70.0 if kind == "rocket" else 45.0
			var spd := minf(vel.length() + acc * delta, 170.0 if kind == "rocket" else 140.0)
			var d := vel.normalized()
			if target != Vector3.INF and _age > 0.15:
				var want := (target - global_position).normalized()
				d = d.slerp(want, clampf(delta * (3.0 if kind == "rocket" else 2.0), 0.0, 1.0)).normalized()
			vel = d * spd
			_trail(-d, 0.03 if kind == "rocket" else 0.02, 0.22 if kind == "rocket" else 0.4)
		"torpedo":
			if global_position.y > Fx.WATER - 0.3:
				vel.y -= 9.8 * delta
				vel *= 1.0 - 0.3 * delta
			else:
				var h := Vector3(vel.x, 0, vel.z)
				var d := h.normalized() if h.length() > 0.5 else -global_basis.z
				if target != Vector3.INF and _age > 0.4:
					var want := Vector3(target.x - global_position.x, 0, target.z - global_position.z).normalized()
					d = d.slerp(want, clampf(delta * 1.2, 0.0, 1.0)).normalized()
				var spd := minf(h.length() + 30.0 * delta, 42.0)
				vel = d * spd + Vector3(0, (Fx.WATER - 1.0 - global_position.y) * 2.0, 0)
				_trail(-d, 0.05, 0.2, Color(0.9, 0.97, 1.0, 0.7))
		"firework":
			vel.y -= 3.0 * delta
			_trail(-vel.normalized(), 0.025, 0.12, Color(1.0, 0.85, 0.4, 0.9), true)
		"flare":
			vel.y -= 4.0 * delta
			vel *= 1.0 - 1.2 * delta
			_trail(Vector3.UP, 0.05, 0.25, Color(0.9, 0.9, 0.9, 0.5))
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Fx.MASK_SHOT, exclude)
	var h := Fx.space().intersect_ray(q)
	if not h.is_empty():
		if kind == "grenade" and _bounces < 3:
			_bounces += 1
			vel = vel.bounce(h.normal) * 0.45
			global_position = h.position + h.normal * 0.15
			return
		if kind == "mine":
			global_position = h.position + h.normal * 0.08
			global_basis = Basis(Quaternion(Vector3.UP, h.normal))
			_land()
			return
		if kind == "flare":
			queue_free()
			return
		_impact(h.position, h)
		return
	if to.y < Fx.WATER and from.y >= Fx.WATER and Fx.over_water(to):
		Fx.splash(to, 1.2)
		match kind:
			"bomb", "cluster", "bigbomb":
				_impact(Vector3(to.x, Fx.WATER - 0.2, to.z), {})
				return
			"torpedo", "plasma", "pbolt", "flare":
				pass
			"mine":
				global_position = Vector3(to.x, Fx.WATER, to.z)
				_land()
				return
			_:
				Fx.explode(Vector3(to.x, Fx.WATER, to.z), 2.5 * sqrt(power), 25.0 * power, false)
				queue_free()
				return
	global_position = to
	if vel.length() > 0.5:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT
		global_basis = Basis.looking_at(vel.normalized(), up)


func _trail(dir: Vector3, every: float, size: float, col := Color(0.85, 0.85, 0.85, 0.6), add := false) -> void:
	_smoke_t -= get_physics_process_delta_time()
	if _smoke_t <= 0.0:
		_smoke_t = every
		Fx.burst(global_position, col, 2, 0.6, size, 1.2, Vector3(0, 0.6, 0), 30.0, dir, add)


func _land() -> void:
	_landed = true
	vel = Vector3.ZERO
	_age = 0.0


func _mine_tick() -> void:
	var led := get_node_or_null("led")
	if led:
		led.visible = fmod(_age, 0.8) < 0.15
	if _age < 1.5:
		return
	for g in ["vehicle", "targets", "props"]:
		for n in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(n) or not (n is Node3D):
				continue
			if n is CollisionObject3D and (n as CollisionObject3D).get_rid() in exclude:
				continue
			if (n as Node3D).global_position.distance_to(global_position) < 3.5:
				_impact(global_position, {})
				return


func _impact(p: Vector3, h: Dictionary) -> void:
	var sp := sqrt(power)
	match kind:
		"shell":
			Fx.explode(p, 4.5 * sp, 70.0 * power, power > 1.5)
		"bomblet":
			Fx.explode(p, 3.5, 40.0, false)
		"flak":
			Fx.explode(p, 6.0, 35.0 * power, false)
		"rocket":
			Fx.explode(p, 5.0 * sp, 55.0 * power, false)
		"missile":
			Fx.explode(p, 8.0 * sp, 120.0 * power)
		"grenade":
			Fx.explode(p, 5.0 * sp, 60.0 * power, false)
		"bomb", "cluster":
			Fx.explode(p, 10.0, 160.0 * power)
		"bigbomb":
			Fx.explode(p, 22.0, 420.0 * power)
			Fx.shake.emit(p, 3.0)
		"torpedo":
			Fx.explode(p, 9.0 * sp, 150.0 * power)
		"mine":
			Fx.explode(p, 7.0 * sp, 120.0 * power)
		"pbolt":
			Fx.explode(p, 3.5 * sp, 45.0 * power, false)
			Fx.burst(p, Color("#c05cff"), 14, 6.0, 0.15, 0.4, Vector3.ZERO, 180.0, Vector3.UP, true)
		"firework":
			var c := Color.from_hsv(randf(), 0.8, 1.0)
			Fx.burst(p, c, 60, 16.0, 0.22, 1.6, Vector3(0, -3, 0), 180.0, Vector3.UP, true)
			Fx.burst(p, Color.from_hsv(fmod(c.h + 0.5, 1.0), 0.6, 1.0), 30, 9.0, 0.16, 1.2, Vector3(0, -3, 0), 180.0, Vector3.UP, true)
			Sfx.play("explosion", p, -6.0, 2.2)
		"plasma":
			var c = h.get("collider")
			if c != null and c.has_method("take_hit"):
				c.take_hit(28.0, p, h.shape, vel.normalized())
			Fx.burst(p, Color("#c05cff"), 14, 6.0, 0.15, 0.4, Vector3.ZERO, 180.0, Vector3.UP, true)
			Sfx.play("hit", p, -2.0, 0.7)
	queue_free()
