extends CharacterBody3D
## The pilot on foot: walks, sprints, jumps and swims around the test arena.
## Reads the vehicle input actions (WASD, Space, Shift) while Controls is disabled.
## main.gd owns the camera and feeds mouse look through `look()`.

## Own collision layer: vehicles and shots pass through the pilot, but the
## pilot still collides with (and can stand on) the world, vehicles and props.
const L_PILOT := 16
const WALK := 4.5
const SPRINT := 8.0
const SWIM := 2.4
const JUMP := 5.2
const EYE := 1.62
## How far the feet hang below the surface while floating (head stays above water).
const FLOAT_DEPTH := 1.3
const SUIT := Color("#e9edf2")
const LIMB := Color("#3a4049")
const ACCENT := Color("#ff7a2f")

var yaw := 0.0
var pitch := 0.0
var first_person := true
var swimming := false

var _gravity := 9.8
var _vis: Node3D
var _torso: Node3D
var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _phase := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = L_PILOT
	collision_mask = Fx.L_WORLD | Fx.L_VEHICLE | Fx.L_PROPS | Fx.L_TARGET
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	_build_body()
	set_first_person(first_person)


func _build_body() -> void:
	_vis = Node3D.new()
	_vis.name = "Body"
	add_child(_vis)
	var suit := Blocks.mat(SUIT, 0.3, 0.4)
	var limb := Blocks.mat(LIMB, 0.3, 0.6)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 0.92, 0)
	_vis.add_child(_torso)
	var chest := CapsuleMesh.new()
	chest.radius = 0.21
	chest.height = 0.7
	chest.radial_segments = 12
	chest.rings = 3
	Blocks._mi(_torso, chest, Vector3(0, 0.34, 0), suit)
	Blocks._mi(_torso, Blocks.box_mesh(Vector3(0.36, 0.14, 0.24)), Vector3(0, 0.02, 0), limb)
	Blocks._mi(_torso, Blocks.box_mesh(Vector3(0.3, 0.36, 0.14)), Vector3(0, 0.4, 0.2), Blocks.mat(ACCENT, 0.2, 0.5))
	Blocks._mi(_torso, Blocks.sphere_mesh(0.17), Vector3(0, 0.82, 0), Blocks.mat(Color("#f4f6f9"), 0.3, 0.3))
	Blocks._mi(_torso, Blocks.box_mesh(Vector3(0.26, 0.08, 0.06)), Vector3(0, 0.84, -0.15), Blocks.glow_mat(Color("#39e1ff"), 2.5))
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.11 * s, 0.92, 0)
		_vis.add_child(leg)
		Blocks._mi(leg, Blocks.box_mesh(Vector3(0.15, 0.44, 0.17)), Vector3(0, -0.22, 0), suit)
		var shin := Node3D.new()
		shin.position = Vector3(0, -0.44, 0)
		leg.add_child(shin)
		Blocks._mi(shin, Blocks.box_mesh(Vector3(0.13, 0.42, 0.15)), Vector3(0, -0.21, 0), limb)
		Blocks._mi(shin, Blocks.box_mesh(Vector3(0.16, 0.08, 0.27)), Vector3(0, -0.44, -0.05), limb)
		_legs.append(leg)
		_shins.append(shin)
		var arm := Node3D.new()
		arm.position = Vector3(0.29 * s, 0.6, 0)
		_torso.add_child(arm)
		Blocks._mi(arm, Blocks.box_mesh(Vector3(0.11, 0.56, 0.12)), Vector3(0, -0.28, 0), suit)
		Blocks._mi(arm, Blocks.sphere_mesh(0.065), Vector3(0, -0.6, 0), limb)
		_arms.append(arm)


## First person hides the body from the camera but keeps its shadow.
func set_first_person(on: bool) -> void:
	first_person = on
	if _vis == null:
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for m in _vis.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = mode


func look(rel: Vector2) -> void:
	yaw -= rel.x * 0.0035
	pitch = clampf(pitch - rel.y * 0.0035, -1.45, 1.45)


func eye_position() -> Vector3:
	return global_position + Vector3(0, EYE, 0)


func _physics_process(delta: float) -> void:
	_t += delta
	var inp := Input.get_vector("v_left", "v_right", "v_fwd", "v_back")
	var dir := Basis(Vector3.UP, yaw) * Vector3(inp.x, 0, inp.y)
	var sprint := Input.is_action_pressed("v_boost")
	var float_y := Fx.WATER - FLOAT_DEPTH
	swimming = global_position.y < float_y + 0.5 and Fx.over_water(global_position)
	var hv := Vector3(velocity.x, 0, velocity.z)
	if swimming:
		hv = hv.move_toward(dir * SWIM * (1.5 if sprint else 1.0), 6.0 * delta)
		# buoyancy pulls the pilot to floating depth with a gentle bob
		var target := float_y + sin(_t * 2.2) * 0.05
		var want := clampf((target - global_position.y) * 3.0, -3.0, 2.5)
		if Input.is_action_pressed("v_up"):
			want = maxf(want, 1.6)
		velocity.y = move_toward(velocity.y, want, 14.0 * delta)
	else:
		var on_floor := is_on_floor()
		hv = hv.move_toward(dir * (SPRINT if sprint else WALK), (45.0 if on_floor else 7.0) * delta)
		velocity.y -= _gravity * delta
		if on_floor and Input.is_action_pressed("v_up"):
			velocity.y = JUMP
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length(), dir)


func _animate(delta: float, hs: float, dir: Vector3) -> void:
	var k := clampf(delta * 14.0, 0.0, 1.0)
	if first_person:
		_vis.rotation.y = yaw
	elif dir.length() > 0.1:
		_vis.rotation.y = rotate_toward(_vis.rotation.y, atan2(-dir.x, -dir.z), delta * 10.0)
	var leg_t := [0.0, 0.0]
	var shin_t := [0.0, 0.0]
	var arm_t := [0.0, 0.0]
	var bob := 0.0
	if swimming:
		# breaststroke arms, flutter kick
		for i in 2:
			arm_t[i] = -2.4 + sin(_t * 3.5) * 0.7
			leg_t[i] = sin(_t * 7.0 + PI * i) * 0.35
			shin_t[i] = -0.3
	elif not is_on_floor():
		leg_t = [0.45, -0.2]
		shin_t = [-0.7, -0.3]
		arm_t = [-0.5, -0.5]
	else:
		var amp := clampf(hs / SPRINT, 0.0, 1.0) * 0.95
		_phase += delta * hs * 2.1
		for i in 2:
			var ph := _phase + PI * i
			leg_t[i] = sin(ph) * amp
			# bend the knee while the leg swings forward so the foot lifts clear
			shin_t[i] = -maxf(0.0, cos(ph)) * amp * 1.5
			arm_t[i] = -sin(ph) * amp * 0.8
		bob = absf(sin(_phase)) * 0.05 * amp
	for i in 2:
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, leg_t[i], k)
		_shins[i].rotation.x = lerpf(_shins[i].rotation.x, shin_t[i], k)
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, arm_t[i], k)
	_torso.position.y = lerpf(_torso.position.y, 0.92 + bob, k)
