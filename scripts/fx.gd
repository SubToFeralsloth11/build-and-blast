extends Node
## Shared combat helpers: explosions, hitscan, tracers, particles, projectiles.

signal shake(pos: Vector3, strength: float)
signal event(kind: String, text: String)

const L_WORLD := 1
const L_VEHICLE := 2
const L_PROPS := 4
const L_TARGET := 8
const L_BUILD := 512
const MASK_SHOT := L_WORLD | L_VEHICLE | L_PROPS | L_TARGET
const WATER := 0.0

const Projectile := preload("res://scripts/projectile.gd")

var root: Node3D          # 3D node effects get parented to
var world: Node           # provides height_at(x, z)
var _pm_cache := {}
var _draw_cache := {}
## One-shot particle bursts currently alive. Every burst is its own GPU particle
## system, so this is capped: hundreds of them at once stall the GPU (Metal
## "timeout waiting for fence") and crash the game.
var _live := 0
const MAX_BURSTS := 220


func space() -> PhysicsDirectSpaceState3D:
	return root.get_world_3d().direct_space_state


func ground_height(x: float, z: float) -> float:
	if world and world.has_method("height_at"):
		return world.height_at(x, z)
	return -100.0


func over_water(p: Vector3) -> bool:
	return ground_height(p.x, p.z) < WATER


# ---------------------------------------------------------------- damage

func explode(pos: Vector3, radius: float, damage: float, big := true) -> void:
	if root == null:
		return
	_explosion_visual(pos, radius, big)
	Sfx.play("explosion" if big else "cannon", pos, 4.0 if big else 0.0, 1.2 - clampf(radius / 30.0, 0.0, 0.5))
	shake.emit(pos, damage * 0.012 + radius * 0.05)
	for n in get_tree().get_nodes_in_group("damageable"):
		if is_instance_valid(n) and n.has_method("take_blast"):
			n.take_blast(pos, radius, damage)
	for b in get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(b) or not (b is RigidBody3D):
			continue
		var d: Vector3 = b.global_position - pos
		var reach := radius * 1.8
		if d.length() < reach:
			var k := 1.0 - d.length() / reach
			b.sleeping = false
			b.apply_central_impulse((d.normalized() + Vector3.UP * 0.4) * k * damage * 0.5 * minf(b.mass, 400.0) / 40.0)
			if b.has_method("take_blast"):
				pass  # already handled through "damageable"


## Instant bullet. Returns the hit dictionary (empty when nothing hit).
func hitscan(from: Vector3, dir: Vector3, rng: float, dmg: float, exclude: Array[RID], col := Color("#ffd27a")) -> Dictionary:
	var to := from + dir * rng
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHOT, exclude)
	var h := space().intersect_ray(q)
	var end := to
	if not h.is_empty():
		end = h.position
	# water splash if the bullet crosses the surface first
	if from.y > WATER and end.y < WATER and dir.y < -0.01:
		var t := (from.y - WATER) / -dir.y
		var wp := from + dir * t
		if over_water(wp):
			splash(wp, 0.5)
			tracer(from, wp, col)
			return {}
	if not h.is_empty():
		var c = h.collider
		if c.has_method("take_hit"):
			c.take_hit(dmg, h.position, h.shape, dir)
		elif c is RigidBody3D:
			c.apply_impulse(dir * dmg * 3.0, h.position - c.global_position)
		sparks(h.position, h.normal)
	tracer(from, end, col)
	return h


## Damages everything in a cone (flamethrower).
func cone_damage(from: Vector3, dir: Vector3, rng: float, dmg: float, exclude: Array[RID]) -> void:
	for i in 3:
		var d := (dir + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + d * rng, MASK_SHOT, exclude)
		var h := space().intersect_ray(q)
		if h.is_empty():
			continue
		var c = h.collider
		if c.has_method("take_hit"):
			c.take_hit(dmg / 3.0, h.position, h.shape, d)
		elif c is RigidBody3D:
			c.apply_impulse(d * dmg * 0.5, h.position - c.global_position)
		if randf() < 0.3:
			burst(h.position, Color(1, 0.5, 0.1), 4, 2.0, 0.4, 0.5, Vector3(0, 3, 0), 60.0, Vector3.UP, true)


## Pushes rigid bodies in a cone (water cannon). No damage.
func cone_push(from: Vector3, dir: Vector3, rng: float, impulse: float, exclude: Array[RID]) -> void:
	for i in 3:
		var d := (dir + Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + d * rng, MASK_SHOT, exclude)
		var h := space().intersect_ray(q)
		if h.is_empty():
			continue
		var c = h.collider
		var k := 1.0 - from.distance_to(h.position) / rng
		if c is RigidBody3D:
			(c as RigidBody3D).sleeping = false
			c.apply_impulse(d * impulse * k / 3.0, h.position - c.global_position)
		if randf() < 0.4:
			burst(h.position, Color(0.85, 0.95, 1.0, 0.9), 6, 5.0, 0.2, 0.6, Vector3(0, -12, 0), 60.0, h.normal, false)


func spawn_projectile(kind: String, pos: Vector3, vel: Vector3, exclude: Array[RID], target := Vector3.INF, power := 1.0) -> Node3D:
	var p := Projectile.new()
	p.kind = kind
	p.power = power
	p.vel = vel
	p.exclude = exclude
	p.target = target
	root.add_child(p)
	p.global_position = pos
	return p


# ---------------------------------------------------------------- visuals

func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func tracer(a: Vector3, b: Vector3, col: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.3:
		return
	var m := MeshInstance3D.new()
	m.mesh = Blocks.box_mesh(Vector3(0.07, 0.07, 1.0))
	var mt := _glow(col, 3.0)
	m.material_override = mt
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	var dir := (b - a) / len
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	m.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3(1, 1, len)), (a + b) * 0.5)
	var tw := m.create_tween()
	tw.tween_property(mt, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(m.queue_free)


func sparks(pos: Vector3, normal: Vector3) -> void:
	burst(pos, Color(1.0, 0.8, 0.4), 8, 7.0, 0.07, 0.35, Vector3(0, -12, 0), 50.0, normal, true)


func splash(pos: Vector3, size: float) -> void:
	burst(Vector3(pos.x, WATER + 0.1, pos.z), Color(0.85, 0.95, 1.0, 0.9), int(8 + size * 14), 4.0 + size * 5.0, 0.18 + size * 0.15, 1.1, Vector3(0, -14, 0), 22.0, Vector3.UP, false)
	if size > 0.8:
		Sfx.play("splash", pos, -4.0 + size * 2.0)


func debris_burst(pos: Vector3, col: Color) -> void:
	burst(pos, col, 10, 6.0, 0.16, 1.2, Vector3(0, -15, 0), 180.0, Vector3.UP, false, true)
	burst(pos, Color(0.25, 0.25, 0.25, 0.7), 6, 1.5, 0.5, 1.6, Vector3(0, 1.5, 0), 180.0, Vector3.UP, false)


func muzzle_flash(pos: Vector3, dir: Vector3, size := 1.0) -> void:
	burst(pos, Color(1.0, 0.75, 0.3), 5, 6.0 * size, 0.12 * size, 0.08, Vector3.ZERO, 18.0, dir, true)


func burst(pos: Vector3, col: Color, amount: int, speed: float, size: float, life: float, grav: Vector3, spread: float, dir: Vector3, additive: bool, cubes := false) -> void:
	if root == null or amount <= 0 or _live >= MAX_BURSTS:
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.process_material = _process_mat(speed, life, grav, spread, additive)
	p.draw_pass_1 = _draw_pass(col, size, additive, cubes)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	# The material always emits along +Y; the node's rotation aims it.
	p.global_transform = Transform3D(basis_up(dir), pos)
	p.emitting = true
	_live += 1
	get_tree().create_timer(life + 0.4).timeout.connect(_burst_done.bind(p))


func _burst_done(p: Node) -> void:
	_live -= 1
	p.queue_free()


## Continuous smoke trail that follows `parent` (rockets, missiles, torpedoes).
## One emitter per projectile instead of a new particle system every few frames.
func trail(parent: Node3D, col: Color, rate: float, size: float, life: float, additive := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(4, ceili(rate * life))
	p.lifetime = life
	p.local_coords = false
	p.process_material = _process_mat(0.6, life, Vector3(0, 0.6, 0), 30.0, additive)
	p.draw_pass_1 = _draw_pass(col, size, additive, false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p


## Leaves a trail behind in the world when its projectile is removed, so the
## smoke already emitted fades out instead of vanishing.
func drop_trail(p: GPUParticles3D) -> void:
	if p == null or not is_instance_valid(p) or root == null:
		return
	p.emitting = false
	p.reparent(root)
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


## Basis whose +Y axis points along `dir`. (Quaternion's shortest-arc
## constructor turns around Y for a straight-down target, which keeps +Y up.)
func basis_up(dir: Vector3) -> Basis:
	if dir.length_squared() < 0.0001:
		return Basis.IDENTITY
	var d := dir.normalized()
	if d.y < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, d))


func _process_mat(speed: float, life: float, grav: Vector3, spread: float, additive: bool) -> ParticleProcessMaterial:
	var key := "%.1f_%.2f_%s_%.0f_%s" % [speed, life, grav.snapped(Vector3.ONE * 0.5), spread, additive]
	if _pm_cache.has(key):
		return _pm_cache[key]
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = grav
	pm.damping_min = 0.5
	pm.damping_max = 2.0
	pm.angular_velocity_min = -300.0
	pm.angular_velocity_max = 300.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1.0))
	c.add_point(Vector2(1, 0.15 if additive else 1.6))
	curve.curve = c
	pm.scale_curve = curve
	var ramp := GradientTexture1D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	ramp.gradient = g
	pm.color_ramp = ramp
	_pm_cache[key] = pm
	return pm


func _draw_pass(col: Color, size: float, additive: bool, cubes: bool) -> Mesh:
	# snap the colour so random colours (fireworks, paint) reuse a bounded set
	col = Color(snappedf(col.r, 0.05), snappedf(col.g, 0.05), snappedf(col.b, 0.05), snappedf(col.a, 0.1))
	var dkey := "%s_%.2f_%s_%s" % [col.to_html(), size, additive, cubes]
	if _draw_cache.has(dkey):
		return _draw_cache[dkey]
	var mesh: PrimitiveMesh
	if cubes:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * size
		mesh = bm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = m
	else:
		var q := Blocks.puff_mesh(size * 1.4, additive).duplicate() as QuadMesh
		var m := (q.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = col
		q.material = m
		mesh = q
	_draw_cache[dkey] = mesh
	return mesh


func _explosion_visual(pos: Vector3, radius: float, big: bool) -> void:
	var r := clampf(radius, 1.0, 14.0)
	var ball := MeshInstance3D.new()
	ball.mesh = Blocks.sphere_mesh(1.0)
	var mt := _glow(Color(1.0, 0.6, 0.2), 4.0)
	ball.material_override = mt
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	ball.global_position = pos
	ball.scale = Vector3.ONE * r * 0.2
	var tw := ball.create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * r * 0.9, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mt, "albedo_color", Color(0.6, 0.15, 0.02, 0.0), 0.45)
	tw.chain().tween_callback(ball.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 8.0
	light.omni_range = r * 4.0
	root.add_child(light)
	light.global_position = pos + Vector3.UP
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.5)
	lt.tween_callback(light.queue_free)
	burst(pos, Color(1.0, 0.55, 0.15), int(12 + r * 3), r * 3.5, 0.35 + r * 0.06, 0.6, Vector3(0, 2, 0), 180.0, Vector3.UP, true)
	burst(pos, Color(0.2, 0.2, 0.2, 0.8), int(8 + r * 2), r * 1.2, 0.6 + r * 0.12, 2.6, Vector3(0, 2.5, 0), 180.0, Vector3.UP, false)
	if big:
		burst(pos, Color(0.35, 0.3, 0.25), int(8 + r), r * 3.0, 0.15, 1.6, Vector3(0, -18, 0), 70.0, Vector3.UP, false, true)
	if pos.y < WATER + 1.5 and over_water(pos):
		splash(pos, minf(r * 0.4, 3.0))
