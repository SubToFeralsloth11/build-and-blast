extends Node3D
## Game flow: garage <-> test drive, chase camera, scoring and the HUD.

const Builder := preload("res://scripts/builder.gd")
const BuilderUI := preload("res://scripts/builder_ui.gd")
const Hud := preload("res://scripts/hud.gd")
const World := preload("res://scripts/world.gd")
const Vehicle := preload("res://scripts/vehicle.gd")
const SimTest := preload("res://tools/sim_test.gd")

var env: Environment
var sun: DirectionalLight3D
var arena: Node3D
var world: Node3D
var builder: Node3D
var bui: Control
var hud: Control
var cam: Camera3D
var vehicle: RigidBody3D
var design := {}
var mode := "build"
var location := "desert"
var paused := false

var cam_yaw := 0.0
var cam_pitch := -0.25
var cam_dist := 12.0
var cam_follow := true
var _shake := 0.0
var _veh_size := 3.0
var _last_target := Vector3.ZERO
var _mouse_idle := 0.0

var score := 0
var targets := 0
var top_speed := 0.0
var max_alt := 0.0
var best_air := 0.0
var best_lap := 0.0
var _air_t := 0.0
var _agl := 0.0
var _lost_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_env()
	arena = Node3D.new()
	arena.name = "Arena"
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	Fx.root = arena
	world = World.new()
	world.name = "World"
	arena.add_child(world)
	Fx.world = world
	builder = Builder.new()
	builder.name = "Builder"
	builder.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(builder)
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 4000
	cam.near = 0.1
	arena.add_child(cam)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	bui = BuilderUI.new()
	canvas.add_child(bui)
	bui.setup(builder)
	bui.test_requested.connect(start_test)
	hud = Hud.new()
	canvas.add_child(hud)
	hud.setup()
	hud.resume.connect(func(): _set_paused(false))
	hud.respawn.connect(_on_menu_respawn)
	hud.relocate.connect(_on_menu_relocate)
	hud.garage.connect(_on_menu_garage)
	hud.enemies_toggled.connect(_on_enemies)
	Fx.event.connect(_on_event)
	Fx.shake.connect(_on_shake)
	builder.load_design(Designs.presets()[0], false)
	bui.toast("Welcome! Build from the orange seat, then hit a TEST button.")
	back_to_builder()
	var args := OS.get_cmdline_user_args()
	if "--simtest" in args or "--shots" in args:
		var t := SimTest.new()
		add_child(t)
		t.run(self, args)


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2f6fd0")
	sm.sky_horizon_color = Color("#b9d6f0")
	sm.ground_bottom_color = Color("#6b5a48")
	sm.ground_horizon_color = Color("#c9b79c")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("#c4d8ec")
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.2
	env.ssao_enabled = false
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	sun.light_energy = 1.05
	sun.light_color = Color("#fff4e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)


# ---------------------------------------------------------------- modes

func back_to_builder() -> void:
	mode = "build"
	if vehicle and is_instance_valid(vehicle):
		vehicle.queue_free()
	vehicle = null
	world.player = null
	arena.visible = false
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	builder.visible = true
	builder.active = true
	builder.process_mode = Node.PROCESS_MODE_PAUSABLE
	builder.cam.current = true
	bui.visible = true
	hud.visible = false
	Controls.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	env.fog_enabled = false


func start_test(loc: String) -> void:
	design = builder.to_design()
	var st := Designs.stats(design)
	if not st.has_seat:
		bui.toast("You need a pilot seat!")
		return
	location = loc
	mode = "test"
	builder.active = false
	builder.visible = false
	builder.process_mode = Node.PROCESS_MODE_DISABLED
	bui.visible = false
	arena.visible = true
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.visible = true
	cam.current = true
	env.fog_enabled = true
	_spawn_vehicle()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Controls.enabled = true
	hud.toast("%s - %s" % [design.name, World.SPAWNS[loc].name], Color("#ffd23f"))


func _spawn_vehicle() -> void:
	if vehicle and is_instance_valid(vehicle):
		vehicle.queue_free()
	var info: Dictionary = world.spawn_info(location)
	vehicle = Vehicle.new()
	vehicle.name = "PlayerVehicle"
	vehicle.transform = Transform3D(Basis(Vector3.UP, info.yaw), info.pos + Vector3(0, 5, 0))
	arena.add_child(vehicle)
	vehicle.build(design)
	var low: float = vehicle.lowest_point_local()
	var p: Vector3 = info.pos
	if not info.air:
		p.y += -low + 0.25
	vehicle.global_position = p
	vehicle.linear_velocity = Basis(Vector3.UP, info.yaw) * info.vel
	vehicle.wrecked.connect(_on_wrecked)
	world.player = vehicle
	Controls.reset_toggles()
	hud.set_wrecked(false)
	_air_t = 0.0
	_lost_t = 0.0
	_veh_size = 1.0
	for part in vehicle.parts:
		_veh_size = maxf(_veh_size, (part.pos - vehicle.com_local).length())
	cam_yaw = info.yaw
	cam_pitch = -0.22
	cam_dist = clampf(_veh_size * 2.4 + 6.0, 8.0, 40.0)
	_last_target = vehicle.com_world()
	cam.global_position = _last_target + Basis(Vector3.UP, cam_yaw) * Vector3(0, 3, cam_dist)


func _on_wrecked() -> void:
	hud.set_wrecked(true)
	hud.toast("Your vehicle was destroyed!", Color("#ff4f5e"))


func _on_menu_respawn() -> void:
	_set_paused(false)
	_spawn_vehicle()


func _on_menu_relocate(loc: String) -> void:
	location = loc
	_set_paused(false)
	_spawn_vehicle()


func _on_menu_garage() -> void:
	_set_paused(false)
	back_to_builder()


func _on_enemies(on: bool) -> void:
	world.enemies = on


func _set_paused(on: bool) -> void:
	paused = on
	get_tree().paused = on
	hud.set_paused(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	Controls.enabled = not on


func _flip() -> void:
	if vehicle == null or not vehicle.alive:
		return
	var fwd := -vehicle.global_basis.z
	fwd.y = 0.0
	var yaw := atan2(-fwd.x, -fwd.z) if fwd.length() > 0.1 else 0.0
	vehicle.global_transform = Transform3D(Basis(Vector3.UP, yaw), vehicle.global_position + Vector3.UP * 2.5)
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.linear_velocity = Vector3.ZERO
	hud.toast("Flipped!")


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if mode == "build":
		if e is InputEventKey and e.is_pressed() and not e.is_echo() and (e as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			start_test(location)
		return
	if e is InputEventKey and e.is_pressed() and not e.is_echo():
		match (e as InputEventKey).physical_keycode:
			KEY_ESCAPE:
				_set_paused(not paused)
			KEY_TAB:
				if paused:
					_set_paused(false)
				back_to_builder()
			KEY_R:
				if not paused:
					_spawn_vehicle()
			KEY_F:
				if not paused:
					_flip()
			KEY_V:
				cam_follow = not cam_follow
				hud.toast("Camera: %s" % ("chase" if cam_follow else "free orbit"))
			KEY_F1:
				hud.toggle_help()
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.0035
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.0035, -1.3, 0.9)
		_mouse_idle = 0.0
	elif e is InputEventMouseButton and e.is_pressed():
		var mb := e as InputEventMouseButton
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(4.0, cam_dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(80.0, cam_dist * 1.1)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if mode != "test" or paused:
		return
	_update_camera(delta)
	_update_stats(delta)


func _update_camera(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	var target := _last_target
	if vehicle.alive:
		target = vehicle.com_world()
		_last_target = target
	_mouse_idle += delta
	var speed := vehicle.linear_velocity.length() if vehicle.alive else 0.0
	if cam_follow and vehicle.alive and speed > 4.0 and _mouse_idle > 1.2:
		var v := vehicle.linear_velocity
		var heading := atan2(-v.x, -v.z)
		cam_yaw = rotate_toward(cam_yaw, heading, delta * 1.6 * clampf((speed - 4.0) / 10.0, 0.0, 1.0))
	var look := target + Vector3(0, _veh_size * 0.35 + 0.8, 0)
	var off := Vector3(0, 0, cam_dist).rotated(Vector3.RIGHT, cam_pitch).rotated(Vector3.UP, cam_yaw)
	var want := look + off
	var gh := maxf(Fx.ground_height(want.x, want.z), Fx.WATER - 0.2)
	want.y = maxf(want.y, gh + 1.2)
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 14.0, 0.0, 1.0))
	if cam.global_position.distance_to(look) > 0.1:
		cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(cam.fov, 70.0 + clampf(speed / 4.0, 0.0, 18.0), delta * 3.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.4
		cam.v_offset = randf_range(-1, 1) * _shake * 0.4
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	# aim point under the crosshair
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var excl: Array[RID] = [vehicle.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1500.0, Fx.MASK_SHOT, excl)
	var h := cam.get_world_3d().direct_space_state.intersect_ray(q)
	vehicle.aim_point = h.position if not h.is_empty() else from + dir * 900.0


func _update_stats(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	var com: Vector3 = vehicle.com_world() if vehicle.alive else _last_target
	var speed: float = vehicle.linear_velocity.length() if vehicle.alive else 0.0
	var gh: float = Fx.ground_height(com.x, com.z)
	var surface := maxf(gh, Fx.WATER)
	var bottom: float = vehicle.com_local.y - vehicle.lowest_point_local()
	_agl = com.y - surface - bottom
	if vehicle.alive:
		top_speed = maxf(top_speed, speed)
		max_alt = maxf(max_alt, com.y)
		if _agl > 1.4:
			_air_t += delta
		else:
			if _air_t > 1.2:
				var pts := int(_air_t * 40.0)
				score += pts
				hud.toast("AIR TIME %.1f s  +%d" % [_air_t, pts], Color("#3fd6ff"))
				if _air_t > best_air:
					best_air = _air_t
			_air_t = 0.0
		if com.y < -45.0:
			_lost_t += delta
			if _lost_t > 1.0:
				hud.toast("Lost to the deep. Respawning...", Color("#3fa9ff"))
				_spawn_vehicle()
				return
	var rp: Vector3 = world.active_ring_pos()
	var rd := -1.0
	if rp != Vector3.INF and (location == "runway" or location == "sky" or com.y > 40.0):
		rd = com.distance_to(rp)
	hud.update({
		"name": design.get("name", ""), "speed": speed, "alt": com.y, "agl": maxf(_agl, 0.0),
		"intact": vehicle.intact(), "score": score, "targets": targets, "top_speed": top_speed,
		"max_alt": max_alt, "best_air": best_air, "best_lap": best_lap, "ring_dist": rd, "ring_idx": world.ring_index,
	})


func _on_event(kind: String, text: String) -> void:
	if mode != "test":
		return
	match kind:
		"target":
			targets += 1
			score += 100
			hud.toast("%s  +100" % text, Color("#ff7a2f"))
			hud.hit_marker()
			Sfx.play("score", null, -6.0)
		"barrel":
			score += 25
			hud.toast("%s  +25" % text, Color("#ffcc00"))
		"ring":
			score += 50
			hud.toast("%s  +50" % text, Color("#ffd23f"))
		"lap":
			score += 500
			if best_lap <= 0.0 or world.last_lap < best_lap:
				best_lap = world.last_lap
			hud.toast("%s  +500" % text, Color("#3ddc84"))
			Sfx.play("score", null, 0.0)


func _on_shake(pos: Vector3, strength: float) -> void:
	if mode != "test":
		return
	var d := cam.global_position.distance_to(pos)
	_shake = minf(2.0, _shake + strength * clampf(1.0 - d / 140.0, 0.0, 1.0))
