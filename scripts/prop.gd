extends RigidBody3D
## Physics prop: crates get knocked around, barrels explode.

var kind := "crate"
var hp := 25.0
var _dead := false


func setup(k: String, size: float, col: Color) -> void:
	kind = k
	collision_layer = Fx.L_PROPS
	collision_mask = Fx.L_WORLD | Fx.L_VEHICLE | Fx.L_PROPS | Fx.L_TARGET
	add_to_group("props")
	add_to_group("magnetic")
	var cs := CollisionShape3D.new()
	if kind == "barrel":
		add_to_group("damageable")
		mass = 60.0
		hp = 18.0
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45
		cyl.height = 1.2
		cs.shape = cyl
		Blocks._mi(self, Blocks.cyl_mesh(0.45, 0.45, 1.2, 14), Vector3.ZERO, Blocks.mat(col, 0.4, 0.45))
		for y in [-0.35, 0.35]:
			Blocks._mi(self, Blocks.cyl_mesh(0.46, 0.46, 0.06, 14), Vector3(0, y, 0), Blocks.mat(col.darkened(0.4), 0.5, 0.4))
		Blocks._mi(self, Blocks.box_mesh(Vector3(0.5, 0.3, 0.02)), Vector3(0, 0.05, -0.455), Blocks.mat(Color("#ffd400"), 0.0, 0.6))
	else:
		mass = 30.0 * size * size * size
		var b := BoxShape3D.new()
		b.size = Vector3.ONE * size
		cs.shape = b
		Blocks._mi(self, Blocks.box_mesh(Vector3.ONE * size), Vector3.ZERO, Blocks.block_mat(col, 0.0, 0.85))
		Blocks._mi(self, Blocks.box_mesh(Vector3(size * 1.01, size * 0.12, size * 1.01)), Vector3.ZERO, Blocks.mat(col.darkened(0.3), 0.0, 0.9))
		Blocks._mi(self, Blocks.box_mesh(Vector3(size * 0.12, size * 1.01, size * 1.01)), Vector3.ZERO, Blocks.mat(col.darkened(0.3), 0.0, 0.9))
	add_child(cs)
	can_sleep = true


func take_hit(dmg: float, pos: Vector3, _shape: int, dir: Vector3) -> void:
	sleeping = false
	apply_impulse(dir * dmg * 4.0, pos - global_position)
	if kind == "barrel":
		hp -= dmg
		if hp <= 0.0:
			_boom()


func take_blast(pos: Vector3, radius: float, dmg: float) -> void:
	if kind != "barrel" or _dead:
		return
	if global_position.distance_to(pos) < radius + 0.5:
		hp -= dmg
		if hp <= 0.0:
			_boom.call_deferred()


func _boom() -> void:
	if _dead:
		return
	_dead = true
	var p := global_position
	queue_free()
	Fx.explode(p, 7.0, 110.0)
	Fx.event.emit("barrel", "Barrel go boom!")
