extends Node
## Block catalog: definitions, the 24 grid orientations, procedural visuals,
## collision shapes and palette icons.

const CATS := ["Structure", "Wheels", "Mechanical", "Propulsion", "Flight", "Water", "Weapons", "Gadgets"]
const CAT_COLORS := {
	"Structure": Color("#9aa4b1"), "Wheels": Color("#e0b341"), "Mechanical": Color("#9ccc65"),
	"Propulsion": Color("#ff7a3d"), "Flight": Color("#5fb8ff"), "Water": Color("#3fd6c6"),
	"Weapons": Color("#ff4f5e"), "Gadgets": Color("#b98cff"),
}
## Mechanism kinds that carry the blocks attached to their output face.
const MOVERS := ["piston", "hinge", "rotator"]

var defs := {}
var order: Array[String] = []
var rots: Array[Basis] = []
var _mats := {}
var _meshes := {}
var _shapes := {}
var _icons := {}
var _block_shader: Shader
const Models := preload("res://scripts/block_models.gd")


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


func mirror_basis(b: Basis) -> Basis:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return snap_basis(m * b * m)


## Index of the grid orientation `b` matches, or -1 for a free (e.g. 45 degree) one.
func grid_index(b: Basis) -> int:
	for i in rots.size():
		var r := rots[i]
		if r.x.distance_to(b.x) < 0.01 and r.y.distance_to(b.y) < 0.01 and r.z.distance_to(b.z) < 0.01:
			return i
	return -1


## Re-orthonormalises `b` and snaps it exactly onto a grid orientation when close.
func snap_basis(b: Basis) -> Basis:
	b = b.orthonormalized()
	var i := grid_index(b)
	return rots[i] if i >= 0 else b


## The grid orientation nearest to `b`.
func nearest_grid(b: Basis) -> Basis:
	var best := 0
	var bd := -INF
	for i in rots.size():
		var r := rots[i]
		var d := r.x.dot(b.x) + r.y.dot(b.y) + r.z.dot(b.z)
		if d > bd:
			bd = d
			best = i
	return rots[best]


# ---------------------------------------------------------------- design block geometry
# A design block is {"id", "p": key cell, "r": grid orientation, "c", "cfg"} plus the
# optional "o" (offset of its centre from p), "s" (size, Structure blocks only) and
# "q" (quaternion for orientations off the 24-grid, e.g. 45 degrees).

func basis_of(b: Dictionary) -> Basis:
	var def: Dictionary = defs.get(b.id, {})
	if def.get("auto_rot", false):
		return Basis.IDENTITY
	if b.has("q"):
		var q: Array = b.q
		return Basis(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
	return rots[clampi(int(b.get("r", 0)), 0, 23)]


func set_basis(b: Dictionary, basis: Basis) -> void:
	basis = snap_basis(basis)
	var i := grid_index(basis)
	if i >= 0:
		b.r = i
		b.erase("q")
	else:
		var q := basis.get_rotation_quaternion()
		b.r = 0
		b.q = [snappedf(q.x, 0.00001), snappedf(q.y, 0.00001), snappedf(q.z, 0.00001), snappedf(q.w, 0.00001)]


func center_of(b: Dictionary) -> Vector3:
	var c := Vector3(float(b.p[0]), float(b.p[1]), float(b.p[2]))
	if b.has("o"):
		c += Vector3(float(b.o[0]), float(b.o[1]), float(b.o[2]))
	return c


func size_of(b: Dictionary) -> Vector3:
	if b.has("s") and resizable(b.id):
		return Vector3(float(b.s[0]), float(b.s[1]), float(b.s[2]))
	return Vector3.ONE


## Plain structure blocks can be resized; seats, mechanisms and devices can't.
func resizable(id: String) -> bool:
	return defs.has(id) and defs[id].kind == "struct"


func volume_of(b: Dictionary) -> float:
	var s := size_of(b)
	return s.x * s.y * s.z


## Tight box (block-local, before rotation) used for snapping and overlap tests.
func local_box(id: String, size := Vector3.ONE) -> AABB:
	var box := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	match defs[id].shape if defs.has(id) else "box":
		"plate": box = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 0.2, 1))
		"half": box = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 0.5, 1))
		"beam": box = AABB(Vector3(-0.17, -0.5, -0.17), Vector3(0.34, 1, 0.34))
	return AABB(box.position * size, box.size * size)


## Axis-aligned bounds of a rotated, scaled unit cell: the footprint used for connectivity.
func cell_box(b: Dictionary) -> AABB:
	var bs := basis_of(b)
	var s := size_of(b) * 0.5
	var h := Vector3(
		absf(bs.x.x) * s.x + absf(bs.y.x) * s.y + absf(bs.z.x) * s.z,
		absf(bs.x.y) * s.x + absf(bs.y.y) * s.y + absf(bs.z.y) * s.z,
		absf(bs.x.z) * s.x + absf(bs.y.z) * s.y + absf(bs.z.z) * s.z)
	return AABB(center_of(b) - h, h * 2.0)


## Blocks share a face (or overlap): connected for building, physics and mechanisms.
static func boxes_touch(a: AABB, b: AABB) -> bool:
	var faces := 0
	for k in 3:
		var ov := minf(a.end[k], b.end[k]) - maxf(a.position[k], b.position[k])
		if ov < -0.03:
			return false
		if ov > 0.05:
			faces += 1
	return faces >= 2


## Neighbour lists (indices into `blocks`) of every block whose footprints touch.
func adjacency(blocks: Array) -> Array:
	var boxes: Array[AABB] = []
	var grid := {}
	var adj := []
	for i in blocks.size():
		var bx := cell_box(blocks[i])
		boxes.append(bx)
		adj.append([])
		var lo := Vector3i((bx.position - Vector3.ONE * 0.05).floor())
		var hi := Vector3i((bx.end + Vector3.ONE * 0.05).floor())
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var k := Vector3i(x, y, z)
					if not grid.has(k):
						grid[k] = []
					grid[k].append(i)
	var seen := {}
	for k in grid:
		var lst: Array = grid[k]
		for a in lst.size():
			for c in range(a + 1, lst.size()):
				var i: int = lst[a]
				var j: int = lst[c]
				var pk := Vector2i(mini(i, j), maxi(i, j))
				if seen.has(pk):
					continue
				seen[pk] = true
				if boxes_touch(boxes[i], boxes[j]):
					adj[i].append(j)
					adj[j].append(i)
	return adj


# ---------------------------------------------------------------- catalog

func _d(id: String, nm: String, cat: String, mass: float, hp: float, col: String, desc: String, extra := {}) -> void:
	var d := {
		"id": id, "name": nm, "cat": cat, "mass": mass, "hp": hp, "color": Color(col),
		"desc": desc, "shape": "box", "buoy": 0.06, "cfg": {}, "auto_rot": false,
		"kind": id, "vis": id, "vs": 1.0,
	}
	d.merge(extra, true)
	defs[id] = d
	order.append(id)


func _define_all() -> void:
	preload("res://scripts/block_catalog.gd").define(self)


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


## Soft round billboard used by smoke, fire and explosion particles.
func puff_mesh(size: float, additive: bool) -> Mesh:
	var key := "puff%.2f_%s" % [size, additive]
	if not _meshes.has(key):
		if not _mats.has("puff_tex"):
			var gt := GradientTexture2D.new()
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(1.0, 0.5)
			gt.width = 64
			gt.height = 64
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(0.45, Color(1, 1, 1, 0.75))
			gt.gradient = g
			_mats["puff_tex"] = gt
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = _mats["puff_tex"]
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var q := QuadMesh.new()
		q.size = Vector2.ONE * size * 2.0
		q.material = m
		_meshes[key] = q
	return _meshes[key]


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


const _H := 0.5
## Convex block shapes: [points, faces]. Faces list point indices of each polygon.
var POLYS := {
	"corner": [[Vector3(-_H, -_H, -_H), Vector3(_H, -_H, -_H), Vector3(-_H, -_H, _H), Vector3(_H, -_H, _H), Vector3(-_H, _H, _H)],
		[[0, 1, 3, 2], [2, 3, 4], [0, 2, 4], [0, 1, 4], [1, 3, 4]]],
	"inner": [[Vector3(-_H, -_H, -_H), Vector3(_H, -_H, -_H), Vector3(-_H, -_H, _H), Vector3(_H, -_H, _H), Vector3(-_H, _H, -_H), Vector3(-_H, _H, _H), Vector3(_H, _H, _H)],
		[[0, 1, 3, 2], [2, 3, 6, 5], [0, 2, 5, 4], [4, 5, 6], [0, 1, 4], [1, 3, 6], [4, 1, 6]]],
	"lowwedge": [[Vector3(-_H, -_H, -_H), Vector3(_H, -_H, -_H), Vector3(-_H, -_H, _H), Vector3(_H, -_H, _H), Vector3(-_H, 0, _H), Vector3(_H, 0, _H)],
		[[0, 1, 3, 2], [2, 3, 5, 4], [0, 1, 5, 4], [0, 2, 4], [1, 3, 5]]],
	"pyramid": [[Vector3(-_H, -_H, -_H), Vector3(_H, -_H, -_H), Vector3(-_H, -_H, _H), Vector3(_H, -_H, _H), Vector3(0, _H, 0)],
		[[0, 1, 3, 2], [0, 1, 4], [1, 3, 4], [3, 2, 4], [2, 0, 4]]],
}


## Flat-shaded convex mesh from points and polygon faces (normals point away from the centre).
func poly_mesh(key: String, pts: Array, faces: Array) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var ctr := Vector3.ZERO
	for p: Vector3 in pts:
		ctr += p
	ctr /= pts.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		var a: Vector3 = pts[f[0]]
		var n: Vector3 = (pts[f[1]] - a).cross(pts[f[2]] - a).normalized()
		if n.dot(a - ctr) < 0.0:
			n = -n
		for k in range(1, f.size() - 1):
			add_tri(st, a, pts[f[k]], pts[f[k + 1]], n)
	var m := st.commit()
	_meshes[key] = m
	return m


## [mesh, offset] for a structural shape name.
func shape_mesh(shp: String) -> Array:
	match shp:
		"wedge": return [wedge_mesh(), Vector3.ZERO]
		"plate": return [box_mesh(Vector3(1, 0.2, 1)), Vector3(0, -0.4, 0)]
		"half": return [box_mesh(Vector3(1, 0.5, 1)), Vector3(0, -0.25, 0)]
		"cyl": return [cyl_mesh(0.5, 0.5, 1.0, 20), Vector3.ZERO]
		"beam": return [box_mesh(Vector3(0.34, 1, 0.34)), Vector3.ZERO]
		"ball": return [sphere_mesh(0.5), Vector3.ZERO]
		"corner", "inner", "lowwedge", "pyramid":
			return [poly_mesh(shp, POLYS[shp][0], POLYS[shp][1]), Vector3.ZERO]
	return [box_mesh(Vector3.ONE), Vector3.ZERO]


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
	p.draw_pass_1 = puff_mesh(0.35 if not fire else 0.4, fire)
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- visuals

func make_visual(id: String, col: Color) -> Node3D:
	var r := Node3D.new()
	var def: Dictionary = defs[id]
	if not Models.build(r, def, col):
		_base_visual(r, def, col)
	if def.vis == "flap" and def.get("nrm", Vector3.UP) == Vector3.RIGHT:
		# upright flap (rudder): its surface normal is local X
		var upright := Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO)
		for c in r.get_children():
			c.transform = upright * c.transform
	var vs: float = def.vs
	if vs != 1.0:
		var sc := Transform3D(Basis.from_scale(Vector3.ONE * vs), Vector3.ZERO)
		for c in r.get_children():
			c.transform = sc * c.transform
	return r


func _base_visual(r: Node3D, def: Dictionary, col: Color) -> void:
	var dk := col.darkened(0.35)
	match def.vis:
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
			# little robot driver (hidden in first-person view)
			var drv := _node(r, "driver")
			_mi(drv, box_mesh(Vector3(0.36, 0.34, 0.24)), Vector3(0, 0.18, 0.18), mat(Color("#e9edf2"), 0.3, 0.4))
			_mi(drv, sphere_mesh(0.19), Vector3(0, 0.5, 0.16), mat(Color("#f4f6f9"), 0.3, 0.3))
			_mi(drv, box_mesh(Vector3(0.3, 0.1, 0.06)), Vector3(0, 0.52, -0.02), glow_mat(Color("#39e1ff"), 2.5))
		"wheel":
			Models.wheel(r, def, col)
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
				_mi(b, box_mesh(Vector3(1.7, 0.05, 0.34)), Vector3(0.9, 0, 0), mat(Color("#30353d"), 0.3, 0.5), Vector3(0.08, 0, 0))
				_mi(b, box_mesh(Vector3(0.22, 0.055, 0.345)), Vector3(1.65, 0, 0), mat(Color("#ffcc00"), 0.2, 0.5), Vector3(0.08, 0, 0))
			var blur := StandardMaterial3D.new()
			blur.albedo_color = Color(0.15, 0.17, 0.2, 0.22)
			blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			blur.cull_mode = BaseMaterial3D.CULL_DISABLED
			blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mi(r, cyl_mesh(1.75, 1.75, 0.02, 32), Vector3(0, 0.48, 0), blur).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			var lc := Color(def.get("lcol", "#ff2244"))
			var bw: float = def.get("width", 1.0)
			_mi(r, cyl_mesh(0.07, 0.07, 0.02, 12), Vector3(0, -0.05, -0.64), glow_mat(lc, 4.0), Vector3(PI * 0.5, 0, 0))
			var beam := _node(r, "beam", Vector3(0, -0.05, -0.65))
			_mi(beam, cyl_mesh(0.06 * bw, 0.06 * bw, 1.0, 8), Vector3(0, 0, -0.5), glow_mat(lc, 6.0, true), Vector3(PI * 0.5, 0, 0))
			_mi(beam, cyl_mesh(0.025 * bw, 0.025 * bw, 1.0, 6), Vector3(0, 0, -0.5), glow_mat(lc.lerp(Color.WHITE, 0.85), 8.0, true), Vector3(PI * 0.5, 0, 0))
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
			if def.id == "turret":
				for x in [-0.13, 0.13]:
					_mi(pt, cyl_mesh(0.05, 0.05, 0.9, 8), Vector3(x, 0, -0.6), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			elif def.has("proj"):
				_mi(pt, cyl_mesh(0.09, 0.1, 1.1, 12), Vector3(0, 0, -0.7), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
				_mi(pt, cyl_mesh(0.13, 0.13, 0.18, 12), Vector3(0, 0, -1.2), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
			else:
				var tc := Color(def.get("tcol", "#ff5ec4"))
				_mi(pt, cyl_mesh(0.06, 0.08, 0.8, 10), Vector3(0, 0, -0.55), mat(DARK, 0.8, 0.3), Vector3(PI * 0.5, 0, 0))
				_mi(pt, sphere_mesh(0.07), Vector3(0, 0, -0.97), glow_mat(tc, 4.0))
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
			_particles(r, "particles", Vector3(0, -0.1, 0.6), Vector3(0, 0, 1), col, def.get("fire", false))
		"light":
			_mi(r, box_mesh(Vector3(0.7, 0.45, 0.4)), Vector3(0, -0.1, 0.12), mat(col, 0.4, 0.4))
			_mi(r, cyl_mesh(0.22, 0.24, 0.12, 16), Vector3(0, -0.1, -0.12), mat(STEEL, 0.9, 0.2), Vector3(PI * 0.5, 0, 0))
			var lens := _mi(r, cyl_mesh(0.19, 0.19, 0.02, 16), Vector3(0, -0.1, -0.19), glow_mat(Color("#fff3c4"), 4.0), Vector3(PI * 0.5, 0, 0))
			lens.name = "lens"
			var sl := SpotLight3D.new()
			sl.name = "lamp"
			sl.position = Vector3(0, -0.1, -0.3)
			sl.spot_range = def.get("range", 45.0)
			sl.spot_angle = def.get("angle", 28.0)
			sl.light_energy = def.get("energy", 6.0)
			sl.light_color = Color("#fff3d1")
			sl.visible = false
			r.add_child(sl)
		"horn":
			_mi(r, box_mesh(Vector3(0.5, 0.4, 0.4)), Vector3(0, -0.25, 0.25), mat(DARK, 0.3, 0.5))
			_mi(r, cyl_mesh(0.32, 0.07, 0.75, 16), Vector3(0, -0.05, -0.2), mat(col, 0.9, 0.2), Vector3(-PI * 0.5, 0, 0))
		_:
			_mi(r, box_mesh(Vector3.ONE * 0.9), Vector3.ZERO, mat(col))


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
	if kind == "wheel":
		# small sphere in the hub: the raycast suspension carries the wheel
		var rad: float = defs[id].radius
		kind = "wheel%.2f" % rad
		if not _shapes.has(kind):
			var s := SphereShape3D.new()
			s.radius = rad * 0.58
			_shapes[kind] = [s, Transform3D.IDENTITY]
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
			"lid":
				var b := BoxShape3D.new()
				b.size = Vector3(1, 0.12, 1)
				_shapes[kind] = [b, Transform3D(Basis.IDENTITY, Vector3(0, 0.44, 0))]
			"half":
				var b := BoxShape3D.new()
				b.size = Vector3(1, 0.5, 1)
				_shapes[kind] = [b, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0))]
			"beam":
				var b := BoxShape3D.new()
				b.size = Vector3(0.34, 1, 0.34)
				_shapes[kind] = [b, Transform3D.IDENTITY]
			"cyl":
				var c := CylinderShape3D.new()
				c.radius = 0.5
				c.height = 1.0
				_shapes[kind] = [c, Transform3D.IDENTITY]
			"ball":
				var c := SphereShape3D.new()
				c.radius = 0.5
				_shapes[kind] = [c, Transform3D.IDENTITY]
			"corner", "inner", "lowwedge", "pyramid":
				var c := ConvexPolygonShape3D.new()
				c.points = PackedVector3Array(POLYS[kind][0])
				_shapes[kind] = [c, Transform3D.IDENTITY]
			_:
				var b := BoxShape3D.new()
				b.size = Vector3.ONE
				_shapes[kind] = [b, Transform3D.IDENTITY]
	return _shapes[kind]


## Like shape_for, but stretched to `size`. Non-box shapes become convex hulls,
## since Godot colliders don't take non-uniform scale.
func shape_scaled(id: String, size: Vector3) -> Array:
	var base := shape_for(id)
	if size.is_equal_approx(Vector3.ONE):
		return base
	var key := "%s_%.3f_%.3f_%.3f" % [defs[id].shape, size.x, size.y, size.z]
	if _shapes.has(key):
		return _shapes[key]
	var src: Shape3D = base[0]
	var tr: Transform3D = base[1]
	var shp: Shape3D
	if src is BoxShape3D:
		var b := BoxShape3D.new()
		b.size = (src as BoxShape3D).size * size
		shp = b
	else:
		var pts := PackedVector3Array()
		if src is ConvexPolygonShape3D:
			pts = (src as ConvexPolygonShape3D).points
		elif src is CylinderShape3D:
			for i in 16:
				var a := i * TAU / 16.0
				pts.append(Vector3(cos(a) * 0.5, -0.5, sin(a) * 0.5))
				pts.append(Vector3(cos(a) * 0.5, 0.5, sin(a) * 0.5))
		else:
			for la in range(-3, 4):
				var y := sin(la * PI / 8.0) * 0.5
				var rr := cos(la * PI / 8.0) * 0.5
				for i in 12:
					var a := i * TAU / 12.0
					pts.append(Vector3(cos(a) * rr, y, sin(a) * rr))
			pts.append(Vector3(0, 0.5, 0))
			pts.append(Vector3(0, -0.5, 0))
		var scaled := PackedVector3Array()
		for p in pts:
			scaled.append(p * size)
		var c := ConvexPolygonShape3D.new()
		c.points = scaled
		shp = c
	_shapes[key] = [shp, Transform3D(tr.basis, tr.origin * size)]
	return _shapes[key]


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
	var def: Dictionary = defs[id]
	if def.kind == "wheel":
		v.rotation = Vector3(0, PI * 0.5, 0)
	var cam := Camera3D.new()
	var ext: float = def.get("icon_ext", 1.0)
	cam.fov = 34
	var dir := Vector3(1.0, 0.8, 1.15).normalized()
	var focus: Vector3 = def.get("icon_focus", Vector3.ZERO)
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
