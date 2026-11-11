extends Node3D
## Ballistic projectile moved by ray sweeps (shell, rocket, bomb, enemy plasma).

var kind := "shell"
var vel := Vector3.ZERO
var exclude: Array[RID] = []
var target := Vector3.INF
var life := 8.0
var _age := 0.0
var _smoke_t := 0.0


func _ready() -> void:
	match kind:
		"shell":
			var m := Blocks._mi(self, Blocks.sphere_mesh(0.14), Vector3.ZERO, Blocks.glow_mat(Color("#ffcf6a"), 4.0))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"rocket":
			var body := Node3D.new()
			body.name = "body"
			add_child(body)
			Blocks._mi(body, Blocks.cyl_mesh(0.09, 0.09, 0.7, 8), Vector3.ZERO, Blocks.mat(Color("#e8e8e8"), 0.3, 0.4), Vector3(PI * 0.5, 0, 0))
			Blocks._mi(body, Blocks.cyl_mesh(0.0, 0.09, 0.2, 8), Vector3(0, 0, -0.45), Blocks.mat(Color("#e53935"), 0.3, 0.4), Vector3(-PI * 0.5, 0, 0))
			Blocks._mi(body, Blocks.sphere_mesh(0.14), Vector3(0, 0, 0.42), Blocks.glow_mat(Color("#ffb347"), 5.0, true))
			life = 6.0
		"bomb":
			var body := Node3D.new()
			body.name = "body"
			add_child(body)
			Blocks._mi(body, Blocks.capsule_mesh(0.22, 0.85), Vector3.ZERO, Blocks.mat(Color("#2f3a28"), 0.4, 0.5), Vector3(PI * 0.5, 0, 0))
			Blocks._mi(body, Blocks.box_mesh(Vector3(0.4, 0.04, 0.2)), Vector3(0, 0, 0.42), Blocks.mat(Color("#2b2f36"), 0.4, 0.5))
			life = 25.0
		"plasma":
			Blocks._mi(self, Blocks.sphere_mesh(0.3), Vector3.ZERO, Blocks.glow_mat(Color("#c05cff"), 5.0, true))
			Blocks._mi(self, Blocks.sphere_mesh(0.15), Vector3.ZERO, Blocks.glow_mat(Color(1, 0.9, 1), 6.0))
			life = 6.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > life:
		if kind == "rocket":
			Fx.explode(global_position, 4.0, 40.0, false)
		queue_free()
		return
	match kind:
		"shell":
			vel.y -= 9.8 * delta
		"bomb":
			vel.y -= 9.8 * delta
			vel *= 1.0 - 0.02 * delta
		"rocket":
			var spd := minf(vel.length() + 70.0 * delta, 170.0)
			var d := vel.normalized()
			if target != Vector3.INF and _age > 0.15:
				var want := (target - global_position).normalized()
				d = d.slerp(want, clampf(delta * 3.0, 0.0, 1.0)).normalized()
			vel = d * spd
			_smoke_t -= delta
			if _smoke_t <= 0.0:
				_smoke_t = 0.03
				Fx.burst(global_position, Color(0.85, 0.85, 0.85, 0.6), 2, 0.6, 0.22, 1.2, Vector3(0, 0.6, 0), 30.0, -d, false)
	var from := global_position
	var to := from + vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Fx.MASK_SHOT, exclude)
	var h := Fx.space().intersect_ray(q)
	if not h.is_empty():
		_impact(h.position, h)
		return
	if to.y < Fx.WATER and from.y >= Fx.WATER and Fx.over_water(to):
		Fx.splash(to, 1.2)
		if kind == "bomb":
			Fx.explode(Vector3(to.x, Fx.WATER - 0.2, to.z), 9.0, 120.0)
		elif kind == "plasma":
			pass
		else:
			Fx.explode(Vector3(to.x, Fx.WATER, to.z), 2.5, 25.0, false)
		queue_free()
		return
	global_position = to
	if vel.length() > 0.5:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT
		global_basis = Basis.looking_at(vel.normalized(), up)


func _impact(p: Vector3, h: Dictionary) -> void:
	match kind:
		"shell":
			Fx.explode(p, 4.5, 70.0, false)
		"rocket":
			Fx.explode(p, 5.0, 55.0, false)
		"bomb":
			Fx.explode(p, 10.0, 160.0)
		"plasma":
			var c = h.collider
			if c.has_method("take_hit"):
				c.take_hit(28.0, p, h.shape, vel.normalized())
			Fx.burst(p, Color("#c05cff"), 14, 6.0, 0.15, 0.4, Vector3.ZERO, 180.0, Vector3.UP, true)
			Sfx.play("hit", p, -2.0, 0.7)
	queue_free()
