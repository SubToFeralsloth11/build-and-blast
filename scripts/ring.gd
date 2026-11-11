extends Area3D
## Sky course ring. The world tells it whether it is the active one.

signal passed(idx: int)

var idx := 0
var _mesh: MeshInstance3D
var _active_mat: Material
var _idle_mat: Material


func setup(i: int) -> void:
	idx = i
	collision_layer = 0
	collision_mask = Fx.L_VEHICLE
	monitoring = true
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 7.0
	cyl.height = 3.0
	cs.shape = cyl
	cs.rotation.x = PI * 0.5
	add_child(cs)
	_active_mat = Blocks.glow_mat(Color("#ffd23f"), 2.5)
	_idle_mat = Blocks.glow_mat(Color("#3fa9ff"), 0.6)
	_mesh = Blocks._mi(self, Blocks.torus_mesh(7.0, 8.0), Vector3.ZERO, _idle_mat, Vector3(PI * 0.5, 0, 0))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_entered.connect(_on_body)


func set_active(on: bool) -> void:
	_mesh.material_override = _active_mat if on else _idle_mat
	_mesh.scale = Vector3.ONE * (1.0 if on else 0.8)


func _on_body(b: Node) -> void:
	if b.is_in_group("vehicle"):
		passed.emit(idx)
