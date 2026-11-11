extends Node3D
## Test world: desert dunes with a stunt park, a runway, mesas with enemy
## turrets, a coastline and open sea with islands. Built procedurally.

const Target := preload("res://scripts/target.gd")
const Ring := preload("res://scripts/ring.gd")
const Prop := preload("res://scripts/prop.gd")

const N := 257
const S := 6.0
const HALF := (N - 1) * S * 0.5
const RUNWAY_X := -440.0
const RUNWAY_H := 10.0
const PAD := Vector2(-120, 40)
const PAD_H := 9.0
const MESAS := [Vector3(-260, -260, 46), Vector3(40, -380, 40), Vector3(-560, 120, 50), Vector3(60, 330, 34)]
const ISLANDS := [Vector3(560, -260, 90), Vector3(600, 300, 70), Vector3(420, 470, 55)]
const ISLAND_H := [14.0, 24.0, 9.0]

var enemies := true
var player: Node = null
var ring_index := 0
var ring_lap_start := 0.0
var last_lap := 0.0
var rings: Array = []
var _noise := FastNoiseLite.new()
var _ripple := FastNoiseLite.new()
var _heights := PackedFloat32Array()
var _time := 0.0


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 4
	_ripple.seed = 11
	_ripple.frequency = 0.04
	_build_terrain()
	_build_water()
	_build_runway()
	_build_pad()
	_build_stunt_park()
	_build_loop(Vector3(-40, 0, -150), 13.0)
	_build_props()
	_build_targets()
	_build_rings()
	_build_decor()
	_build_dock()


func _process(delta: float) -> void:
	_time += delta


# ---------------------------------------------------------------- terrain

func _flatten(h: float, target: float, d: float, inner: float, outer: float) -> float:
	if d >= outer:
		return h
	var t := 1.0 - smoothstep(inner, outer, d)
	return lerpf(h, target, t)


func _raw(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := 5.0 + n * n * 30.0 + _ripple.get_noise_2d(x, z) * 0.8
	for m: Vector3 in MESAS:
		var d := Vector2(x - m.x, z - m.y).length()
		h = maxf(h, lerpf(h, m.z, 1.0 - smoothstep(m.z * 0.9, m.z * 0.9 + 18.0, d)))
	# runway strip
	var rd := maxf(absf(x - RUNWAY_X) - 30.0, absf(z) - 360.0)
	h = _flatten(h, RUNWAY_H, maxf(rd, 0.0), 0.0, 45.0)
	h = _flatten(h, PAD_H, Vector2(x - PAD.x, z - PAD.y).length(), 55.0, 110.0)
	# mountains on the land edges
	var edge := maxf(absf(x), absf(z))
	if edge > 600.0:
		h += pow(edge - 600.0, 1.25) * 0.22
	h = maxf(h, 2.5)
	# coast
	var coast := smoothstep(150.0, 330.0, x + _noise.get_noise_2d(z * 0.6, 500.0) * 70.0)
	h = lerpf(h, -26.0, coast)
	for i in ISLANDS.size():
		var isl: Vector3 = ISLANDS[i]
		var d := Vector2(x - isl.x, z - isl.y).length()
		var top: float = ISLAND_H[i] + _ripple.get_noise_2d(x * 0.5, z * 0.5) * 2.0
		h = maxf(h, lerpf(-26.0, top, 1.0 - smoothstep(isl.z * 0.25, isl.z, d)))
	return h


## Height of the collision terrain (bilinear over the grid).
func height_at(x: float, z: float) -> float:
	var fx := (x + HALF) / S
	var fz := (z + HALF) / S
	if fx < 0.0 or fz < 0.0 or fx >= N - 1 or fz >= N - 1:
		return -60.0
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := _heights[iz * N + ix]
	var b := _heights[iz * N + ix + 1]
	var c := _heights[(iz + 1) * N + ix]
	var d := _heights[(iz + 1) * N + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _build_terrain() -> void:
	_heights.resize(N * N)
	for j in N:
		for i in N:
			_heights[j * N + i] = _raw(i * S - HALF, j * S - HALF)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(N * N)
	norms.resize(N * N)
	cols.resize(N * N)
	var sand := Color("#e3b778")
	var sand2 := Color("#d39a5a")
	var wet := Color("#a8875a")
	var rock := Color("#a46a45")
	var sea := Color("#5f7f7a")
	var grass := Color("#8fae5a")
	for j in N:
		for i in N:
			var k := j * N + i
			var h := _heights[k]
			var x := i * S - HALF
			var z := j * S - HALF
			var hl := _heights[k - 1] if i > 0 else h
			var hr := _heights[k + 1] if i < N - 1 else h
			var hd := _heights[k - N] if j > 0 else h
			var hu := _heights[k + N] if j < N - 1 else h
			var n := Vector3(hl - hr, 2.0 * S, hd - hu).normalized()
			verts[k] = Vector3(x, h, z)
			norms[k] = n
			var t := _ripple.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5
			var c := sand.lerp(sand2, t)
			var slope := 1.0 - n.y
			c = c.lerp(rock, clampf((slope - 0.12) * 4.0, 0.0, 1.0))
			if h < 2.0:
				c = c.lerp(wet, clampf((2.0 - h) / 3.0, 0.0, 1.0))
			if h < -1.0:
				c = c.lerp(sea, clampf((-1.0 - h) / 10.0, 0.0, 1.0))
			if x > 300.0 and h > 4.0:
				c = c.lerp(grass, clampf((h - 4.0) / 6.0, 0.0, 0.8))
			cols[k] = c
	var idx := PackedInt32Array()
	idx.resize((N - 1) * (N - 1) * 6)
	var w := 0
	# Winding chosen so the face normal points up (Godot front faces are clockwise).
	var a0 := Vector3(0, 0, 0)
	var b0 := Vector3(S, 0, 0)
	var c0 := Vector3(0, 0, S)
	var flip := (b0 - a0).cross(c0 - a0).dot(Vector3.UP) > 0.0
	for j in N - 1:
		for i in N - 1:
			var k := j * N + i
			var t1 := [k, k + 1, k + N]
			var t2 := [k + 1, k + N + 1, k + N]
			if flip:
				t1 = [k, k + N, k + 1]
				t2 = [k + 1, k + N, k + N + 1]
			for v in t1:
				idx[w] = v
				w += 1
			for v in t2:
				idx[w] = v
				w += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = Fx.L_WORLD
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	body.physics_material_override = pm
	add_child(body)
	var hs := HeightMapShape3D.new()
	hs.map_width = N
	hs.map_depth = N
	var data := PackedFloat32Array()
	data.resize(N * N)
	for k in N * N:
		data[k] = _heights[k] / S
	hs.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3(S, S, S)
	body.add_child(cs)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(16000, 16000)
	pm.subdivide_width = 260
	pm.subdivide_depth = 260
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;
uniform vec4 deep : source_color = vec4(0.02, 0.2, 0.33, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.62, 0.62, 1.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
varying vec3 wp;
float wave(vec2 p, float t) {
	return sin(p.x * 0.06 + t * 1.1) * 0.25 + cos(p.y * 0.05 + t * 0.9) * 0.25
		+ sin((p.x + p.y) * 0.13 + t * 1.7) * 0.08;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(wp.xz, TIME);
}
void fragment() {
	float e = 0.5;
	float h0 = wave(wp.xz, TIME);
	float hx = wave(wp.xz + vec2(e, 0.0), TIME);
	float hz = wave(wp.xz + vec2(0.0, e), TIME);
	vec2 q = wp.xz;
	vec2 rip = vec2(
		sin(q.x * 0.71 + q.y * 0.23 + TIME * 2.3) + sin(q.x * 1.37 - q.y * 0.91 - TIME * 1.7) * 0.6 + sin(q.y * 2.9 + q.x * 0.4 + TIME * 3.1) * 0.3,
		cos(q.y * 0.83 - q.x * 0.31 + TIME * 2.1) + sin(q.y * 1.53 + q.x * 1.1 + TIME * 1.5) * 0.6 + cos(q.x * 3.3 - q.y * 0.5 - TIME * 2.7) * 0.3) * 0.012;
	vec3 n = normalize(vec3(h0 - hx + rip.x, e, h0 - hz + rip.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pix = upos.xyz / upos.w;
	float wd = clamp(VERTEX.z - pix.z, 0.0, 60.0);
	float sh = exp(-wd * 0.18);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep.rgb, shallow.rgb, sh);
	float foam = smoothstep(1.2, 0.0, wd) * (0.6 + 0.4 * sin(TIME * 2.0 + wp.x * 0.7));
	ALBEDO = mix(col, vec3(0.95), foam * 0.8);
	ALPHA = clamp(mix(0.72, 0.97, 1.0 - sh) + fres * 0.2 + foam, 0.0, 1.0);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, Fx.WATER, 0)
	add_child(mi)


# ---------------------------------------------------------------- static helpers

func _static_box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, shader := true) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Fx.L_WORLD
	b.collision_mask = 0
	add_child(b)
	b.position = pos
	b.rotation = rot
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var m := Blocks.mat(col, 0.1, 0.8) if not shader else Blocks.mat(col, 0.15, 0.6)
	Blocks._mi(b, Blocks.box_mesh(size), Vector3.ZERO, m)
	return b


## Ramp rising toward -Z. `pos` is the low front edge center on the ground.
func _ramp(pos: Vector3, w: float, h: float, l: float, yaw: float, col: Color) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Fx.L_WORLD
	add_child(b)
	b.position = pos
	b.rotation.y = yaw
	var pts := PackedVector3Array([
		Vector3(-w / 2, -1.5, 0), Vector3(w / 2, -1.5, 0), Vector3(-w / 2, 0, 0), Vector3(w / 2, 0, 0),
		Vector3(-w / 2, -1.5, -l), Vector3(w / 2, -1.5, -l), Vector3(-w / 2, h, -l), Vector3(w / 2, h, -l)])
	var cs := CollisionShape3D.new()
	var cp := ConvexPolygonShape3D.new()
	cp.points = pts
	cs.shape = cp
	b.add_child(cs)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0 := pts[2]; var p1 := pts[3]; var p2 := pts[6]; var p3 := pts[7]
	var sn := (p2 - p0).cross(p1 - p0).normalized()
	if sn.y < 0.0:
		sn = -sn
	Blocks.add_tri(st, p0, p1, p3, sn); Blocks.add_tri(st, p0, p3, p2, sn)
	var q0 := pts[4]; var q1 := pts[5]
	Blocks.add_tri(st, q0, q1, p3, Vector3.FORWARD); Blocks.add_tri(st, q0, p3, p2, Vector3.FORWARD)
	Blocks.add_tri(st, pts[0], p0, p2, Vector3.LEFT); Blocks.add_tri(st, pts[0], p2, q0, Vector3.LEFT)
	Blocks.add_tri(st, pts[1], p1, p3, Vector3.RIGHT); Blocks.add_tri(st, pts[1], p3, q1, Vector3.RIGHT)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Blocks.mat(col, 0.1, 0.7)
	b.add_child(mi)
	# hazard stripes on the lip
	Blocks._mi(b, Blocks.box_mesh(Vector3(w, 0.12, 0.6)), Vector3(0, h + 0.02, -l + 0.3), Blocks.mat(Color("#ffcc00"), 0.1, 0.6))


func _ground(x: float, z: float) -> float:
	return height_at(x, z)


# ---------------------------------------------------------------- areas

func _build_runway() -> void:
	var y := RUNWAY_H + 0.05
	var b := _static_box(Vector3(RUNWAY_X, y - 0.5, 0), Vector3(40, 1.0, 700), Color("#3a3d42"), Vector3.ZERO, false)
	b.name = "Runway"
	for z in range(-330, 340, 30):
		Blocks._mi(b, Blocks.box_mesh(Vector3(1.0, 0.04, 14)), Vector3(0, 0.51, z), Blocks.mat(Color.WHITE, 0, 0.6))
	for x in [-18.5, 18.5]:
		Blocks._mi(b, Blocks.box_mesh(Vector3(0.6, 0.04, 700)), Vector3(x, 0.51, 0), Blocks.mat(Color("#f5c518"), 0, 0.6))
	for z in [-345.0, 345.0]:
		for i in 8:
			Blocks._mi(b, Blocks.box_mesh(Vector3(2.0, 0.04, 8)), Vector3(-14 + i * 4, 0.51, z - signf(z) * 8.0), Blocks.mat(Color.WHITE, 0, 0.6))
	# hangar + tower
	var hx := RUNWAY_X - 60.0
	_static_box(Vector3(hx, RUNWAY_H + 6, 120), Vector3(30, 12, 40), Color("#8d99a6"))
	_static_box(Vector3(hx, RUNWAY_H + 12.5, 120), Vector3(32, 1, 42), Color("#5c6773"))
	_static_box(Vector3(hx + 15.2, RUNWAY_H + 5, 120), Vector3(0.6, 10, 30), Color("#2b2f36"))
	_static_box(Vector3(hx, RUNWAY_H + 10, -60), Vector3(6, 20, 6), Color("#d9dee5"))
	var top := _static_box(Vector3(hx, RUNWAY_H + 21.5, -60), Vector3(9, 3, 9), Color("#7fb8e6"))
	Blocks._mi(top, Blocks.box_mesh(Vector3(9.2, 0.5, 9.2)), Vector3(0, 1.7, 0), Blocks.mat(Color("#e53935"), 0.1, 0.6))
	# windsock
	var pole := Vector3(RUNWAY_X + 26, RUNWAY_H, -300)
	_static_box(pole + Vector3(0, 4, 0), Vector3(0.3, 8, 0.3), Color("#d9dee5"))
	var sock := Node3D.new()
	add_child(sock)
	sock.position = pole + Vector3(0, 7.6, 0)
	Blocks._mi(sock, Blocks.cyl_mesh(0.25, 0.45, 2.4, 10), Vector3(1.2, 0, 0), Blocks.mat(Color("#ff6d00"), 0, 0.7), Vector3(0, 0, PI * 0.5))


func _build_pad() -> void:
	var c := Vector3(PAD.x, PAD_H, PAD.y)
	var b := _static_box(c - Vector3(0, 0.45, 0), Vector3(36, 1.0, 36), Color("#b9ad98"), Vector3.ZERO, false)
	for i in 6:
		Blocks._mi(b, Blocks.box_mesh(Vector3(36, 0.04, 0.5)), Vector3(0, 0.51, -15 + i * 6), Blocks.mat(Color("#968a76"), 0, 0.8))
	Blocks._mi(b, Blocks.cyl_mesh(6, 6, 0.06, 32), Vector3(0, 0.52, 0), Blocks.mat(Color("#f5c518"), 0, 0.7))
	Blocks._mi(b, Blocks.cyl_mesh(5.2, 5.2, 0.08, 32), Vector3(0, 0.52, 0), Blocks.mat(Color("#b9ad98"), 0, 0.8))
	# flag poles
	for x in [-17.0, 17.0]:
		_static_box(c + Vector3(x, 5, -17), Vector3(0.3, 10, 0.3), Color("#d9dee5"))
		Blocks._mi(self, Blocks.box_mesh(Vector3(0.05, 1.6, 2.6)), c + Vector3(x, 9.0, -15.6), Blocks.mat(Color("#ff4f5e") if x < 0 else Color("#3fa9ff"), 0, 0.7))


func _build_stunt_park() -> void:
	var cols := [Color("#ff7a2f"), Color("#3fa9ff"), Color("#3ddc84"), Color("#b98cff"), Color("#ffcc00")]
	# a line of growing ramps heading north from the pad
	for i in 4:
		var z := PAD.y - 60.0 - i * 70.0
		var x := PAD.x - 10.0 + i * 8.0
		var h := 2.0 + i * 1.6
		_ramp(Vector3(x, _ground(x, z), z), 10, h, 12 + i * 3, 0.0, cols[i % cols.size()])
	# gap jump with a landing ramp
	var gx := PAD.x + 70.0
	var gz := PAD.y - 40.0
	_ramp(Vector3(gx, _ground(gx, gz), gz), 12, 7, 18, 0.0, cols[3])
	_ramp(Vector3(gx, _ground(gx, gz - 65), gz - 70.0), 12, 6, 20, PI, cols[4])
	# mega ramp
	var mx := PAD.x - 80.0
	var mz := PAD.y - 120.0
	_ramp(Vector3(mx, _ground(mx, mz), mz), 16, 16, 45, 0.0, Color("#e53935"))
	# side kickers
	for i in 6:
		var a := i * TAU / 6.0
		var p := Vector2(PAD.x, PAD.y) + Vector2(cos(a), sin(a)) * 75.0
		_ramp(Vector3(p.x, _ground(p.x, p.y), p.y), 7, 2.2, 7, -a - PI * 0.5, cols[i % cols.size()])


func _build_loop(base: Vector3, r: float) -> void:
	var c := Vector3(PAD.x + base.x, _ground(PAD.x + base.x, PAD.y + base.z) + r + 0.2, PAD.y + base.z)
	var segs := 36
	var drift := 11.0
	var seg_len := TAU * r / segs + 0.25
	for s in segs + 1:
		var th := float(s) / segs * TAU
		var p := c + Vector3(th / TAU * drift, -r * cos(th), -r * sin(th))
		var t := Vector3(drift / TAU, r * sin(th), -r * cos(th)).normalized()
		var n := Vector3(0, cos(th), sin(th))
		n = (n - t * n.dot(t)).normalized()
		var x := n.cross(-t)
		var b := StaticBody3D.new()
		b.collision_layer = Fx.L_WORLD
		add_child(b)
		b.global_transform = Transform3D(Basis(x, n, -t), p - n * 0.3)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(8, 0.6, seg_len)
		cs.shape = bs
		b.add_child(cs)
		var col := Color("#ff4f5e") if s % 2 == 0 else Color("#f2f2f2")
		Blocks._mi(b, Blocks.box_mesh(Vector3(8, 0.6, seg_len)), Vector3.ZERO, Blocks.mat(col, 0.2, 0.5))
	# entry and exit ramps flush with the ground
	_ramp(Vector3(c.x, _ground(c.x, c.z + 6.0), c.z + 6.0), 8, 0.3, 5, 0.0, Color("#f2f2f2"))
	var ex := c.x + drift
	_ramp(Vector3(ex, _ground(ex, c.z - 6.0), c.z - 6.0), 8, 0.3, 5, PI, Color("#f2f2f2"))


func _build_props() -> void:
	# crate pyramids
	for base in [Vector2(PAD.x + 40, PAD.y + 60), Vector2(-300, 60), Vector2(RUNWAY_X + 50, -200)]:
		var gy := _ground(base.x, base.y)
		var n := 0
		for layer in 4:
			for i in 4 - layer:
				for j in 2:
					var cr := Prop.new()
					add_child(cr)
					cr.setup("crate", 1.4, Color("#c58b4c"))
					cr.global_position = Vector3(base.x + (i - (3 - layer) * 0.5) * 1.45, gy + 0.72 + layer * 1.42, base.y + j * 1.45)
					n += 1
	# explosive barrels
	for i in 14:
		var a := randf() * TAU
		var p := Vector2(PAD.x, PAD.y) + Vector2(cos(a), sin(a)) * randf_range(50, 160)
		var br := Prop.new()
		add_child(br)
		br.setup("barrel", 1.0, Color("#d32f2f"))
		br.global_position = Vector3(p.x, _ground(p.x, p.y) + 0.65, p.y)
	# barrel cluster on the beach
	for i in 8:
		var br := Prop.new()
		add_child(br)
		br.setup("barrel", 1.0, Color("#d32f2f"))
		var x := 190.0 + (i % 4) * 1.1
		var z := 120.0 + int(i / 4) * 1.1
		br.global_position = Vector3(x, _ground(x, z) + 0.7, z)


func _target(kind: String, pos: Vector3, r := 0.0, spd := 0.0) -> void:
	var t := Target.new()
	add_child(t)
	t.setup(kind, pos, self, r, spd)


func _build_targets() -> void:
	# practice dummies around the desert
	var spots := [Vector2(-60, -60), Vector2(-150, -90), Vector2(-20, 90), Vector2(-200, 110), Vector2(30, -10),
		Vector2(-120, -200), Vector2(80, -150), Vector2(-260, -40), Vector2(10, 200), Vector2(-330, 200)]
	for s in spots:
		_target("dummy", Vector3(s.x, _ground(s.x, s.y) - 0.2, s.y))
	# drones above the runway and desert
	_target("drone", Vector3(RUNWAY_X + 80, 90, -100), 120.0, 24.0)
	_target("drone", Vector3(RUNWAY_X + 120, 130, 150), 160.0, 30.0)
	_target("drone", Vector3(-150, 70, -150), 90.0, 18.0)
	_target("drone", Vector3(-200, 160, 50), 200.0, 34.0)
	_target("drone", Vector3(300, 60, 0), 110.0, 22.0)
	# boats circling the islands
	for i in ISLANDS.size():
		var isl: Vector3 = ISLANDS[i]
		_target("boat", Vector3(isl.x, 0, isl.y), isl.z + 40.0, 9.0 + i * 2.0)
	_target("boat", Vector3(380, 0, -40), 50.0, 7.0)
	# enemy turrets on the mesas
	for m: Vector3 in MESAS:
		_target("turret", Vector3(m.x, _ground(m.x, m.y), m.y))


func _build_rings() -> void:
	var pts := []
	var n := 12
	for i in n:
		var a := float(i) / n * TAU
		var p := Vector3(-150 + cos(a) * 330.0, 70.0 + sin(a * 2.0) * 35.0 + (i % 3) * 12.0, sin(a) * 300.0)
		pts.append(p)
	for i in n:
		var rg := Ring.new()
		add_child(rg)
		rg.setup(i)
		var p: Vector3 = pts[i]
		var nx: Vector3 = pts[(i + 1) % n]
		var pv: Vector3 = pts[(i - 1 + n) % n]
		rg.global_transform = Transform3D(Basis.looking_at((nx - pv).normalized(), Vector3.UP), p)
		rg.passed.connect(_on_ring)
		rings.append(rg)
	_activate_ring(0)


func _activate_ring(i: int) -> void:
	ring_index = i
	for r in rings:
		r.set_active(r.idx == i)


func _on_ring(i: int) -> void:
	if i != ring_index:
		return
	Sfx.play("ring", null, -2.0, 1.0 + i * 0.03)
	if i == 0:
		ring_lap_start = _time
	if i == rings.size() - 1:
		last_lap = _time - ring_lap_start
		Fx.event.emit("lap", "Ring course complete! %.1f s" % last_lap)
		_activate_ring(0)
	else:
		Fx.event.emit("ring", "Ring %d / %d" % [i + 1, rings.size()])
		_activate_ring(i + 1)


func active_ring_pos() -> Vector3:
	if rings.is_empty():
		return Vector3.INF
	return rings[ring_index].global_position


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var rock_m := Blocks.mat(Color("#9c6644"), 0.0, 0.95)
	var cactus_m := Blocks.mat(Color("#4f8a3a"), 0.0, 0.8)
	var palm_m := Blocks.mat(Color("#7a5230"), 0.0, 0.9)
	var leaf_m := Blocks.mat(Color("#3f9b45"), 0.0, 0.8)
	for i in 70:
		var x := rng.randf_range(-650, 140)
		var z := rng.randf_range(-650, 650)
		if absf(x - RUNWAY_X) < 60 and absf(z) < 400:
			continue
		if Vector2(x - PAD.x, z - PAD.y).length() < 120:
			continue
		var h := _ground(x, z)
		var sz := rng.randf_range(1.2, 4.5)
		var b := StaticBody3D.new()
		b.collision_layer = Fx.L_WORLD
		add_child(b)
		b.position = Vector3(x, h + sz * 0.2, z)
		var cs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = sz * 0.75
		cs.shape = ss
		b.add_child(cs)
		var mi := Blocks._mi(b, Blocks.sphere_mesh(1.0), Vector3.ZERO, rock_m, Vector3(rng.randf(), rng.randf() * TAU, rng.randf()))
		mi.scale = Vector3(sz * rng.randf_range(0.9, 1.4), sz * rng.randf_range(0.6, 0.9), sz * rng.randf_range(0.9, 1.3))
	for i in 90:
		var x := rng.randf_range(-650, 140)
		var z := rng.randf_range(-650, 650)
		if absf(x - RUNWAY_X) < 50 and absf(z) < 380:
			continue
		var h := _ground(x, z)
		if h < 3.0:
			continue
		var c := Node3D.new()
		add_child(c)
		c.position = Vector3(x, h, z)
		c.rotation.y = rng.randf() * TAU
		var tall := rng.randf_range(2.5, 5.0)
		Blocks._mi(c, Blocks.capsule_mesh(0.35, tall), Vector3(0, tall * 0.5, 0), cactus_m)
		for side in [-1, 1]:
			if rng.randf() < 0.7:
				var ah := rng.randf_range(0.8, tall * 0.6)
				Blocks._mi(c, Blocks.capsule_mesh(0.22, 1.0), Vector3(side * 0.55, ah, 0), cactus_m, Vector3(0, 0, PI * 0.5))
				Blocks._mi(c, Blocks.capsule_mesh(0.22, 1.4), Vector3(side * 0.9, ah + 0.55, 0), cactus_m)
	# palms on the islands
	for i in ISLANDS.size():
		var isl: Vector3 = ISLANDS[i]
		for k in 7:
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, isl.z * 0.4)
			var x := isl.x + cos(a) * d
			var z := isl.y + sin(a) * d
			var h := _ground(x, z)
			if h < 1.5:
				continue
			var p := Node3D.new()
			add_child(p)
			p.position = Vector3(x, h, z)
			var tall := rng.randf_range(6, 10)
			Blocks._mi(p, Blocks.cyl_mesh(0.22, 0.35, tall, 8), Vector3(0, tall * 0.5, 0), palm_m, Vector3(0, 0, rng.randf_range(-0.12, 0.12)))
			for l in 6:
				var la := l * TAU / 6.0
				var leaf := Blocks._mi(p, Blocks.box_mesh(Vector3(0.9, 0.08, 4.0)), Vector3(cos(la) * 1.6, tall - 0.3, sin(la) * 1.6), leaf_m)
				leaf.rotation = Vector3(0.35, -la + PI * 0.5, 0)
	# buoys
	for i in 16:
		var a := float(i) / 16.0 * TAU
		var p := Vector3(330 + cos(a) * 150.0, 0.0, sin(a) * 260.0)
		if _ground(p.x, p.z) > -2.0:
			continue
		var bnode := Node3D.new()
		add_child(bnode)
		bnode.position = p
		Blocks._mi(bnode, Blocks.cyl_mesh(0.3, 0.6, 1.6, 10), Vector3(0, 0.5, 0), Blocks.mat(Color("#ff4f5e") if i % 2 == 0 else Color("#f2f2f2"), 0.1, 0.6))
		Blocks._mi(bnode, Blocks.sphere_mesh(0.18), Vector3(0, 1.45, 0), Blocks.glow_mat(Color("#ffd23f"), 3.0))


func _build_dock() -> void:
	var z := 60.0
	var x0 := 170.0
	var x1 := 310.0
	var len := x1 - x0
	var b := _static_box(Vector3((x0 + x1) * 0.5, 1.6, z), Vector3(len, 0.5, 8), Color("#8a5a2b"), Vector3.ZERO, false)
	for i in int(len / 2.0):
		Blocks._mi(b, Blocks.box_mesh(Vector3(0.12, 0.02, 8.0)), Vector3(-len * 0.5 + i * 2.0, 0.26, 0), Blocks.mat(Color("#5d3b1a"), 0, 0.9))
	for i in int(len / 12.0) + 1:
		for s in [-3.6, 3.6]:
			var px := x0 + i * 12.0
			var gy := _ground(px, z + s)
			var hgt := 1.6 - gy + 0.5
			if hgt < 0.4:
				continue
			_static_box(Vector3(px, gy + hgt * 0.5 - 0.5, z + s), Vector3(0.6, hgt, 0.6), Color("#5d3b1a"), Vector3.ZERO, false)
	# launch ramp off the end of the pier
	_ramp(Vector3(x1 - 4.0, 1.85, z), 8, 3.0, 10, -PI * 0.5, Color("#ffcc00"))


# ---------------------------------------------------------------- spawns

const SPAWNS := {
	"desert": {"name": "Desert Stunt Park"},
	"sea": {"name": "Harbor & Open Sea"},
	"runway": {"name": "Airfield Runway"},
	"sky": {"name": "Sky Drop"},
}


## Returns {"pos": Vector3 ground point, "yaw": float, "vel": Vector3, "air": bool}.
func spawn_info(loc: String) -> Dictionary:
	match loc:
		"sea":
			return {"pos": Vector3(340, Fx.WATER + 0.3, 20), "yaw": -PI * 0.5, "vel": Vector3.ZERO, "air": false}
		"runway":
			return {"pos": Vector3(RUNWAY_X, RUNWAY_H + 0.05, 320), "yaw": 0.0, "vel": Vector3.ZERO, "air": false}
		"sky":
			return {"pos": Vector3(RUNWAY_X + 60, 230, 300), "yaw": 0.0, "vel": Vector3(0, 0, -45), "air": true}
	return {"pos": Vector3(PAD.x, PAD_H + 0.05, PAD.y), "yaw": 0.0, "vel": Vector3.ZERO, "air": false}
