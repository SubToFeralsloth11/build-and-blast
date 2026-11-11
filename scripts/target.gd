extends AnimatableBody3D
## Destructible targets: practice dummies, flying drones, target boats and
## enemy turrets that shoot back. They respawn after a while.

var kind := "dummy"
var max_hp := 60.0
var hp := 60.0
var dead := false
var center := Vector3.ZERO
var radius := 0.0
var speed := 0.0
var phase := 0.0
var world: Node
var _vis: Node3D
var _head: Node3D
var _cd := 2.0


func setup(k: String, pos: Vector3, w: Node, r := 0.0, spd := 0.0) -> void:
	kind = k
	world = w
	center = pos
	radius = r
	speed = spd
	phase = randf() * TAU
	collision_layer = Fx.L_TARGET
	collision_mask = 0
	sync_to_physics = false
	add_to_group("damageable")
	add_to_group("targets")
	_vis = Node3D.new()
	add_child(_vis)
	var cs := CollisionShape3D.new()
	match kind:
		"dummy":
			max_hp = 70.0
			var b := BoxShape3D.new()
			b.size = Vector3(2.4, 3.6, 0.5)
			cs.shape = b
			cs.position = Vector3(0, 1.8, 0)
			Blocks._mi(_vis, Blocks.box_mesh(Vector3(0.25, 3.6, 0.25)), Vector3(0, 1.0, 0.2), Blocks.mat(Color("#7a5230"), 0.0, 0.9))
			var cols := [Color("#e53935"), Color.WHITE, Color("#e53935"), Color.WHITE, Color("#ffcc00")]
			for i in 5:
				var rr := 1.2 - i * 0.24
				Blocks._mi(_vis, Blocks.cyl_mesh(rr, rr, 0.1 + i * 0.02, 24), Vector3(0, 2.2, 0), Blocks.mat(cols[i], 0.0, 0.7), Vector3(PI * 0.5, 0, 0))
		"drone":
			max_hp = 45.0
			var s := SphereShape3D.new()
			s.radius = 1.6
			cs.shape = s
			Blocks._mi(_vis, Blocks.sphere_mesh(0.9), Vector3.ZERO, Blocks.mat(Color("#2b2f36"), 0.6, 0.3))
			Blocks._mi(_vis, Blocks.sphere_mesh(0.35), Vector3(0, 0, -0.75), Blocks.glow_mat(Color("#ff3355"), 4.0))
			for a in 4:
				var ang := a * TAU / 4.0 + PI / 4.0
				var arm := Vector3(cos(ang), 0, sin(ang)) * 1.4
				Blocks._mi(_vis, Blocks.box_mesh(Vector3(0.15, 0.1, 1.4)), arm * 0.5, Blocks.mat(Color("#444b55"), 0.5, 0.4), Vector3(0, -ang + PI * 0.5, 0))
				Blocks._mi(_vis, Blocks.cyl_mesh(0.55, 0.55, 0.04, 16), arm + Vector3(0, 0.15, 0), Blocks.glow_mat(Color("#ff8a3d"), 1.2, true))
		"boat":
			max_hp = 160.0
			var b := BoxShape3D.new()
			b.size = Vector3(4, 2.4, 9)
			cs.shape = b
			cs.position = Vector3(0, 0.6, 0)
			Blocks._mi(_vis, Blocks.box_mesh(Vector3(4, 1.6, 8)), Vector3(0, 0.3, 0.4), Blocks.mat(Color("#c62828"), 0.2, 0.5))
			Blocks._mi(_vis, Blocks.wedge_mesh(), Vector3(0, 0.3, -4.2), Blocks.mat(Color("#c62828"), 0.2, 0.5), Vector3.ZERO).scale = Vector3(4, 1.6, 1.2)
			Blocks._mi(_vis, Blocks.box_mesh(Vector3(4.05, 0.3, 8.05)), Vector3(0, -0.3, 0.4), Blocks.mat(Color.WHITE, 0.2, 0.5))
			Blocks._mi(_vis, Blocks.box_mesh(Vector3(2.4, 1.6, 3)), Vector3(0, 1.9, 1.5), Blocks.mat(Color("#eceff1"), 0.1, 0.5))
			Blocks._mi(_vis, Blocks.box_mesh(Vector3(2.45, 0.5, 2.0)), Vector3(0, 2.2, 1.2), Blocks.mat(Color("#263238"), 0.6, 0.2))
			Blocks._mi(_vis, Blocks.cyl_mesh(0.08, 0.08, 3.0, 6), Vector3(0, 3.8, 2.5), Blocks.mat(Color("#cfd8dc"), 0.7, 0.3))
		"turret":
			max_hp = 220.0
			var b := BoxShape3D.new()
			b.size = Vector3(4, 3.4, 4)
			cs.shape = b
			cs.position = Vector3(0, 1.7, 0)
			Blocks._mi(_vis, Blocks.cyl_mesh(2.0, 2.4, 1.6, 8), Vector3(0, 0.8, 0), Blocks.mat(Color("#3a3f47"), 0.5, 0.5))
			_head = Node3D.new()
			_head.position = Vector3(0, 2.2, 0)
			_vis.add_child(_head)
			Blocks._mi(_head, Blocks.sphere_mesh(1.4, true), Vector3.ZERO, Blocks.mat(Color("#5b2a86"), 0.5, 0.35))
			Blocks._mi(_head, Blocks.cyl_mesh(0.22, 0.28, 2.6, 10), Vector3(0, 0.7, -1.6), Blocks.mat(Color("#2b2f36"), 0.7, 0.3), Vector3(PI * 0.5, 0, 0))
			Blocks._mi(_head, Blocks.sphere_mesh(0.3), Vector3(0, 0.7, -2.9), Blocks.glow_mat(Color("#c05cff"), 5.0))
			Blocks._mi(_head, Blocks.sphere_mesh(0.25), Vector3(0, 1.1, -0.9), Blocks.glow_mat(Color("#ff2244"), 4.0))
	add_child(cs)
	hp = max_hp
	_place(0.0)


func _place(t: float) -> void:
	match kind:
		"drone":
			var a := phase + t * speed / maxf(radius, 1.0)
			var p := center + Vector3(cos(a) * radius, sin(t * 0.7 + phase) * 6.0, sin(a) * radius)
			global_position = p
			_vis.rotation.y = -a
		"boat":
			var a := phase + t * speed / maxf(radius, 1.0)
			global_position = center + Vector3(cos(a) * radius, 0.15 + sin(t * 1.3) * 0.15, sin(a) * radius)
			_vis.rotation = Vector3(sin(t * 1.1) * 0.03, -a, sin(t * 0.9) * 0.04)
		_:
			global_position = center


var _t := 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if kind == "drone" or kind == "boat":
		_place(_t)
	elif kind == "turret":
		_turret(delta)


func _turret(delta: float) -> void:
	if world == null or not world.enemies:
		return
	var v = world.player
	if v == null or not is_instance_valid(v) or not v.alive:
		return
	var tp: Vector3 = v.com_world()
	var d := tp.distance_to(_head.global_position)
	if d > 260.0:
		return
	var lead: Vector3 = tp + v.linear_velocity * (d / 70.0) * 0.8
	var to := lead - _head.global_position
	var yaw := atan2(-to.x, -to.z)
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, 1.6 * delta)
	_cd -= delta
	if _cd <= 0.0 and absf(angle_difference(_head.rotation.y, yaw)) < 0.2:
		_cd = 2.4
		var mz := _head.global_transform * Vector3(0, 0.7, -3.0)
		var dir := (lead - mz).normalized()
		Fx.spawn_projectile("plasma", mz, dir * 70.0, [get_rid()])
		Sfx.play("laser", mz, -2.0, 0.5)


func take_hit(dmg: float, _pos: Vector3, _shape: int, _dir: Vector3) -> void:
	if dead:
		return
	hp -= dmg
	_vis.scale = Vector3.ONE * 1.08
	_vis.create_tween().tween_property(_vis, "scale", Vector3.ONE, 0.12)
	if hp <= 0.0:
		_die()


func take_blast(pos: Vector3, r: float, dmg: float) -> void:
	if dead:
		return
	var d := global_position.distance_to(pos)
	var reach := r + (3.0 if kind == "boat" or kind == "turret" else 1.5)
	if d < reach:
		take_hit(dmg * (1.0 - d / reach * 0.7), pos, 0, Vector3.ZERO)


func _die() -> void:
	dead = true
	var p := global_position + Vector3.UP
	Fx.explode.call_deferred(p, 6.0 if kind != "dummy" else 3.0, 30.0)
	var names := {"dummy": "Target down", "drone": "Drone shot down", "boat": "Boat sunk", "turret": "Enemy turret destroyed"}
	Fx.event.emit("target", names.get(kind, "Target destroyed"))
	visible = false
	collision_layer = 0
	get_tree().create_timer(22.0).timeout.connect(_respawn)


func _respawn() -> void:
	dead = false
	hp = max_hp
	visible = true
	collision_layer = Fx.L_TARGET
	_place(_t)
