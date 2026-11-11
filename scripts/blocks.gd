extends Node
## Block catalog: definitions, the 24 grid orientations, procedural visuals,
## collision shapes and palette icons.

const CATS := ["Structure", "Wheels", "Propulsion", "Flight", "Water", "Weapons", "Gadgets"]
const CAT_COLORS := {
	"Structure": Color("#9aa4b1"), "Wheels": Color("#e0b341"), "Propulsion": Color("#ff7a3d"),
	"Flight": Color("#5fb8ff"), "Water": Color("#3fd6c6"), "Weapons": Color("#ff4f5e"),
	"Gadgets": Color("#b98cff"),
}

var defs := {}
var order: Array[String] = []
var rots: Array[Basis] = []
var _mats := {}
var _meshes := {}
var _shapes := {}
var _icons := {}
var _block_shader: Shader


func _init() -> void:
	_build_rots()
	_define_all()
	_block_shader = Shader.new()
	_block_shader.code = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float rough = 0.55;
uniform float metal = 0.1;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 d = 0.5 - abs(lp);
	float mn = min(d.x, min(d.y, d.z));
	float mx = max(d.x, max(d.y, d.z));
	float mid = d.x + d.y + d.z - mn - mx;
	float edge = 1.0 - smoothstep(0.015, 0.05, mid);
	float inset = 1.0 - smoothstep(0.0, 0.012, abs(mid - 0.09));
	vec3 c = albedo.rgb * (1.0 - 0.38 * edge) * (1.0 - 0.12 * inset);
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
}
"""


# ---------------------------------------------------------------- orientations

func _build_rots() -> void:
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for a: Vector3 in axes:
		for b: Vector3 in axes:
			if absf(a.dot(b)) > 0.1:
				continue
			rots.append(Basis(a, b, a.cross(b)))


func rot_index(b: Basis) -> int:
	for i in rots.size():
		var r := rots[i]
		if r.x.distance_to(b.x) < 0.1 and r.y.distance_to(b.y) < 0.1 and r.z.distance_to(b.z) < 0.1:
			return i
	return 0


## Orientation whose local forward (-Z) is `fwd` and local up (+Y) is `up`.
func rot_toward(fwd: Vector3, up: Vector3) -> int:
	var z := -fwd
	return rot_index(Basis(up.cross(z), up, z))


func rotate_index(i: int, axis: Vector3, steps := 1) -> int:
	return rot_index(Basis(axis, PI * 0.5 * steps) * rots[i])


func mirror_index(i: int) -> int:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return rot_index(m * rots[i] * m)


# ---------------------------------------------------------------- catalog

func _d(id: String, nm: String, cat: String, mass: float, hp: float, col: String, desc: String, extra := {}) -> void:
	var d := {
		"id": id, "name": nm, "cat": cat, "mass": mass, "hp": hp, "color": Color(col),
		"desc": desc, "shape": "box", "buoy": 0.06, "cfg": {}, "auto_rot": false,
	}
	d.merge(extra, true)
	defs[id] = d
	order.append(id)


func _define_all() -> void:
	# Structure
	_d("seat", "Pilot Seat", "Structure", 80, 400, "#ff7a2f", "The core of every vehicle. Lose it and you are wrecked.", {"buoy": 0.18, "unique": true})
	_d("cube", "Block", "Structure", 25, 90, "#d9dee5", "Sturdy all-round building block.", {"buoy": 0.14})
	_d("wood", "Wood Block", "Structure", 10, 50, "#b67a44", "Light and floats great. Perfect for boats.", {"buoy": 0.4})
	_d("armor", "Armor Block", "Structure", 90, 320, "#59616c", "Heavy plate that soaks up bullets and blasts.", {"buoy": 0.05})
	_d("wedge", "Wedge", "Structure", 18, 70, "#d9dee5", "Sloped block for noses, ramps and style.", {"shape": "wedge", "buoy": 0.1})
	_d("plate", "Thin Plate", "Structure", 8, 40, "#cfd5dd", "Flat floor plate. Very light.", {"shape": "plate", "buoy": 0.05})
	# Wheels
	_d("wheel", "Wheel", "Wheels", 35, 120, "#e8b23a", "Sprung wheel. Front wheels steer automatically.", {"shape": "wheel", "auto_rot": true, "radius": 0.48, "travel": 0.4, "drive": 1150.0, "cfg": {"steer": "auto", "drive": true, "pow": 100}})
	_d("bigwheel", "Monster Wheel", "Wheels", 70, 220, "#e8b23a", "Huge off-road wheel with long suspension.", {"shape": "bigwheel", "auto_rot": true, "radius": 0.8, "travel": 0.55, "drive": 1700.0, "cfg": {"steer": "auto", "drive": true, "pow": 100}})
	# Propulsion
	_d("thruster", "Thruster", "Propulsion", 40, 80, "#c8ced8", "Small jet that pushes toward its pointy end. Works anywhere.", {"thrust": 1900.0, "medium": "any", "flame": 1.2, "cfg": {"ch": "throttle", "inv": false, "pow": 100}})
	_d("jet", "Jet Engine", "Propulsion", 100, 140, "#9aa3ad", "Powerful air-breathing engine. Dies underwater.", {"thrust": 6200.0, "medium": "air", "flame": 2.2, "cfg": {"ch": "throttle", "inv": false, "pow": 100}})
	_d("rocket", "Rocket Booster", "Propulsion", 70, 100, "#f2f2f2", "Insane burst of thrust on Shift. Hold on tight!", {"thrust": 14000.0, "medium": "any", "flame": 3.5, "cfg": {"ch": "boost", "inv": false, "pow": 100}})
	_d("prop", "Propeller", "Propulsion", 50, 90, "#f0c419", "Classic airplane propeller. Strong at low speed.", {"thrust": 4200.0, "medium": "air", "cfg": {"ch": "throttle", "inv": false, "pow": 100}})
	_d("rotor", "Heli Rotor", "Propulsion", 60, 110, "#7c8794", "Helicopter rotor with altitude hold. Space/C to climb or sink.", {"thrust": 5200.0, "cfg": {"ch": "lift", "inv": false, "pow": 100}})
	_d("balloon", "Balloon", "Propulsion", 12, 30, "#ff4f6d", "Floats up forever. Pops if shot.", {"lift": 1500.0, "cfg": {"ch": "always", "inv": false, "pow": 100}})
	# Flight
	_d("wing", "Wing", "Flight", 15, 70, "#e6ebf2", "Generates lift when moving forward. Leading edge faces forward.", {"shape": "wing", "buoy": 0.06})
	_d("flap", "Control Flap", "Flight", 15, 60, "#5fb8ff", "Moving surface. Auto-steers pitch, roll and yaw based on where you put it.", {"shape": "wing", "cfg": {"pow": 100}})
	_d("gyro", "Gyro Stabilizer", "Flight", 40, 80, "#5fd0ff", "Keeps you level and adds steering torque from arrows and A/D.", {"cfg": {"pow": 100}})
	_d("parachute", "Parachute", "Flight", 20, 50, "#ffffff", "Toggle with 2 for a soft landing or a drag-race stop.", {"cfg": {"ch": "act2", "inv": false, "pow": 100}})
	# Water
	_d("float", "Float", "Water", 10, 60, "#ff9a1f", "Huge buoyancy. Keeps anything above water.", {"buoy": 0.95})
	_d("boatprop", "Boat Propeller", "Water", 40, 90, "#d4a542", "Pushes through water. Only works submerged.", {"thrust": 4600.0, "medium": "water", "cfg": {"ch": "throttle", "inv": false, "pow": 100}})
	# Weapons
	_d("mg", "Machine Gun", "Weapons", 30, 70, "#3c434c", "Rapid fire bullets. Aims near your crosshair.", {"cfg": {"ch": "fire1", "inv": false, "pow": 100}})
	_d("cannon", "Cannon", "Weapons", 90, 150, "#4b5563", "Explosive shells with a big kick.", {"cfg": {"ch": "fire2", "inv": false, "pow": 100}})
	_d("rockets", "Rocket Pod", "Weapons", 60, 90, "#59616c", "Fires homing rockets toward your crosshair.", {"cfg": {"ch": "fire2", "inv": false, "pow": 100}})
	_d("laser", "Laser", "Weapons", 40, 70, "#eef2f7", "Continuous beam that melts blocks.", {"cfg": {"ch": "fire1", "inv": false, "pow": 100}})
	_d("flamer", "Flamethrower", "Weapons", 40, 70, "#d33c2c", "Short range torrent of fire.", {"cfg": {"ch": "fire1", "inv": false, "pow": 100}})
	_d("bombs", "Bomb Bay", "Weapons", 70, 110, "#4a5a3c", "Drops big bombs on G. Best from a plane.", {"cfg": {"ch": "fire3", "inv": false, "pow": 100}})
	_d("turret", "Auto Turret", "Weapons", 70, 140, "#5c6b4a", "Swivels to follow your crosshair and fires twin guns.", {"cfg": {"ch": "fire1", "inv": false, "pow": 100}})
	# Gadgets
	_d("jump", "Spring Jump", "Gadgets", 40, 90, "#3ddc84", "Launches you along its spring on Space.", {"cfg": {"ch": "lift", "inv": false, "pow": 100}})
	_d("magnet", "Magnet", "Gadgets", 60, 110, "#e53935", "Toggle with 1 to pull crates, barrels and debris.", {"cfg": {"ch": "act1", "inv": false, "pow": 100}})
	_d("tnt", "TNT", "Gadgets", 30, 30, "#d32f2f", "Detonate with 4. Also explodes when destroyed!", {"cfg": {"ch": "act4", "inv": false, "pow": 100}})
	_d("smoke", "Smoke Trail", "Gadgets", 10, 40, "#ff5ec4", "Leaves a colorful trail. Paint it to change the color.", {"cfg": {"ch": "always", "inv": false, "pow": 100}})
	_d("light", "Headlight", "Gadgets", 8, 30, "#2b2f36", "Bright spotlight. Toggle with 3.", {"cfg": {"ch": "act3", "inv": true, "pow": 100}})
	_d("horn", "Horn", "Gadgets", 8, 30, "#e0b341", "HONK. Press H.", {"cfg": {"ch": "horn", "inv": false, "pow": 100}})


func get_def(id: String) -> Dictionary:
	return defs.get(id, {})


func ids_in(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id in order:
		if defs[id].cat == cat:
			out.append(id)
	return out


# ---------------------------------------------------------------- materials & meshes

func mat(col: Color, metal := 0.15, rough := 0.6) -> Material:
	var key := "s%s_%.2f_%.2f" % [col.to_html(), metal, rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = metal
		m.roughness = rough
		if col.a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


func block_mat(col: Color, metal := 0.1, rough := 0.55) -> Material:
	var key := "b%s_%.2f_%.2f" % [col.to_html(), metal, rough]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _block_shader
		m.set_shader_parameter("albedo", col)
		m.set_shader_parameter("metal", metal)
		m.set_shader_parameter("rough", rough)
		_mats[key] = m
	return _mats[key]


func glow_mat(col: Color, energy := 3.0, additive := false) -> Material:
	var key := "g%s_%.1f_%s" % [col.to_html(), energy, additive]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


func ghost_mat(ok: bool) -> Material:
	var key := "ghost_%s" % ok
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.35, 1.0, 0.55, 0.45) if ok else Color(1.0, 0.3, 0.3, 0.45)
		m.no_depth_test = false
		_mats[key] = m
	return _mats[key]


func box_mesh(size: Vector3) -> Mesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


func cyl_mesh(rt: float, rb: float, h: float, segs := 16) -> Mesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [rt, rb, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


func sphere_mesh(r: float, hemi := false) -> Mesh:
	var key := "sph%.3f_%s" % [r, hemi]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r if hemi else r * 2.0
		m.is_hemisphere = hemi
		m.radial_segments = 20
		m.rings = 10
		_meshes[key] = m
	return _meshes[key]


func torus_mesh(inner: float, outer: float) -> Mesh:
	var key := "tor%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]


func capsule_mesh(r: float, h: float) -> Mesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		_meshes[key] = m
	return _meshes[key]


## Adds one triangle with outward normal `n`, fixing winding so faces render front-side.
static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


func wedge_mesh() -> Mesh:
	if _meshes.has("wedge"):
		return _meshes["wedge"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	var p0 := Vector3(-h, -h, -h); var p1 := Vector3(h, -h, -h)
	var p2 := Vector3(-h, -h, h); var p3 := Vector3(h, -h, h)
	var p4 := Vector3(-h, h, h); var p5 := Vector3(h, h, h)
	add_tri(st, p0, p1, p3, Vector3.DOWN); add_tri(st, p0, p3, p2, Vector3.DOWN)
	add_tri(st, p2, p3, p5, Vector3.BACK); add_tri(st, p2, p5, p4, Vector3.BACK)
	var sn := Vector3(0, 1, -1).normalized()
	add_tri(st, p0, p1, p5, sn); add_tri(st, p0, p5, p4, sn)
	add_tri(st, p0, p2, p4, Vector3.LEFT)
	add_tri(st, p1, p3, p5, Vector3.RIGHT)
	var m := st.commit()
	_meshes["wedge"] = m
	return m


func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	m.material_override = material
	parent.add_child(m)
	return m


func _node(parent: Node3D, nm: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n


func _flame(parent: Node3D, z: float, radius: float, col: Color) -> void:
	var f := _node(parent, "flame", Vector3(0, 0, z))
	_mi(f, cyl_mesh(0.02, radius, 1.0, 12), Vector3(0, 0, 0.5), glow_mat(col, 4.0, true), Vector3(PI * 0.5, 0, 0))
	_mi(f, cyl_mesh(0.01, radius * 0.5, 0.7, 10), Vector3(0, 0, 0.35), glow_mat(Color(1, 1, 0.85), 6.0, true), Vector3(PI * 0.5, 0, 0))
	f.scale = Vector3(1, 1, 0.001)
	f.visible = false


const DARK := Color("#2b2f36")
const STEEL := Color("#8b949e")
const RUBBER := Color("#1d1f23")

func _particles(parent: Node3D, nm: String, pos: Vector3, dir: Vector3, col: Color, fire: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.position = pos
	p.amount = 90 if not fire else 70
	p.lifetime = 3.0 if not fire else 0.55
	p.local_coords = false
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 8.0 if not fire else 14.0
	pm.initial_velocity_min = 2.0 if not fire else 16.0
	pm.initial_velocity_max = 4.0 if not fire else 22.0
	pm.gravity = Vector3(0, 0.6, 0) if not fire else Vector3(0, 2.0, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 2.6 if not fire else 3.0))
	curve.curve = c
	pm.scale_curve = curve
	var ramp := GradientTexture1D.new()
	var g := Gradient.new()
	if fire:
		g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
		g.set_color(1, Color(0.6, 0.1, 0.0, 0.0))
		g.add_point(0.35, Color(1.0, 0.45, 0.1, 0.9))
	else:
		g.set_color(0, Color(col.r, col.g, col.b, 0.9))
		g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	ramp.gradient = g
	pm.color_ramp = ramp
	p.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.25 if not fire else 0.3
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if fire else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if fire:
		smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.material = smat
	p.draw_pass_1 = sm
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- visuals

func make_visual(id: String, col: Color) -> Node3D:
	var r := Node3D.new()
	var dk := col.darkened(0.35)
	match id:
		"cube":
			_mi(r, box_mesh(Vector3.ONE), Vector3.ZERO, block_mat(col))
		"wood":
			_mi(r, box_mesh(Vector3.ONE), Vector3.ZERO, block_mat(col, 0.0, 0.85))
			for i in 3:
				_mi(r, box_mesh(Vector3(1.01, 0.03, 1.01)), Vector3(0, -0.3 + i * 0.3, 0), mat(col.darkened(0.25), 0.0, 0.9))
		"armor":
			_mi(r, box_mesh(Vector3.ONE), Vector3.ZERO, block_mat(col, 0.6, 0.4))
			for x in [-0.33, 0.33]:
				for z in [-0.33, 0.33]:
					_mi(r, cyl_mesh(0.05, 0.05, 0.04, 8), Vector3(x, 0.51, z), mat(STEEL, 0.8, 0.3))
		"wedge":
			_mi(r, wedge_mesh(), Vector3.ZERO, mat(col, 0.1, 0.55))
		"plate":
			_mi(r, box_mesh(Vector3(1, 0.2, 1)), Vector3(0, -0.4, 0), mat(col, 0.2, 0.5))
		"seat":
			_mi(r, box_mesh(Vector3(1, 0.4, 1)), Vector3(0, -0.3, 0), mat(col, 0.1, 0.5))
			_mi(r, box_mesh(Vector3(0.8, 0.75, 0.16)), Vector3(0, 0.25, 0.38), mat(DARK, 0.1, 0.7))
			_mi(r, box_mesh(Vector3(0.7, 0.12, 0.6)), Vector3(0, -0.05, 0.05), mat(DARK, 0.1, 0.8))
			_mi(r, box_mesh(Vector3(0.9, 0.28, 0.18)), Vector3(0, 0.02, -0.41), mat(dk, 0.2, 0.5))
			_mi(r, torus_mesh(0.1, 0.15), Vector3(0, 0.22, -0.26), mat(DARK, 0.3, 0.5), Vector3(-PI / 3.0, 0, 0))
			# little robot driver
			_mi(r, box_mesh(Vector3(0.36, 0.34, 0.24)), Vector3(0, 0.18, 0.18), mat(Color("#e9edf2"), 0.3, 0.4))
			_mi(r, sphere_mesh(0.19), Vector3(0, 0.5, 0.16), mat(Color("#f4f6f9"), 0.3, 0.3))
			_mi(r, box_mesh(Vector3(0.3, 0.1, 0.06)), Vector3(0, 0.52, -0.02), glow_mat(Color("#39e1ff"), 2.5))
		"wheel", "bigwheel":
			var rad: float = defs[id].radius
			var w := rad * 0.8
			var spin := _node(r, "spin")
			_mi(spin, cyl_mesh(rad, rad, w, 24), Vector3.ZERO, mat(RUBBER, 0.0, 0.95), Vector3(0, 0, PI * 0.5))
			_mi(spin, cyl_mesh(rad * 0.62, rad * 0.62, w + 0.02, 16), Vector3.ZERO, mat(col, 0.5, 0.35), Vector3(0, 0, PI * 0.5))
			_mi(spin, cyl_mesh(rad * 0.2, rad * 0.2, w + 0.06, 10), Vector3.ZERO, mat(STEEL, 0.8, 0.3), Vector3(0, 0, PI * 0.5))
			for i in 3:
				var s := _node(spin, "s%d" % i)
				s.rotation.x = i * PI / 3.0
				_mi(s, box_mesh(Vector3(w + 0.04, rad * 1.15, rad * 0.14)), Vector3.ZERO, mat(col.darkened(0.25), 0.5, 0.4))
			for i in 10:
				var t := _node(spin, "t%d" % i)
				t.rotation.x = i * TAU / 10.0
				_mi(t, box_mesh(Vector3(w * 0.9, 0.08, rad * 0.22)), Vector3(0, rad, 0), mat(RUBBER, 0.0, 1.0))
		"thruster":
			_mi(r, cyl_mesh(0.32, 0.32, 0.75, 16), Vector3(0, 0, -0.08), mat(col, 0.6, 0.35), Vector3(PI * 0.5, 0, 0))
			_mi(r, sphere_mesh(0.32), Vector3(0, 0, -0.45), mat(col, 0.6, 0.35))
			_mi(r, cyl_mesh(0.3, 0.2, 0.3, 16), Vector3(0, 0, 0.42), mat(DARK, 0.7, 0.4), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.19, 0.19, 0.02, 16), Vector3(0, 0, 0.56), glow_mat(Color("#ff9a3d"), 3.0), Vector3(PI * 0.5, 0, 0))
			_mi(r, box_mesh(Vector3(0.12, 0.4, 0.4)), Vector3(0, 0.3, 0.0), mat(dk, 0.3, 0.5))
			_flame(r, 0.56, 0.2, Color("#4fb3ff"))
		"jet":
			_mi(r, torus_mesh(0.34, 0.46), Vector3(0, 0, -0.45), mat(STEEL, 0.8, 0.25), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.44, 0.4, 0.95, 20), Vector3(0, 0, 0), mat(col, 0.7, 0.3), Vector3(PI * 0.5, 0, 0))
			var fan := _node(r, "spin", Vector3(0, 0, -0.42))
			_mi(fan, cyl_mesh(0.12, 0.12, 0.1, 10), Vector3.ZERO, mat(DARK, 0.5, 0.4), Vector3(PI * 0.5, 0, 0))
			for i in 6:
				var b := _node(fan, "b%d" % i)
				b.rotation.z = i * TAU / 6.0
				_mi(b, box_mesh(Vector3(0.06, 0.34, 0.03)), Vector3(0, 0.2, 0), mat(Color("#c0c6ce"), 0.9, 0.2), Vector3(0, 0.5, 0))
			_mi(r, cyl_mesh(0.3, 0.38, 0.3, 20), Vector3(0, 0, 0.55), mat(DARK, 0.8, 0.35), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.26, 0.26, 0.02, 16), Vector3(0, 0, 0.7), glow_mat(Color("#ff6a2a"), 3.0), Vector3(PI * 0.5, 0, 0))
			_flame(r, 0.7, 0.3, Color("#ff7a2a"))
		"rocket":
			_mi(r, cyl_mesh(0.34, 0.34, 0.9, 16), Vector3(0, 0, 0.05), mat(col, 0.2, 0.4), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.0, 0.34, 0.4, 16), Vector3(0, 0, -0.6), mat(Color("#e53935"), 0.2, 0.4), Vector3(-PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.34, 0.345, 0.12, 16), Vector3(0, 0, 0.0), mat(Color("#e53935"), 0.2, 0.4), Vector3(PI * 0.5, 0, 0))
			for i in 3:
				var fn := _node(r, "f%d" % i)
				fn.rotation.z = i * TAU / 3.0
				_mi(fn, box_mesh(Vector3(0.04, 0.3, 0.35)), Vector3(0, 0.45, 0.35), mat(Color("#e53935"), 0.2, 0.4))
			_mi(r, cyl_mesh(0.28, 0.2, 0.2, 14), Vector3(0, 0, 0.58), mat(DARK, 0.8, 0.4), Vector3(PI * 0.5, 0, 0))
			_flame(r, 0.68, 0.32, Color("#ffb03a"))
		"prop":
			_mi(r, cyl_mesh(0.28, 0.33, 0.7, 16), Vector3(0, 0, 0.12), mat(col.darkened(0.2), 0.5, 0.4), Vector3(PI * 0.5, 0, 0))
			var sp := _node(r, "spin", Vector3(0, 0, -0.32))
			_mi(sp, cyl_mesh(0.0, 0.18, 0.3, 14), Vector3(0, 0, -0.1), mat(Color("#e53935"), 0.4, 0.4), Vector3(-PI * 0.5, 0, 0))
			for i in 3:
				var b := _node(sp, "b%d" % i)
				b.rotation.z = i * TAU / 3.0
				_mi(b, box_mesh(Vector3(0.14, 0.95, 0.04)), Vector3(0, 0.55, 0), mat(col, 0.2, 0.5), Vector3(0, 0.35, 0))
				_mi(b, box_mesh(Vector3(0.145, 0.12, 0.045)), Vector3(0, 0.97, 0), mat(Color("#f2f2f2"), 0.2, 0.5), Vector3(0, 0.35, 0))
		"rotor":
			_mi(r, box_mesh(Vector3(0.8, 0.3, 0.8)), Vector3(0, -0.35, 0), mat(col, 0.5, 0.4))
			_mi(r, cyl_mesh(0.08, 0.1, 0.8, 10), Vector3(0, 0.1, 0), mat(STEEL, 0.8, 0.3))
			var rs := _node(r, "spin", Vector3(0, 0.48, 0))
			_mi(rs, cyl_mesh(0.16, 0.16, 0.12, 12), Vector3.ZERO, mat(DARK, 0.6, 0.4))
			for i in 2:
				var b := _node(rs, "b%d" % i)
				b.rotation.y = i * PI
				_mi(b, box_mesh(Vector3(1.7, 0.04, 0.24)), Vector3(0.9, 0, 0), mat(Color("#30353d"), 0.3, 0.5), Vector3(0.08, 0, 0))
				_mi(b, box_mesh(Vector3(0.2, 0.045, 0.245)), Vector3(1.65, 0, 0), mat(Color("#ffcc00"), 0.2, 0.5), Vector3(0.08, 0, 0))
		"balloon":
			_mi(r, box_mesh(Vector3(0.7, 0.2, 0.7)), Vector3(0, -0.4, 0), mat(Color("#8a5a2b"), 0.0, 0.9))
			for x in [-0.28, 0.28]:
				for z in [-0.28, 0.28]:
					_mi(r, cyl_mesh(0.015, 0.015, 1.6, 4), Vector3(x * 0.8, 0.45, z * 0.8), mat(Color("#dddddd"), 0, 1))
			_mi(r, sphere_mesh(0.95), Vector3(0, 2.0, 0), mat(col, 0.0, 0.25))
			_mi(r, cyl_mesh(0.18, 0.08, 0.2, 10), Vector3(0, 1.0, 0), mat(col.darkened(0.2), 0.0, 0.4))
		"wing":
			_mi(r, box_mesh(Vector3(1, 0.1, 0.92)), Vector3(0, 0, 0.04), mat(col, 0.2, 0.45))
			_mi(r, cyl_mesh(0.07, 0.07, 1.0, 10), Vector3(0, 0.0, -0.44), mat(col, 0.2, 0.45), Vector3(0, 0, PI * 0.5))
			_mi(r, box_mesh(Vector3(1.0, 0.04, 0.12)), Vector3(0, 0.0, 0.48), mat(col.darkened(0.2), 0.2, 0.5))
		"flap":
			_mi(r, box_mesh(Vector3(1, 0.1, 0.38)), Vector3(0, 0, -0.29), mat(Color("#e6ebf2"), 0.2, 0.45))
			_mi(r, cyl_mesh(0.07, 0.07, 1.0, 10), Vector3(0, 0, -0.44), mat(Color("#e6ebf2"), 0.2, 0.45), Vector3(0, 0, PI * 0.5))
			_mi(r, cyl_mesh(0.05, 0.05, 1.02, 8), Vector3(0, 0, -0.08), mat(DARK, 0.6, 0.4), Vector3(0, 0, PI * 0.5))
			var fl := _node(r, "flap", Vector3(0, 0, -0.08))
			_mi(fl, box_mesh(Vector3(0.98, 0.07, 0.56)), Vector3(0, 0, 0.29), mat(col, 0.2, 0.45))
		"gyro":
			_mi(r, box_mesh(Vector3(0.9, 0.2, 0.9)), Vector3(0, -0.4, 0), mat(DARK, 0.5, 0.4))
			var gs := _node(r, "spin")
			_mi(gs, torus_mesh(0.3, 0.38), Vector3.ZERO, mat(col, 0.7, 0.25))
			_mi(gs, torus_mesh(0.22, 0.29), Vector3.ZERO, mat(col.darkened(0.2), 0.7, 0.25), Vector3(PI * 0.5, 0, 0))
			_mi(r, sphere_mesh(0.14), Vector3.ZERO, glow_mat(Color("#7fe7ff"), 3.0))
		"parachute":
			_mi(r, box_mesh(Vector3(0.8, 0.45, 0.8)), Vector3(0, -0.27, 0), mat(Color("#3b4a2f"), 0.0, 0.9))
			_mi(r, box_mesh(Vector3(0.6, 0.06, 0.6)), Vector3(0, -0.02, 0), mat(col, 0.0, 0.8))
			var cn := _node(r, "canopy")
			var cm := StandardMaterial3D.new()
			cm.albedo_color = col
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_mi(cn, sphere_mesh(3.0, true), Vector3(0, 4.0, 0), cm)
			_mi(cn, torus_mesh(2.92, 3.02), Vector3(0, 4.0, 0), mat(Color("#e53935"), 0.0, 0.8))
			for i in 6:
				var a := i * TAU / 6.0
				var top := Vector3(cos(a) * 2.95, 4.0, sin(a) * 2.95)
				var ln := _mi(cn, cyl_mesh(0.015, 0.015, top.length(), 4), top * 0.5, mat(Color("#dddddd"), 0, 1))
				ln.basis = Basis(Quaternion(Vector3.UP, top.normalized()))
			cn.visible = false
		"float":
			_mi(r, capsule_mesh(0.46, 1.0), Vector3.ZERO, mat(col, 0.0, 0.5), Vector3(PI * 0.5, 0, 0))
			_mi(r, torus_mesh(0.42, 0.5), Vector3.ZERO, mat(Color("#f4f4f4"), 0.0, 0.6), Vector3(PI * 0.5, 0, 0))
		"boatprop":
			_mi(r, box_mesh(Vector3(0.3, 0.5, 0.5)), Vector3(0, 0.2, -0.15), mat(DARK, 0.5, 0.4))
			_mi(r, cyl_mesh(0.07, 0.07, 0.7, 8), Vector3(0, -0.1, 0.1), mat(STEEL, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			_mi(r, torus_mesh(0.36, 0.42), Vector3(0, -0.1, 0.38), mat(col.darkened(0.2), 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			var bs := _node(r, "spin", Vector3(0, -0.1, 0.38))
			for i in 3:
				var b := _node(bs, "b%d" % i)
				b.rotation.z = i * TAU / 3.0
				_mi(b, box_mesh(Vector3(0.2, 0.34, 0.03)), Vector3(0, 0.18, 0), mat(col, 0.9, 0.25), Vector3(0, 0.6, 0))
		"mg":
			_mi(r, box_mesh(Vector3(0.3, 0.15, 0.3)), Vector3(0, -0.4, 0), mat(DARK, 0.5, 0.4))
			_mi(r, box_mesh(Vector3(0.38, 0.34, 0.7)), Vector3(0, -0.1, 0.1), mat(col, 0.6, 0.35))
			_mi(r, cyl_mesh(0.06, 0.06, 0.9, 10), Vector3(0, -0.06, -0.6), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.09, 0.09, 0.16, 10), Vector3(0, -0.06, -1.0), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			_mi(r, box_mesh(Vector3(0.22, 0.28, 0.32)), Vector3(0.3, -0.12, 0.12), mat(Color("#5d6b3a"), 0.2, 0.6))
		"cannon":
			_mi(r, box_mesh(Vector3(0.62, 0.5, 0.7)), Vector3(0, -0.1, 0.12), mat(col, 0.5, 0.4))
			var rc := _node(r, "recoil")
			_mi(rc, cyl_mesh(0.13, 0.15, 1.3, 14), Vector3(0, -0.02, -0.72), mat(DARK, 0.7, 0.35), Vector3(PI * 0.5, 0, 0))
			_mi(rc, cyl_mesh(0.18, 0.18, 0.2, 14), Vector3(0, -0.02, -1.35), mat(DARK, 0.7, 0.35), Vector3(PI * 0.5, 0, 0))
		"rockets":
			_mi(r, box_mesh(Vector3(0.82, 0.82, 0.9)), Vector3.ZERO, mat(col, 0.4, 0.45))
			for x in [-0.2, 0.2]:
				for y in [-0.2, 0.2]:
					_mi(r, cyl_mesh(0.15, 0.15, 0.94, 12), Vector3(x, y, 0), mat(DARK, 0.6, 0.4), Vector3(PI * 0.5, 0, 0))
					_mi(r, sphere_mesh(0.1), Vector3(x, y, -0.45), mat(Color("#e53935"), 0.2, 0.5))
		"laser":
			_mi(r, box_mesh(Vector3(0.4, 0.4, 0.85)), Vector3(0, -0.05, 0.05), mat(col, 0.5, 0.25))
			_mi(r, box_mesh(Vector3(0.6, 0.06, 0.3)), Vector3(0, -0.05, 0.25), mat(DARK, 0.5, 0.3))
			_mi(r, cyl_mesh(0.1, 0.14, 0.3, 12), Vector3(0, -0.05, -0.48), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			_mi(r, cyl_mesh(0.07, 0.07, 0.02, 12), Vector3(0, -0.05, -0.64), glow_mat(Color("#ff2244"), 4.0), Vector3(PI * 0.5, 0, 0))
			var beam := _node(r, "beam", Vector3(0, -0.05, -0.65))
			_mi(beam, cyl_mesh(0.06, 0.06, 1.0, 8), Vector3(0, 0, -0.5), glow_mat(Color("#ff2244"), 6.0, true), Vector3(PI * 0.5, 0, 0))
			_mi(beam, cyl_mesh(0.025, 0.025, 1.0, 6), Vector3(0, 0, -0.5), glow_mat(Color(1, 0.9, 0.9), 8.0, true), Vector3(PI * 0.5, 0, 0))
			beam.visible = false
		"flamer":
			_mi(r, cyl_mesh(0.24, 0.24, 0.7, 14), Vector3(0, -0.12, 0.2), mat(col, 0.4, 0.4))
			_mi(r, sphere_mesh(0.24), Vector3(0, 0.23, 0.2), mat(col, 0.4, 0.4))
			_mi(r, cyl_mesh(0.07, 0.09, 0.6, 10), Vector3(0, -0.05, -0.32), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			_mi(r, sphere_mesh(0.05), Vector3(0, -0.12, -0.6), glow_mat(Color("#4fa8ff"), 4.0))
			_particles(r, "particles", Vector3(0, -0.05, -0.65), Vector3(0, 0, -1), Color.ORANGE, true)
		"bombs":
			for x in [-0.44, 0.44]:
				_mi(r, box_mesh(Vector3(0.12, 0.7, 1)), Vector3(x, 0.1, 0), mat(col, 0.3, 0.6))
			_mi(r, box_mesh(Vector3(1, 0.15, 1)), Vector3(0, 0.42, 0), mat(col, 0.3, 0.6))
			var bomb := _node(r, "bomb", Vector3(0, -0.05, 0))
			_mi(bomb, capsule_mesh(0.22, 0.85), Vector3.ZERO, mat(Color("#2f3a28"), 0.4, 0.5), Vector3(PI * 0.5, 0, 0))
			_mi(bomb, box_mesh(Vector3(0.4, 0.04, 0.2)), Vector3(0, 0, 0.42), mat(DARK, 0.4, 0.5))
			_mi(bomb, box_mesh(Vector3(0.04, 0.4, 0.2)), Vector3(0, 0, 0.42), mat(DARK, 0.4, 0.5))
		"turret":
			_mi(r, cyl_mesh(0.45, 0.48, 0.24, 18), Vector3(0, -0.38, 0), mat(DARK, 0.6, 0.4))
			var yaw := _node(r, "yaw", Vector3(0, -0.2, 0))
			_mi(yaw, cyl_mesh(0.36, 0.4, 0.4, 16), Vector3(0, 0.15, 0), mat(col, 0.4, 0.45))
			var pt := _node(yaw, "pitch", Vector3(0, 0.25, 0))
			_mi(pt, box_mesh(Vector3(0.5, 0.26, 0.42)), Vector3.ZERO, mat(col.darkened(0.15), 0.4, 0.45))
			for x in [-0.13, 0.13]:
				_mi(pt, cyl_mesh(0.05, 0.05, 0.9, 8), Vector3(x, 0, -0.6), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
		"jump":
			_mi(r, box_mesh(Vector3(0.9, 0.18, 0.9)), Vector3(0, 0.41, 0), mat(col, 0.3, 0.5))
			var coil := _node(r, "coil")
			for i in 5:
				_mi(coil, torus_mesh(0.22, 0.29), Vector3(0, 0.25 - i * 0.13, 0), mat(STEEL, 0.9, 0.25))
			_mi(coil, box_mesh(Vector3(0.75, 0.1, 0.75)), Vector3(0, -0.44, 0), mat(DARK, 0.4, 0.6))
		"magnet":
			for x in [-0.3, 0.3]:
				_mi(r, box_mesh(Vector3(0.26, 0.62, 0.32)), Vector3(x, -0.05, 0), mat(col, 0.3, 0.4))
				_mi(r, box_mesh(Vector3(0.27, 0.16, 0.33)), Vector3(x, -0.43, 0), mat(Color("#d7dbe0"), 0.9, 0.2))
			_mi(r, box_mesh(Vector3(0.86, 0.26, 0.32)), Vector3(0, 0.33, 0), mat(col, 0.3, 0.4))
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.4, 0.7, 1.0, 0.12)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var field := _mi(r, sphere_mesh(1.6), Vector3.ZERO, fm)
			field.name = "field"
			field.visible = false
		"tnt":
			for p in [Vector3(-0.2, 0, -0.12), Vector3(0.2, 0, -0.12), Vector3(0, 0, 0.2)]:
				_mi(r, cyl_mesh(0.19, 0.19, 0.86, 12), p, mat(col, 0.0, 0.7))
			_mi(r, box_mesh(Vector3(0.82, 0.12, 0.72)), Vector3(0, 0.15, 0.03), mat(DARK, 0.1, 0.8))
			_mi(r, box_mesh(Vector3(0.82, 0.12, 0.72)), Vector3(0, -0.2, 0.03), mat(DARK, 0.1, 0.8))
			_mi(r, box_mesh(Vector3(0.3, 0.12, 0.2)), Vector3(0, 0.48, 0), mat(DARK, 0.4, 0.5))
			var led := _mi(r, sphere_mesh(0.05), Vector3(0.08, 0.56, 0), glow_mat(Color("#ff2020"), 5.0))
			led.name = "led"
		"smoke":
			_mi(r, cyl_mesh(0.28, 0.28, 0.75, 14), Vector3(0, -0.1, -0.05), mat(col, 0.3, 0.45))
			_mi(r, sphere_mesh(0.28), Vector3(0, 0.27, -0.05), mat(col, 0.3, 0.45))
			_mi(r, cyl_mesh(0.08, 0.12, 0.4, 10), Vector3(0, -0.1, 0.35), mat(DARK, 0.7, 0.4), Vector3(PI * 0.5, 0, 0))
			_particles(r, "particles", Vector3(0, -0.1, 0.6), Vector3(0, 0, 1), col, false)
		"light":
			_mi(r, box_mesh(Vector3(0.7, 0.45, 0.4)), Vector3(0, -0.1, 0.12), mat(col, 0.4, 0.4))
			_mi(r, cyl_mesh(0.22, 0.24, 0.12, 16), Vector3(0, -0.1, -0.12), mat(STEEL, 0.9, 0.2), Vector3(PI * 0.5, 0, 0))
			var lens := _mi(r, cyl_mesh(0.19, 0.19, 0.02, 16), Vector3(0, -0.1, -0.19), glow_mat(Color("#fff3c4"), 4.0), Vector3(PI * 0.5, 0, 0))
			lens.name = "lens"
			var sl := SpotLight3D.new()
			sl.name = "lamp"
			sl.position = Vector3(0, -0.1, -0.3)
			sl.spot_range = 45.0
			sl.spot_angle = 28.0
			sl.light_energy = 6.0
			sl.light_color = Color("#fff3d1")
			sl.visible = false
			r.add_child(sl)
		"horn":
			_mi(r, box_mesh(Vector3(0.5, 0.4, 0.4)), Vector3(0, -0.25, 0.25), mat(DARK, 0.3, 0.5))
			_mi(r, cyl_mesh(0.32, 0.07, 0.75, 16), Vector3(0, -0.05, -0.2), mat(col, 0.9, 0.2), Vector3(-PI * 0.5, 0, 0))
		_:
			_mi(r, box_mesh(Vector3.ONE * 0.9), Vector3.ZERO, mat(col))
	return r


## Replaces every surface material in a visual with a ghost material.
func ghostify(n: Node, ok: bool) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.material_override = ghost_mat(ok)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif c is GPUParticles3D or c is Light3D:
			c.visible = false
		ghostify(c, ok)


# ---------------------------------------------------------------- collision

## Returns [Shape3D, local Transform3D] for the block's collider inside its cell.
func shape_for(id: String) -> Array:
	var kind: String = defs[id].shape if defs.has(id) else "box"
	if not _shapes.has(kind):
		match kind:
			"wedge":
				var c := ConvexPolygonShape3D.new()
				c.points = PackedVector3Array([
					Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5),
					Vector3(0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(0.5, 0.5, 0.5)])
				_shapes[kind] = [c, Transform3D.IDENTITY]
			"plate":
				var b := BoxShape3D.new()
				b.size = Vector3(1, 0.2, 1)
				_shapes[kind] = [b, Transform3D(Basis.IDENTITY, Vector3(0, -0.4, 0))]
			"wing":
				var b := BoxShape3D.new()
				b.size = Vector3(1, 0.14, 1)
				_shapes[kind] = [b, Transform3D.IDENTITY]
			"wheel", "bigwheel":
				var s := SphereShape3D.new()
				s.radius = 0.28 if kind == "wheel" else 0.46
				_shapes[kind] = [s, Transform3D.IDENTITY]
			_:
				var b := BoxShape3D.new()
				b.size = Vector3.ONE
				_shapes[kind] = [b, Transform3D.IDENTITY]
	return _shapes[kind]


# ---------------------------------------------------------------- icons

## Palette icon rendered once by an offscreen viewport.
func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var root := Node3D.new()
	vp.add_child(root)
	var v := make_visual(id, defs[id].color)
	root.add_child(v)
	if id == "wheel" or id == "bigwheel":
		v.rotation = Vector3(0, PI * 0.5, 0)
	var cam := Camera3D.new()
	var ext := 1.0
	match id:
		"balloon": ext = 3.2
		"rotor": ext = 3.6
		"parachute": ext = 1.3
		"bigwheel": ext = 1.7
	cam.fov = 34
	var dir := Vector3(1.0, 0.8, 1.15).normalized()
	var focus := Vector3(0, 1.1, 0) if id == "balloon" else Vector3.ZERO
	var cpos := focus + dir * (2.6 * ext)
	cam.transform = Transform3D(Basis.looking_at(focus - cpos, Vector3.UP), cpos)
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	add_child(vp)
	var tex := vp.get_texture()
	_icons[id] = tex
	return tex
