extends RefCounted
## Procedural models for the extended block set. `build` returns false when it
## does not know `vis`, so blocks.gd falls back to its own models.

const DARK := Color("#2b2f36")
const STEEL := Color("#8b949e")
const RUBBER := Color("#1d1f23")
const YEL := Color("#ffcc00")
const RX := Vector3(PI * 0.5, 0, 0)    # cylinder along Z
const RZ := Vector3(0, 0, PI * 0.5)    # cylinder along X


static func _mi(p: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Blocks._mi(p, mesh, pos, m, rot)


static func _box(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Blocks._mi(p, Blocks.box_mesh(size), pos, m, rot)


static func _cyl(p: Node3D, rt: float, rb: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	return Blocks._mi(p, Blocks.cyl_mesh(rt, rb, h, segs), pos, m, rot)


static func _m(c: Color, metal := 0.15, rough := 0.6) -> Material:
	return Blocks.mat(c, metal, rough)


static func _glow(c: Color, e := 3.0, add := false) -> Material:
	return Blocks.glow_mat(c, e, add)


## Yellow/black stripes marking the face that a mechanism moves.
static func _stripes(p: Node3D, y: float, w := 0.86) -> void:
	_box(p, Vector3(w, 0.03, w), Vector3(0, y, 0), _m(YEL, 0.2, 0.5))
	for i in 3:
		_box(p, Vector3(0.1, 0.035, w + 0.005), Vector3(-0.27 + i * 0.27, y, 0), _m(DARK, 0.2, 0.5), Vector3(0, 0.6, 0))


## Node whose local Y is the mechanism output direction and local X its hinge axis.
static func mech_frame(def: Dictionary) -> Basis:
	var out: Vector3 = def.get("out", Vector3.UP)
	var ax: Vector3 = def.get("axis", Vector3.RIGHT)
	if absf(ax.dot(out)) > 0.9:
		ax = Vector3.RIGHT if absf(out.x) < 0.9 else Vector3.UP
	return Basis(ax, out, ax.cross(out))


static func _frame(r: Node3D, def: Dictionary) -> Node3D:
	var f := Node3D.new()
	f.name = "frame"
	f.basis = mech_frame(def)
	r.add_child(f)
	return f


static func _flame(p: Node3D, nm: String, pos: Vector3, radius: float, col: Color, twin := 0.0) -> Node3D:
	var f := Blocks._node(p, nm, pos)
	for x in ([-twin, twin] if twin > 0.0 else [0.0]):
		_cyl(f, 0.02, radius, 1.0, Vector3(x, 0, 0.5), _glow(col, 4.0, true), RX, 12)
		_cyl(f, 0.01, radius * 0.5, 0.7, Vector3(x, 0, 0.35), _glow(Color(1, 1, 0.85), 6.0, true), RX, 10)
	f.scale = Vector3(1, 1, 0.001)
	f.visible = false
	return f


static func _omni(p: Node3D, nm: String, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = nm
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.visible = false
	p.add_child(l)
	return l


static func build(r: Node3D, def: Dictionary, col: Color) -> bool:
	match def.vis:
		"solid":
			_solid(r, def, col)
		"passenger":
			_box(r, Vector3(0.9, 0.35, 0.9), Vector3(0, -0.32, 0), _m(col, 0.1, 0.5))
			_box(r, Vector3(0.8, 0.7, 0.16), Vector3(0, 0.2, 0.36), _m(DARK, 0.1, 0.7))
			_box(r, Vector3(0.34, 0.32, 0.22), Vector3(0, 0.0, 0.16), _m(Color("#ffcc80"), 0.3, 0.4))
			Blocks._mi(r, Blocks.sphere_mesh(0.17), Vector3(0, 0.3, 0.14), _m(Color("#fff3e0"), 0.3, 0.3))
			_box(r, Vector3(0.26, 0.08, 0.05), Vector3(0, 0.32, -0.02), _glow(Color("#ff9a1f"), 2.5))
		"canopy":
			var g := _m(Color(col.r, col.g, col.b, 0.35), 0.2, 0.05)
			var d := Blocks._mi(r, Blocks.sphere_mesh(0.48, true), Vector3(0, -0.5, 0), g)
			d.scale = Vector3(1, 1.9, 1)
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(r, Vector3(0.08, 0.06, 0.96), Vector3(0, 0.42, 0), _m(DARK, 0.4, 0.5))
			Blocks._mi(r, Blocks.torus_mesh(0.44, 0.5), Vector3(0, -0.47, 0), _m(DARK, 0.4, 0.5))
		"track":
			var sp := Blocks._node(r, "spin")
			for z in [-0.55, 0.0, 0.55]:
				_cyl(sp, 0.32, 0.32, 0.5, Vector3(0, 0, z), _m(STEEL, 0.6, 0.4), RZ, 12)
			_box(r, Vector3(0.6, 0.1, 1.4), Vector3(0, 0.45, 0), _m(RUBBER, 0, 1))
			_box(r, Vector3(0.6, 0.1, 1.4), Vector3(0, -0.45, 0), _m(RUBBER, 0, 1))
			for z in [-0.72, 0.72]:
				_cyl(r, 0.5, 0.5, 0.6, Vector3(0, 0, z), _m(RUBBER, 0, 1), RZ, 16)
			for z in 7:
				_box(r, Vector3(0.62, 0.05, 0.08), Vector3(0, -0.51, -0.6 + z * 0.2), _m(STEEL, 0.6, 0.5))
			_box(r, Vector3(0.08, 0.7, 1.3), Vector3(0.33, 0, 0), _m(col, 0.4, 0.5))
			_box(r, Vector3(0.08, 0.7, 1.3), Vector3(-0.33, 0, 0), _m(col, 0.4, 0.5))
		"ski":
			Blocks._node(r, "spin")
			_box(r, Vector3(0.36, 0.06, 1.3), Vector3(0, -0.17, 0.05), _m(col, 0.2, 0.3))
			_box(r, Vector3(0.36, 0.06, 0.3), Vector3(0, -0.07, -0.68), _m(col, 0.2, 0.3), Vector3(0.6, 0, 0))
			_box(r, Vector3(0.12, 0.5, 0.12), Vector3(0, 0.1, 0), _m(STEEL, 0.7, 0.3))
			_box(r, Vector3(0.6, 0.12, 0.4), Vector3(0, 0.38, 0), _m(DARK, 0.3, 0.5))
		"piston":
			_piston(_frame(r, def), def, col)
		"hinge":
			_hinge(_frame(r, def), def, col)
		"rotator":
			_rotator(_frame(r, def), def, col)
		"susp":
			_susp(_frame(r, def), def, col)
		"decoupler":
			_decoupler(r, col)
		"motor":
			_motor(r, def, col)
		# ------------------------------------------------ propulsion
		"ion":
			var gc := Color(def.get("glow", "#5fd0ff"))
			_cyl(r, 0.34, 0.4, 0.8, Vector3(0, 0, 0), _m(col.darkened(0.5), 0.7, 0.3), RX, 20)
			Blocks._mi(r, Blocks.torus_mesh(0.3, 0.42), Vector3(0, 0, 0.42), _glow(gc, 3.0), RX)
			_cyl(r, 0.27, 0.27, 0.02, Vector3(0, 0, 0.42), _glow(gc, 5.0), RX)
			Blocks._mi(r, Blocks.sphere_mesh(0.34), Vector3(0, 0, -0.4), _m(col.darkened(0.5), 0.7, 0.3))
			for i in 3:
				Blocks._mi(r, Blocks.torus_mesh(0.38, 0.42), Vector3(0, 0, -0.2 + i * 0.2), _m(gc.darkened(0.2), 0.6, 0.3), RX)
			_flame(r, "flame", Vector3(0, 0, 0.44), 0.26, gc)
		"ramjet":
			_cyl(r, 0.18, 0.42, 0.45, Vector3(0, 0, -0.32), _m(col, 0.8, 0.25), Vector3(-PI * 0.5, 0, 0), 20)
			_cyl(r, 0.08, 0.08, 0.5, Vector3(0, 0, -0.5), _m(DARK, 0.7, 0.3), RX, 10)
			_cyl(r, 0.42, 0.34, 0.6, Vector3(0, 0, 0.18), _m(col, 0.8, 0.25), RX, 20)
			_cyl(r, 0.28, 0.28, 0.02, Vector3(0, 0, 0.49), _glow(Color("#ff6a2a"), 3.0), RX)
			_flame(r, "flame", Vector3(0, 0, 0.5), 0.3, Color("#ff7a2a"))
		"pulsejet":
			_cyl(r, 0.14, 0.14, 1.0, Vector3(0, 0.1, 0.05), _m(col, 0.6, 0.4), RX, 12)
			Blocks._mi(r, Blocks.sphere_mesh(0.3), Vector3(0, 0.1, -0.3), _m(col, 0.6, 0.4))
			_cyl(r, 0.24, 0.2, 0.12, Vector3(0, 0.1, -0.52), _m(DARK, 0.6, 0.4), RX, 14)
			_box(r, Vector3(0.12, 0.3, 0.5), Vector3(0, -0.25, 0), _m(DARK, 0.4, 0.5))
			_flame(r, "flame", Vector3(0, 0.1, 0.55), 0.16, Color("#ffb03a"))
		"twinjet":
			_box(r, Vector3(0.95, 0.3, 0.8), Vector3(0, 0.2, 0), _m(col.darkened(0.2), 0.6, 0.35))
			for x in [-0.25, 0.25]:
				_cyl(r, 0.24, 0.22, 0.95, Vector3(x, -0.05, 0), _m(col, 0.7, 0.3), RX, 16)
				Blocks._mi(r, Blocks.torus_mesh(0.18, 0.25), Vector3(x, -0.05, -0.47), _m(STEEL, 0.8, 0.25), RX)
				_cyl(r, 0.16, 0.16, 0.02, Vector3(x, -0.05, 0.48), _glow(Color("#ff6a2a"), 3.0), RX)
			_flame(r, "flame", Vector3(0, -0.05, 0.5), 0.18, Color("#ff7a2a"), 0.25)
		"srb":
			_cyl(r, 0.36, 0.36, 1.0, Vector3(0, 0, 0), _m(col, 0.2, 0.45), RX, 18)
			_cyl(r, 0.0, 0.36, 0.45, Vector3(0, 0, -0.72), _m(col, 0.2, 0.45), Vector3(-PI * 0.5, 0, 0), 18)
			for z in [-0.3, 0.2]:
				_cyl(r, 0.37, 0.37, 0.07, Vector3(0, 0, z), _m(DARK, 0.3, 0.5), RX, 18)
			_cyl(r, 0.24, 0.32, 0.25, Vector3(0, 0, 0.6), _m(DARK, 0.8, 0.4), RX, 14)
			_flame(r, "flame", Vector3(0, 0, 0.72), 0.34, Color("#ffcf6a"))
		"coax":
			_cyl(r, 0.28, 0.33, 0.7, Vector3(0, 0, 0.12), _m(col.darkened(0.3), 0.5, 0.4), RX, 16)
			var sp := Blocks._node(r, "spin", Vector3(0, 0, -0.3))
			_cyl(sp, 0.0, 0.17, 0.3, Vector3(0, 0, -0.18), _m(col, 0.4, 0.4), Vector3(-PI * 0.5, 0, 0), 14)
			for k in 2:
				for i in 3:
					var b := Blocks._node(sp, "b%d%d" % [k, i])
					b.rotation.z = i * TAU / 3.0 + k * PI / 3.0
					b.position.z = k * 0.14
					_box(b, Vector3(0.13, 0.9, 0.04), Vector3(0, 0.52, 0), _m(Color("#f2f2f2") if k == 0 else col, 0.2, 0.5), Vector3(0, 0.35 * (1 - 2 * k), 0))
		"ducted":
			Blocks._mi(r, Blocks.torus_mesh(0.4, 0.5), Vector3(0, 0, 0), _m(col, 0.4, 0.4), RX)
			_cyl(r, 0.5, 0.5, 0.5, Vector3(0, 0, 0), _m(col.darkened(0.3), 0.4, 0.4), RX, 24)
			_cyl(r, 0.46, 0.46, 0.52, Vector3(0, 0, 0), _m(DARK, 0.2, 0.8), RX, 24)
			var sp := Blocks._node(r, "spin", Vector3(0, 0, -0.1))
			_cyl(sp, 0.1, 0.1, 0.3, Vector3.ZERO, _m(STEEL, 0.7, 0.3), RX, 10)
			for i in 5:
				var b := Blocks._node(sp, "b%d" % i)
				b.rotation.z = i * TAU / 5.0
				_box(b, Vector3(0.12, 0.38, 0.03), Vector3(0, 0.24, 0), _m(Color("#f2f2f2"), 0.3, 0.4), Vector3(0, 0.5, 0))
		"vtol":
			_box(r, Vector3(0.95, 0.3, 0.95), Vector3(0, 0.32, 0), _m(col, 0.4, 0.45))
			Blocks._mi(r, Blocks.torus_mesh(0.38, 0.47), Vector3(0, -0.1, 0), _m(col.darkened(0.3), 0.5, 0.4))
			var sp := Blocks._node(r, "spin", Vector3(0, -0.05, 0))
			sp.rotation.x = -PI * 0.5
			for i in 6:
				var b := Blocks._node(sp, "b%d" % i)
				b.rotation.z = i * TAU / 6.0
				_box(b, Vector3(0.1, 0.34, 0.03), Vector3(0, 0.2, 0), _m(Color("#c0c6ce"), 0.8, 0.25), Vector3(0, 0.5, 0))
			for i in 4:
				_box(r, Vector3(0.9, 0.03, 0.04), Vector3(0, -0.42, -0.3 + i * 0.2), _m(DARK, 0.5, 0.4))
		"hover":
			_cyl(r, 0.46, 0.48, 0.22, Vector3(0, -0.3, 0), _m(col.darkened(0.4), 0.6, 0.35), Vector3.ZERO, 24)
			_cyl(r, 0.32, 0.4, 0.2, Vector3(0, -0.12, 0), _m(col, 0.5, 0.35), Vector3.ZERO, 20)
			var gl := _cyl(r, 0.4, 0.4, 0.02, Vector3(0, -0.42, 0), _glow(col, 4.0), Vector3.ZERO, 24)
			gl.name = "hglow"
			Blocks._mi(r, Blocks.torus_mesh(0.42, 0.5), Vector3(0, -0.41, 0), _glow(col.lightened(0.3), 2.5))
		"hotair":
			_box(r, Vector3(0.7, 0.4, 0.7), Vector3(0, -0.3, 0), _m(Color("#8a5a2b"), 0.0, 0.9))
			for x in [-0.28, 0.28]:
				for z in [-0.28, 0.28]:
					_cyl(r, 0.015, 0.015, 1.2, Vector3(x, 0.4, z), _m(Color("#dddddd"), 0, 1), Vector3.ZERO, 4)
			var lamp := Blocks._mi(r, Blocks.sphere_mesh(0.14), Vector3(0, 0.95, 0), _glow(Color("#ffb03a"), 6.0, true))
			lamp.name = "led"
			lamp.visible = false
			var env := Blocks._mi(r, Blocks.sphere_mesh(1.25), Vector3(0, 2.4, 0), _m(col, 0.0, 0.5))
			env.scale = Vector3(1, 1.2, 1)
			for i in 6:
				var s := _box(r, Vector3(0.06, 2.6, 0.06), Vector3(0, 2.45, 0), _m(Color("#ffcc00"), 0, 0.6))
				s.position = Vector3(cos(i * TAU / 6.0) * 1.22, 2.4, sin(i * TAU / 6.0) * 1.22)
				s.scale = Vector3(1, 0.85, 1)
			_cyl(r, 0.5, 0.25, 0.4, Vector3(0, 1.15, 0), _m(col.darkened(0.2), 0.0, 0.5))
		"blimp":
			_box(r, Vector3(0.7, 0.2, 0.7), Vector3(0, -0.4, 0), _m(DARK, 0.3, 0.5))
			for z in [-0.25, 0.25]:
				_cyl(r, 0.02, 0.02, 1.0, Vector3(0, 0.1, z), _m(Color("#dddddd"), 0, 1), Vector3.ZERO, 4)
			Blocks._mi(r, Blocks.capsule_mesh(0.95, 3.6), Vector3(0, 1.5, 0), _m(col, 0.1, 0.4), RX)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				var fn := Blocks._node(r, "fin", Vector3(0, 1.5, 1.5))
				fn.rotation.z = a
				_box(fn, Vector3(0.06, 0.7, 0.6), Vector3(0, 0.75, 0), _m(Color("#e53935"), 0.1, 0.5))
		"antigrav":
			for x in [-0.4, 0.4]:
				for z in [-0.4, 0.4]:
					_box(r, Vector3(0.1, 1.0, 0.1), Vector3(x, 0, z), _m(DARK, 0.6, 0.4))
			_box(r, Vector3(1.0, 0.1, 1.0), Vector3(0, -0.45, 0), _m(DARK, 0.6, 0.4))
			_box(r, Vector3(1.0, 0.1, 1.0), Vector3(0, 0.45, 0), _m(DARK, 0.6, 0.4))
			Blocks._mi(r, Blocks.sphere_mesh(0.24), Vector3.ZERO, _glow(col, 5.0))
			var sp := Blocks._node(r, "spin")
			Blocks._mi(sp, Blocks.torus_mesh(0.3, 0.34), Vector3.ZERO, _glow(col.lightened(0.3), 3.0))
			Blocks._mi(sp, Blocks.torus_mesh(0.3, 0.34), Vector3.ZERO, _glow(col.lightened(0.3), 3.0), RX)
		# ------------------------------------------------ flight
		"wing2":
			_wing(r, def, col)
		"spoiler":
			_box(r, Vector3(1.0, 0.08, 0.5), Vector3(0, 0.35, 0.1), _m(col, 0.2, 0.45), Vector3(-0.15, 0, 0))
			for x in [-0.46, 0.46]:
				_box(r, Vector3(0.05, 0.4, 0.6), Vector3(x, 0.3, 0.1), _m(DARK, 0.3, 0.5))
			for x in [-0.25, 0.25]:
				_box(r, Vector3(0.06, 0.8, 0.12), Vector3(x, -0.1, 0.1), _m(DARK, 0.5, 0.4))
		"splitter":
			_box(r, Vector3(1.0, 0.06, 1.0), Vector3(0, -0.47, 0), _m(col, 0.3, 0.45))
			_box(r, Vector3(1.0, 0.1, 0.08), Vector3(0, -0.42, -0.48), _m(Color("#e53935"), 0.3, 0.45))
		"airbrake":
			_box(r, Vector3(0.9, 0.18, 0.9), Vector3(0, -0.41, 0), _m(DARK, 0.4, 0.5))
			var fl := Blocks._node(r, "flap", Vector3(0, -0.32, 0.4))
			_box(fl, Vector3(0.86, 0.06, 0.8), Vector3(0, 0, -0.4), _m(col, 0.3, 0.45))
			for x in [-0.25, 0.0, 0.25]:
				_box(fl, Vector3(0.12, 0.065, 0.12), Vector3(x, 0, -0.45), _m(DARK, 0.3, 0.5))
		# ------------------------------------------------ water
		"bigfloat":
			Blocks._mi(r, Blocks.capsule_mesh(0.48, 1.0), Vector3(-0.0, 0, 0), _m(col, 0.0, 0.5), RX)
			_box(r, Vector3(0.94, 0.94, 0.7), Vector3.ZERO, _m(col, 0.0, 0.5))
			for z in [-0.25, 0.25]:
				Blocks._mi(r, Blocks.torus_mesh(0.44, 0.5), Vector3(0, 0, z), _m(Color("#f4f4f4"), 0.0, 0.6), RX)
		"pontoon":
			Blocks._mi(r, Blocks.capsule_mesh(0.42, 1.0), Vector3(0, -0.05, 0), _m(col, 0.3, 0.35), RX)
			_box(r, Vector3(0.1, 0.4, 0.8), Vector3(0, 0.3, 0), _m(DARK, 0.4, 0.5))
			_box(r, Vector3(0.86, 0.05, 1.0), Vector3(0, -0.05, 0), _m(Color("#e53935"), 0.2, 0.5))
		"tube":
			Blocks._mi(r, Blocks.torus_mesh(0.18, 0.5), Vector3.ZERO, _m(col, 0.0, 0.35))
			for i in 4:
				var a := i * TAU / 4.0
				_box(r, Vector3(0.12, 0.3, 0.12), Vector3(cos(a) * 0.34, 0, sin(a) * 0.34), _m(Color("#e53935"), 0.0, 0.4), Vector3(0, -a, 0))
		"keel":
			_box(r, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.44, 0), _m(DARK, 0.4, 0.5))
			_box(r, Vector3(0.1, 0.85, 0.9), Vector3(0, 0.0, 0), _m(col, 0.5, 0.4))
			Blocks._mi(r, Blocks.capsule_mesh(0.12, 0.8), Vector3(0, -0.42, 0.05), _m(DARK, 0.7, 0.3), RX)
		"waterrudder":
			_box(r, Vector3(0.5, 0.2, 0.5), Vector3(0, 0.4, 0), _m(DARK, 0.4, 0.5))
			_cyl(r, 0.05, 0.05, 0.9, Vector3(0, 0.0, -0.1), _m(STEEL, 0.8, 0.3))
			var fl := Blocks._node(r, "flap", Vector3(0, -0.1, -0.1))
			_box(fl, Vector3(0.08, 0.7, 0.6), Vector3(0, 0, 0.3), _m(col, 0.3, 0.45))
		"hydrofoil":
			_box(r, Vector3(0.5, 0.15, 0.5), Vector3(0, 0.42, 0), _m(DARK, 0.4, 0.5))
			_box(r, Vector3(0.08, 0.8, 0.3), Vector3(0, 0.0, 0), _m(STEEL, 0.7, 0.3))
			_box(r, Vector3(1.0, 0.06, 0.6), Vector3(0, -0.42, 0), _m(col, 0.4, 0.35))
			_cyl(r, 0.05, 0.05, 1.0, Vector3(0, -0.42, -0.3), _m(col, 0.4, 0.35), RZ, 8)
		"jetdrive":
			_box(r, Vector3(0.7, 0.6, 0.8), Vector3(0, 0.1, -0.05), _m(col, 0.5, 0.4))
			_cyl(r, 0.18, 0.26, 0.4, Vector3(0, -0.05, 0.45), _m(DARK, 0.7, 0.3), RX, 14)
			_box(r, Vector3(0.6, 0.12, 0.3), Vector3(0, -0.35, -0.35), _m(DARK, 0.5, 0.4))
			var sp := Blocks._node(r, "spin", Vector3(0, -0.05, 0.5))
			for i in 3:
				var b := Blocks._node(sp, "b%d" % i)
				b.rotation.z = i * TAU / 3.0
				_box(b, Vector3(0.06, 0.16, 0.03), Vector3(0, 0.08, 0), _m(STEEL, 0.8, 0.3))
		"paddle":
			var sp := Blocks._node(r, "spin")
			_cyl(sp, 0.12, 0.12, 0.9, Vector3.ZERO, _m(STEEL, 0.8, 0.3), RZ, 10)
			for x in [-0.4, 0.4]:
				Blocks._mi(sp, Blocks.torus_mesh(0.42, 0.48), Vector3(x, 0, 0), _m(Color("#e53935"), 0.2, 0.6), Vector3(0, 0, PI * 0.5))
			for i in 6:
				var b := Blocks._node(sp, "b%d" % i)
				b.rotation.x = i * TAU / 6.0
				_box(b, Vector3(0.8, 0.04, 0.22), Vector3(0, 0.0, -0.36), _m(col, 0.0, 0.85))
		"ballast":
			Blocks._mi(r, Blocks.capsule_mesh(0.42, 1.0), Vector3.ZERO, _m(col, 0.5, 0.4), RX)
			for z in [-0.25, 0.25]:
				Blocks._mi(r, Blocks.torus_mesh(0.4, 0.45), Vector3(0, 0, z), _m(DARK, 0.6, 0.4), RX)
			_cyl(r, 0.06, 0.06, 0.25, Vector3(0, 0.45, 0), _m(STEEL, 0.8, 0.3))
			var led := Blocks._mi(r, Blocks.sphere_mesh(0.07), Vector3(0, 0.58, 0), _glow(Color("#3ddc84"), 4.0))
			led.name = "led"
		"outboard":
			var y := Blocks._node(r, "yaw")
			_box(y, Vector3(0.5, 0.5, 0.6), Vector3(0, 0.25, 0.05), _m(col, 0.4, 0.4))
			_box(y, Vector3(0.52, 0.1, 0.62), Vector3(0, 0.45, 0.05), _m(Color("#e53935"), 0.4, 0.4))
			_box(y, Vector3(0.14, 0.7, 0.2), Vector3(0, -0.3, 0.1), _m(DARK, 0.5, 0.4))
			_cyl(y, 0.08, 0.08, 0.3, Vector3(0, -0.55, 0.1), _m(DARK, 0.6, 0.4), RX, 10)
			var sp := Blocks._node(y, "spin", Vector3(0, -0.55, 0.3))
			for i in 3:
				var b := Blocks._node(sp, "b%d" % i)
				b.rotation.z = i * TAU / 3.0
				_box(b, Vector3(0.12, 0.2, 0.03), Vector3(0, 0.1, 0), _m(Color("#d4a542"), 0.9, 0.25), Vector3(0, 0.6, 0))
		"anchor":
			_box(r, Vector3(0.6, 0.2, 0.6), Vector3(0, 0.4, 0), _m(DARK, 0.4, 0.5))
			var an := Blocks._node(r, "bomb")
			_cyl(an, 0.06, 0.06, 0.7, Vector3(0, 0.0, 0), _m(col, 0.7, 0.4))
			Blocks._mi(an, Blocks.torus_mesh(0.07, 0.13), Vector3(0, 0.36, 0), _m(col, 0.7, 0.4), RX)
			_box(an, Vector3(0.6, 0.08, 0.08), Vector3(0, 0.22, 0), _m(col, 0.7, 0.4))
			Blocks._mi(an, Blocks.torus_mesh(0.3, 0.38), Vector3(0, -0.15, 0), _m(col, 0.7, 0.4), RX).scale = Vector3(1, 1, 0.6)
			var chain := Blocks._node(r, "beam", Vector3(0, 0.3, 0))
			_cyl(chain, 0.03, 0.03, 1.0, Vector3(0, -0.5, 0), _m(STEEL, 0.8, 0.4), Vector3.ZERO, 6)
			chain.visible = false
		# ------------------------------------------------ weapons
		"gun":
			gun(r, def, col)
		"railgun":
			_box(r, Vector3(0.5, 0.4, 0.8), Vector3(0, -0.1, 0.15), _m(col, 0.6, 0.35))
			for x in [-0.14, 0.14]:
				_box(r, Vector3(0.08, 0.2, 1.5), Vector3(x, -0.05, -0.6), _m(STEEL, 0.9, 0.2))
			for i in 4:
				Blocks._mi(r, Blocks.torus_mesh(0.18, 0.24), Vector3(0, -0.05, -0.2 - i * 0.28), _glow(Color(def.get("tcol", "#39e1ff")), 2.5), RX)
			var led := Blocks._mi(r, Blocks.sphere_mesh(0.08), Vector3(0, 0.15, 0.3), _glow(Color(def.get("tcol", "#39e1ff")), 5.0))
			led.name = "led"
		"mortar":
			_box(r, Vector3(0.9, 0.15, 0.9), Vector3(0, -0.42, 0), _m(DARK, 0.4, 0.5))
			_cyl(r, 0.2, 0.22, 0.9, Vector3(0, 0.0, -0.1), _m(col, 0.5, 0.4), Vector3(-PI * 0.25, 0, 0), 14)
			_box(r, Vector3(0.08, 0.6, 0.08), Vector3(0.2, -0.15, 0.2), _m(STEEL, 0.7, 0.3), Vector3(0.4, 0, 0))
			_box(r, Vector3(0.08, 0.6, 0.08), Vector3(-0.2, -0.15, 0.2), _m(STEEL, 0.7, 0.3), Vector3(0.4, 0, 0))
		"missile":
			_box(r, Vector3(0.9, 0.2, 1.0), Vector3(0, -0.4, 0), _m(DARK, 0.5, 0.4))
			var ms := Blocks._node(r, "bomb", Vector3(0, -0.05, 0))
			_cyl(ms, 0.17, 0.17, 0.9, Vector3.ZERO, _m(col, 0.3, 0.4), RX, 14)
			_cyl(ms, 0.0, 0.17, 0.3, Vector3(0, 0, -0.6), _m(Color("#e53935"), 0.3, 0.4), Vector3(-PI * 0.5, 0, 0), 14)
			for i in 4:
				var fn := Blocks._node(ms, "f%d" % i)
				fn.rotation.z = i * TAU / 4.0 + PI / 4.0
				_box(fn, Vector3(0.03, 0.22, 0.25), Vector3(0, 0.22, 0.3), _m(DARK, 0.3, 0.5))
		"torpedo":
			_cyl(r, 0.3, 0.3, 1.0, Vector3(0, -0.05, 0), _m(col, 0.6, 0.35), RX, 16)
			_cyl(r, 0.22, 0.22, 0.04, Vector3(0, -0.05, -0.5), _m(DARK, 0.6, 0.35), RX, 16)
			var tp := Blocks._node(r, "bomb", Vector3(0, -0.05, -0.47))
			Blocks._mi(tp, Blocks.sphere_mesh(0.2), Vector3.ZERO, _m(Color("#ffcc00"), 0.4, 0.4))
			_box(r, Vector3(0.3, 0.2, 0.6), Vector3(0, 0.3, 0.1), _m(DARK, 0.5, 0.4))
		"plasmacannon":
			var gc := Color(def.get("glow", "#c05cff"))
			_box(r, Vector3(0.5, 0.45, 0.7), Vector3(0, -0.08, 0.15), _m(DARK, 0.6, 0.35))
			_cyl(r, 0.1, 0.13, 0.8, Vector3(0, -0.05, -0.5), _m(col.darkened(0.3), 0.7, 0.3), RX, 12)
			Blocks._mi(r, Blocks.sphere_mesh(0.18), Vector3(0, 0.2, 0.15), _glow(gc, 4.0))
			for i in 3:
				Blocks._mi(r, Blocks.torus_mesh(0.12, 0.17), Vector3(0, -0.05, -0.3 - i * 0.2), _glow(gc, 2.5), RX)
		"grenade":
			_cyl(r, 0.3, 0.3, 0.35, Vector3(0, -0.1, 0.15), _m(col, 0.4, 0.5), RX, 12)
			_cyl(r, 0.09, 0.09, 0.8, Vector3(0, -0.05, -0.4), _m(DARK, 0.7, 0.3), RX, 10)
			_box(r, Vector3(0.12, 0.3, 0.3), Vector3(0, -0.35, 0.3), _m(DARK, 0.4, 0.5))
		"mines":
			_box(r, Vector3(0.9, 0.6, 0.9), Vector3(0, 0.1, 0), _m(col, 0.4, 0.5))
			var mn := Blocks._node(r, "bomb", Vector3(0, -0.32, 0))
			_cyl(mn, 0.3, 0.32, 0.14, Vector3.ZERO, _m(Color("#5c6b4a"), 0.4, 0.5))
			Blocks._mi(mn, Blocks.sphere_mesh(0.05), Vector3(0, 0.08, 0), _glow(Color("#ff2020"), 4.0))
		"firework":
			_box(r, Vector3(0.8, 0.2, 0.8), Vector3(0, -0.4, 0), _m(DARK, 0.3, 0.6))
			var cols := [Color("#e53935"), Color("#3fa9ff"), Color("#ffcc00"), Color("#3ddc84")]
			for i in 4:
				var x := -0.2 + (i % 2) * 0.4
				var z := -0.2 + (i / 2) * 0.4
				_cyl(r, 0.1, 0.1, 0.7, Vector3(x, 0.0, z), _m(cols[i], 0.2, 0.5), Vector3(-0.35, 0, 0), 10)
				_cyl(r, 0.0, 0.1, 0.16, Vector3(x, 0.36, z - 0.13), _m(cols[(i + 1) % 4], 0.2, 0.5), Vector3(-0.35, 0, 0), 10)
		"tesla":
			_cyl(r, 0.42, 0.45, 0.2, Vector3(0, -0.4, 0), _m(DARK, 0.6, 0.4), Vector3.ZERO, 18)
			_cyl(r, 0.14, 0.18, 0.7, Vector3(0, -0.0, 0), _m(Color("#b87333"), 0.9, 0.3), Vector3.ZERO, 14)
			for i in 3:
				Blocks._mi(r, Blocks.torus_mesh(0.18, 0.26 - i * 0.03), Vector3(0, -0.2 + i * 0.18, 0), _m(STEEL, 0.9, 0.2))
			var orb := Blocks._mi(r, Blocks.sphere_mesh(0.2), Vector3(0, 0.4, 0), _glow(Color("#9fd8ff"), 4.0))
			orb.name = "led"
		"watercannon":
			_cyl(r, 0.3, 0.3, 0.6, Vector3(0, -0.1, 0.2), _m(col, 0.4, 0.4), RX, 14)
			_cyl(r, 0.06, 0.12, 0.6, Vector3(0, -0.05, -0.4), _m(STEEL, 0.8, 0.3), RX, 10)
			_box(r, Vector3(0.12, 0.3, 0.3), Vector3(0, 0.3, 0.2), _m(DARK, 0.4, 0.5))
			var pt := Blocks._particles(r, "particles", Vector3(0, -0.05, -0.7), Vector3(0, 0, -1), Color(0.75, 0.9, 1.0), false)
			var pm := pt.process_material as ParticleProcessMaterial
			pm.initial_velocity_min = 30.0
			pm.initial_velocity_max = 38.0
			pm.gravity = Vector3(0, -9.8, 0)
			pm.spread = 3.0
			pt.lifetime = 0.9
			pt.amount = 80
		"confetti":
			_cyl(r, 0.1, 0.3, 0.8, Vector3(0, 0, -0.1), _m(col, 0.2, 0.5), Vector3(-PI * 0.5, 0, 0), 14)
			for i in 5:
				Blocks._mi(r, Blocks.torus_mesh(0.15 + i * 0.03, 0.18 + i * 0.03), Vector3(0, 0, 0.25 - i * 0.15), _m(Color.from_hsv(i * 0.2, 0.8, 1.0), 0.2, 0.5), RX)
		"ramspike":
			_box(r, Vector3(0.95, 0.95, 0.2), Vector3(0, 0, 0.38), _m(DARK, 0.6, 0.4))
			for p in [Vector3(0, 0, 0), Vector3(-0.28, -0.28, 0), Vector3(0.28, -0.28, 0), Vector3(-0.28, 0.28, 0), Vector3(0.28, 0.28, 0)]:
				_cyl(r, 0.0, 0.14, 0.7, p + Vector3(0, 0, -0.05), _m(col, 0.9, 0.2), Vector3(-PI * 0.5, 0, 0), 10)
		"saw":
			_box(r, Vector3(0.4, 0.4, 0.6), Vector3(0, 0, 0.2), _m(DARK, 0.5, 0.4))
			_cyl(r, 0.08, 0.08, 0.5, Vector3(0, 0, -0.3), _m(STEEL, 0.8, 0.3), RZ, 10)
			var sp := Blocks._node(r, "spin", Vector3(0, 0, -0.35))
			sp.rotation.y = PI * 0.5
			_cyl(sp, 0.55, 0.55, 0.04, Vector3.ZERO, _m(col, 0.95, 0.15), RX, 24)
			for i in 12:
				var t := Blocks._node(sp, "t%d" % i)
				t.rotation.z = i * TAU / 12.0
				_box(t, Vector3(0.1, 0.12, 0.04), Vector3(0, 0.58, 0), _m(col.darkened(0.2), 0.95, 0.15), Vector3(0, 0, 0.5))
		"drill":
			_box(r, Vector3(0.7, 0.7, 0.4), Vector3(0, 0, 0.3), _m(DARK, 0.5, 0.4))
			var sp := Blocks._node(r, "spin", Vector3(0, 0, 0.0))
			_cyl(sp, 0.0, 0.36, 0.9, Vector3(0, 0, -0.45), _m(col, 0.7, 0.3), Vector3(-PI * 0.5, 0, 0), 14)
			for i in 4:
				Blocks._mi(sp, Blocks.torus_mesh(0.05, 0.3 - i * 0.07), Vector3(0, 0, -0.15 - i * 0.18), _m(col.darkened(0.3), 0.7, 0.3), Vector3(PI * 0.5 + 0.25, 0, 0))
		# ------------------------------------------------ gadgets
		"grabber":
			_box(r, Vector3(0.8, 0.3, 0.8), Vector3(0, 0.35, 0), _m(DARK, 0.4, 0.5))
			_cyl(r, 0.12, 0.12, 0.3, Vector3(0, 0.1, 0), _m(STEEL, 0.8, 0.3))
			for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
				var fn := Blocks._node(r, "f", Vector3(0, -0.05, 0))
				fn.rotation.y = a
				_box(fn, Vector3(0.1, 0.4, 0.08), Vector3(0, -0.15, -0.25), _m(col, 0.5, 0.4), Vector3(0.4, 0, 0))
				_box(fn, Vector3(0.1, 0.25, 0.08), Vector3(0, -0.4, -0.25), _m(col, 0.5, 0.4), Vector3(-0.3, 0, 0))
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(1.0, 0.85, 0.2, 0.15)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var field := Blocks._mi(r, Blocks.sphere_mesh(0.7), Vector3(0, -0.4, 0), fm)
			field.name = "field"
			field.visible = false
		"brakelight":
			_box(r, Vector3(0.8, 0.3, 0.2), Vector3(0, -0.2, 0.38), _m(col, 0.3, 0.5))
			var lens := _box(r, Vector3(0.7, 0.2, 0.03), Vector3(0, -0.2, 0.49), _m(Color("#5a1010"), 0.2, 0.3))
			lens.name = "lens"
			var led := _box(r, Vector3(0.7, 0.2, 0.035), Vector3(0, -0.2, 0.495), _glow(Color("#ff2020"), 5.0))
			led.name = "led"
			led.visible = false
			_omni(r, "lamp", Vector3(0, -0.2, 0.9), Color("#ff2020"), 2.0, 4.0)
		"underglow":
			_box(r, Vector3(0.9, 0.08, 0.9), Vector3(0, 0.46, 0), _m(DARK, 0.3, 0.5))
			var led := _box(r, Vector3(0.8, 0.04, 0.8), Vector3(0, 0.4, 0), _glow(col, 3.0))
			led.name = "led"
			_omni(r, "lamp", Vector3(0, -0.6, 0), col, 3.0, 6.0)
		"strobe", "beacon":
			_cyl(r, 0.3, 0.32, 0.2, Vector3(0, -0.4, 0), _m(DARK, 0.4, 0.5))
			var dome := Blocks._mi(r, Blocks.sphere_mesh(0.26, true), Vector3(0, -0.3, 0), _m(Color(def.get("lcol", "#ffffff")).darkened(0.5), 0.1, 0.2))
			dome.name = "lens"
			var led := Blocks._mi(r, Blocks.sphere_mesh(0.26, true), Vector3(0, -0.3, 0), _glow(Color(def.get("lcol", "#ffffff")), 6.0))
			led.name = "led"
			led.visible = false
			_omni(r, "lamp", Vector3(0, 0.1, 0), Color(def.get("lcol", "#ffffff")), 4.0, 12.0)
		"siren":
			_box(r, Vector3(0.95, 0.15, 0.4), Vector3(0, -0.42, 0), _m(col, 0.4, 0.5))
			for i in 2:
				var c := Color(def.lcol) if i == 0 else Color(def.lcol2)
				var x := -0.25 if i == 0 else 0.25
				_box(r, Vector3(0.42, 0.2, 0.34), Vector3(x, -0.25, 0), _m(c.darkened(0.6), 0.1, 0.2))
				var led := _box(r, Vector3(0.43, 0.21, 0.35), Vector3(x, -0.25, 0), _glow(c, 6.0))
				led.name = "led" if i == 0 else "led2"
				led.visible = false
				_omni(r, "lamp" if i == 0 else "lamp2", Vector3(x * 2.0, 0.2, 0), c, 4.0, 12.0)
		"clownhorn":
			Blocks._mi(r, Blocks.sphere_mesh(0.24), Vector3(0, 0, 0.25), _m(Color("#e53935"), 0.0, 0.5))
			_cyl(r, 0.3, 0.06, 0.6, Vector3(0, 0, -0.2), _m(Color("#ffcc33"), 0.9, 0.2), Vector3(-PI * 0.5, 0, 0), 16)
			_box(r, Vector3(0.3, 0.2, 0.3), Vector3(0, -0.35, 0.2), _m(DARK, 0.3, 0.5))
		"shield":
			_cyl(r, 0.42, 0.45, 0.25, Vector3(0, -0.38, 0), _m(DARK, 0.6, 0.4), Vector3.ZERO, 20)
			_cyl(r, 0.1, 0.3, 0.3, Vector3(0, -0.1, 0), _m(STEEL, 0.8, 0.3), Vector3.ZERO, 16)
			Blocks._mi(r, Blocks.sphere_mesh(0.16), Vector3(0, 0.15, 0), _glow(col, 4.0))
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(col.r, col.g, col.b, 0.13)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			var field := Blocks._mi(r, Blocks.sphere_mesh(3.2), Vector3.ZERO, fm)
			field.name = "field"
			field.visible = false
			field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"repair":
			_box(r, Vector3(0.8, 0.6, 0.8), Vector3(0, -0.15, 0), _m(Color("#f2f2f2"), 0.2, 0.5))
			_box(r, Vector3(0.5, 0.15, 0.82), Vector3(0, -0.15, 0), _m(col, 0.2, 0.5))
			_box(r, Vector3(0.15, 0.5, 0.82), Vector3(0, -0.15, 0), _m(col, 0.2, 0.5))
			var arm := Blocks._node(r, "spin", Vector3(0, 0.2, 0))
			_box(arm, Vector3(0.08, 0.3, 0.08), Vector3(0.2, 0.15, 0), _m(STEEL, 0.8, 0.3))
			_box(arm, Vector3(0.2, 0.08, 0.08), Vector3(0.28, 0.3, 0), _m(STEEL, 0.8, 0.3))
			var led := Blocks._mi(r, Blocks.sphere_mesh(0.06), Vector3(-0.25, 0.2, 0), _glow(col, 4.0))
			led.name = "led"
		"nitro":
			for x in [-0.22, 0.22]:
				Blocks._mi(r, Blocks.capsule_mesh(0.18, 0.95), Vector3(x, -0.1, 0), _m(col, 0.7, 0.25), RX)
				_cyl(r, 0.05, 0.05, 0.2, Vector3(x, -0.1, -0.52), _m(STEEL, 0.8, 0.3), RX, 8)
			_box(r, Vector3(0.7, 0.08, 0.2), Vector3(0, 0.1, 0), _m(DARK, 0.4, 0.5))
			_flame(r, "flame", Vector3(0, -0.1, 0.5), 0.14, Color("#4fb3ff"), 0.22)
		"airbag":
			_box(r, Vector3(0.9, 0.9, 0.9), Vector3.ZERO, Blocks.block_mat(col, 0.0, 0.8))
			_box(r, Vector3(0.92, 0.18, 0.92), Vector3(0, 0, 0), _m(Color("#e53935"), 0.1, 0.6))
		"selfrighter":
			_box(r, Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), _m(DARK, 0.4, 0.5))
			var sp := Blocks._node(r, "spin")
			_box(sp, Vector3(0.12, 0.12, 0.9), Vector3(0, 0, 0), _m(col, 0.5, 0.4))
			Blocks._mi(sp, Blocks.sphere_mesh(0.16), Vector3(0, 0, -0.45), _m(STEEL, 0.8, 0.3))
			Blocks._mi(sp, Blocks.sphere_mesh(0.16), Vector3(0, 0, 0.45), _m(STEEL, 0.8, 0.3))
		"blink":
			_box(r, Vector3(0.9, 0.2, 0.9), Vector3(0, -0.4, 0), _m(DARK, 0.5, 0.4))
			var cr := SphereMesh.new()
			cr.radius = 0.3
			cr.height = 0.8
			cr.radial_segments = 4
			cr.rings = 2
			var crystal := _mi(r, cr, Vector3(0, 0.05, 0), _glow(col, 3.5))
			crystal.name = "led"
			var sp := Blocks._node(r, "spin", Vector3(0, 0.05, 0))
			Blocks._mi(sp, Blocks.torus_mesh(0.36, 0.4), Vector3.ZERO, _m(STEEL, 0.9, 0.2), Vector3(0.4, 0, 0))
		"flares":
			_box(r, Vector3(0.9, 0.4, 0.9), Vector3(0, -0.3, 0), _m(DARK, 0.4, 0.5))
			for x in [-0.25, 0.0, 0.25]:
				_cyl(r, 0.08, 0.08, 0.5, Vector3(x, 0.15, 0.1), _m(col, 0.4, 0.5), Vector3(0.5, 0, 0), 8)
		"dropweight":
			Blocks._mi(r, Blocks.sphere_mesh(0.42), Vector3(0, -0.08, 0), _m(col, 0.6, 0.45))
			Blocks._mi(r, Blocks.torus_mesh(0.14, 0.22), Vector3(0, 0.36, 0), _m(col, 0.6, 0.45), RX)
			_box(r, Vector3(0.6, 0.06, 0.12), Vector3(0, -0.05, -0.4), _m(YEL, 0.2, 0.5))
		"fueltank":
			_cyl(r, 0.42, 0.42, 0.95, Vector3.ZERO, _m(col, 0.4, 0.4), Vector3.ZERO, 18)
			for y in [-0.3, 0.3]:
				_cyl(r, 0.43, 0.43, 0.06, Vector3(0, y, 0), _m(DARK, 0.6, 0.4), Vector3.ZERO, 18)
			_cyl(r, 0.08, 0.08, 0.1, Vector3(0.2, 0.5, 0), _m(DARK, 0.6, 0.4), Vector3.ZERO, 10)
			_box(r, Vector3(0.3, 0.3, 0.02), Vector3(0, 0, -0.43), _m(YEL, 0.1, 0.6), Vector3(0, 0, PI * 0.25))
		"flag":
			_box(r, Vector3(0.4, 0.1, 0.4), Vector3(0, -0.45, 0), _m(DARK, 0.4, 0.5))
			_cyl(r, 0.035, 0.035, 2.4, Vector3(0, 0.75, 0), _m(STEEL, 0.8, 0.3), Vector3.ZERO, 8)
			Blocks._mi(r, Blocks.sphere_mesh(0.07), Vector3(0, 1.97, 0), _m(Color("#ffcc33"), 0.9, 0.2))
			var fl := Blocks._node(r, "flap", Vector3(0, 1.55, 0.02))
			var cm := StandardMaterial3D.new()
			cm.albedo_color = col
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_box(fl, Vector3(0.02, 0.6, 0.9), Vector3(0, 0, 0.47), cm)
		"discoball":
			_box(r, Vector3(0.5, 0.1, 0.5), Vector3(0, 0.45, 0), _m(DARK, 0.4, 0.5))
			_cyl(r, 0.02, 0.02, 0.3, Vector3(0, 0.27, 0), _m(STEEL, 0.8, 0.3), Vector3.ZERO, 6)
			var sp := Blocks._node(r, "spin", Vector3(0, -0.1, 0))
			var ds := SphereMesh.new()
			ds.radius = 0.32
			ds.height = 0.64
			ds.radial_segments = 12
			ds.rings = 6
			_mi(sp, ds, Vector3.ZERO, _m(col, 0.6, 0.1))
			for i in 3:
				var l := _omni(sp, "lamp%d" % i, Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * 0.5, Color.from_hsv(i / 3.0, 0.9, 1.0), 3.0, 9.0)
				l.name = "lamp" if i == 0 else "lamp%d" % i
		"cargocrate":
			_box(r, Vector3(0.96, 0.96, 0.96), Vector3.ZERO, Blocks.block_mat(col, 0.3, 0.6))
			for y in [-0.3, 0.0, 0.3]:
				_box(r, Vector3(0.98, 0.05, 0.98), Vector3(0, y, 0), _m(col.darkened(0.3), 0.3, 0.6))
			_box(r, Vector3(0.5, 0.06, 0.08), Vector3(0, 0.52, 0), _m(DARK, 0.5, 0.4))
			_box(r, Vector3(0.3, 0.2, 0.01), Vector3(0, 0.1, -0.49), _m(YEL, 0.1, 0.6))
		_:
			return false
	return true


# ---------------------------------------------------------------- mechanical
# Every mechanical id gets its own silhouette; `col` stays the main tint so
# painting works. vehicle.gd animates the `mov`, `rod` and `coil` nodes.

const CHROME := Color("#e8edf2")
const HOSE := Color("#2a2d33")
const RED := Color("#e53935")

## Wheel engine. Shape follows the style (single, inline, V, electric, turbine);
## the front pulley/fan is the `spin` node vehicle.gd turns with the throttle.
static func _motor(r: Node3D, def: Dictionary, col: Color) -> void:
	var style: String = def.get("style", "inline")
	var cyls: int = def.get("cyls", 4)
	var dark := _m(DARK, 0.4, 0.5)
	var metal := _m(STEEL, 0.75, 0.3)
	var body := _m(col, 0.45, 0.4)
	var cover := _m(col.lightened(0.25), 0.5, 0.3)
	var plug := _m(Color("#e53935"), 0.2, 0.5)
	_box(r, Vector3(0.92, 0.12, 0.92), Vector3(0, -0.44, 0), dark)
	match style:
		"single":
			_box(r, Vector3(0.46, 0.36, 0.46), Vector3(0, -0.2, 0.05), body)
			_cyl(r, 0.15, 0.17, 0.4, Vector3(0, 0.16, 0.05), metal, Vector3.ZERO, 14)
			for i in 4:
				_cyl(r, 0.24, 0.24, 0.03, Vector3(0, 0.02 + i * 0.08, 0.05), metal, Vector3.ZERO, 14)
			Blocks._mi(r, Blocks.sphere_mesh(0.05), Vector3(0, 0.4, 0.05), plug)
			_cyl(r, 0.2, 0.2, 0.06, Vector3(-0.27, -0.15, 0.05), _m(Color("#e53935"), 0.2, 0.5), RZ, 18)
			_cyl(r, 0.05, 0.05, 0.5, Vector3(0.26, 0.05, 0.2), metal, RX, 8)
		"inline":
			_box(r, Vector3(0.5, 0.42, 0.86), Vector3(0, -0.15, 0), body)
			_box(r, Vector3(0.44, 0.14, 0.82), Vector3(0, 0.13, 0), cover)
			for i in cyls:
				var z := -0.32 + 0.64 * (i + 0.5) / cyls
				Blocks._mi(r, Blocks.sphere_mesh(0.04), Vector3(0, 0.22, z), plug)
				_cyl(r, 0.035, 0.035, 0.18, Vector3(0.3, 0.0, z), metal, RZ, 8)
			_cyl(r, 0.06, 0.06, 0.8, Vector3(0.39, 0.0, 0.0), metal, RX, 10)
			_box(r, Vector3(0.12, 0.2, 0.7), Vector3(-0.32, 0.0, 0.0), dark)
			if def.get("turbo", false):
				Blocks._mi(r, Blocks.torus_mesh(0.07, 0.16), Vector3(0.36, 0.2, 0.32), metal, RZ)
				_cyl(r, 0.08, 0.08, 0.12, Vector3(0.36, 0.2, 0.32), dark, RZ, 12)
		"v":
			_box(r, Vector3(0.56, 0.32, 0.86), Vector3(0, -0.22, 0), body)
			for sx in [-1.0, 1.0]:
				var bank := Node3D.new()
				r.add_child(bank)
				bank.position = Vector3(sx * 0.16, 0.0, 0)
				bank.rotation.z = -sx * 0.6
				_box(bank, Vector3(0.26, 0.32, 0.84), Vector3(0, 0.0, 0), body)
				_box(bank, Vector3(0.24, 0.1, 0.82), Vector3(0, 0.2, 0), cover)
				var n := maxi(1, cyls / 2)
				for i in n:
					var z := -0.32 + 0.64 * (i + 0.5) / n
					Blocks._mi(bank, Blocks.sphere_mesh(0.035), Vector3(0, 0.27, z), plug)
				_cyl(r, 0.05, 0.05, 0.8, Vector3(sx * 0.43, -0.12, 0), metal, RX, 10)
			_box(r, Vector3(0.2, 0.14, 0.7), Vector3(0, 0.16, 0), dark)
			if def.get("blower", false):
				_box(r, Vector3(0.3, 0.2, 0.42), Vector3(0, 0.32, 0.02), metal)
				_box(r, Vector3(0.24, 0.12, 0.22), Vector3(0, 0.47, -0.02), _m(DARK, 0.2, 0.6))
		"electric":
			_cyl(r, 0.36, 0.36, 0.78, Vector3(0, -0.02, 0.02), body, RX, 24)
			for i in 6:
				Blocks._mi(r, Blocks.torus_mesh(0.35, 0.41), Vector3(0, -0.02, -0.28 + i * 0.12), dark, RX)
			_box(r, Vector3(0.32, 0.12, 0.34), Vector3(0, 0.38, 0.12), dark)
			_box(r, Vector3(0.22, 0.03, 0.2), Vector3(0, 0.45, 0.12), _glow(Color("#39e1ff"), 2.5))
		"turbine":
			_cyl(r, 0.32, 0.42, 0.9, Vector3(0, -0.02, 0), body, RX, 22)
			Blocks._mi(r, Blocks.torus_mesh(0.3, 0.43), Vector3(0, -0.02, -0.44), metal, RX)
			_cyl(r, 0.22, 0.22, 0.02, Vector3(0, -0.02, 0.46), _glow(Color("#ff6a2a"), 2.5), RX, 16)
			for i in 3:
				_cyl(r, 0.4 - i * 0.03, 0.4 - i * 0.03, 0.04, Vector3(0, -0.02, -0.2 + i * 0.22), dark, RX, 22)
	# front pulley and fan, turned by vehicle.gd
	var spin := Blocks._node(r, "spin", Vector3(0, -0.05, -0.47))
	_cyl(spin, 0.12, 0.12, 0.05, Vector3.ZERO, metal, RX, 14)
	if style != "electric" and style != "turbine":
		for a in 4:
			_box(spin, Vector3(0.05, 0.3, 0.02), Vector3.ZERO, dark, Vector3(0, 0, a * PI * 0.25 + 0.3))


## Ring of `n` studs around the local Y axis.
static func _bolts(p: Node3D, n: int, rad: float, y: float, m: Material, size := 0.04, a0 := 0.0) -> void:
	for i in n:
		var a := a0 + i * TAU / n
		Blocks._mi(p, Blocks.sphere_mesh(size), Vector3(cos(a) * rad, y, sin(a) * rad), m)


## Coil spring along Y built from slightly tilted rings (reads as a helix).
static func _coil(p: Node3D, rad: float, wire: float, y0: float, y1: float, n: int, m: Material, x := 0.0) -> void:
	for i in n:
		var y := lerpf(y0, y1, (i + 0.5) / n)
		Blocks._mi(p, Blocks.torus_mesh(rad - wire, rad + wire), Vector3(x, y, 0), m, Vector3(0.12, 0, 0))


## Pistons: `rod` is a unit-height cylinder stretched by vehicle.gd, `mov` the output face.
static func _piston(f: Node3D, def: Dictionary, col: Color) -> void:
	var body := Blocks.block_mat(col, 0.3, 0.5)
	var dkm := _m(col.darkened(0.35), 0.4, 0.5)
	var steel := _m(STEEL, 0.7, 0.3)
	var dark := _m(DARK, 0.4, 0.5)
	var hose := _m(HOSE, 0.1, 0.8)
	var rod := Blocks._node(f, "rod", Vector3(0, 0.3, 0))
	var mv := Blocks._node(f, "mov")
	var rr := 0.13
	var plate := Vector3(0.86, 0.1, 0.86)
	match def.id:
		"piston_s":  # squat drum, short fat rod
			_box(f, Vector3(0.94, 0.16, 0.94), Vector3(0, -0.42, 0), body)
			_cyl(f, 0.42, 0.44, 0.4, Vector3(0, -0.14, 0), body, Vector3.ZERO, 24)
			Blocks._mi(f, Blocks.torus_mesh(0.38, 0.45), Vector3(0, 0.06, 0), dark)
			_bolts(f, 6, 0.32, 0.08, steel, 0.035)
			_cyl(f, 0.22, 0.24, 0.1, Vector3(0, 0.1, 0), steel)
			rr = 0.17
		"piston_l":  # tall slim barrel with banding and fins
			_box(f, Vector3(0.9, 0.08, 0.9), Vector3(0, -0.46, 0), body)
			_cyl(f, 0.22, 0.22, 0.76, Vector3(0, -0.04, 0), body, Vector3.ZERO, 16)
			for y in [-0.26, 0.0, 0.24]:
				Blocks._mi(f, Blocks.torus_mesh(0.2, 0.27), Vector3(0, y, 0), steel)
			for a in 4:
				var ang := a * PI * 0.5
				_box(f, Vector3(0.34, 0.3, 0.05), Vector3(cos(ang) * 0.3, -0.27, -sin(ang) * 0.3), dkm, Vector3(0, ang, 0))
			_cyl(f, 0.15, 0.17, 0.06, Vector3(0, 0.37, 0), dark)
			rr = 0.09
			plate = Vector3(0.7, 0.08, 0.7)
		"piston_t":  # stepped telescopic sleeves
			_box(f, Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), body)
			var rads: Array[float] = [0.4, 0.33, 0.26, 0.2]
			for i in 4:
				_cyl(f, rads[i], rads[i], 0.11, Vector3(0, -0.14 + i * 0.11, 0), body if i % 2 == 0 else steel, Vector3.ZERO, 20)
			var srad: Array[float] = [0.16, 0.125, 0.09]
			for i in 3:
				_cyl(rod, srad[i], srad[i], 0.34, Vector3(0, -0.333 + i * 0.333, 0), _m(CHROME, 0.95, 0.12))
				_cyl(rod, srad[i] + 0.025, srad[i] + 0.025, 0.05, Vector3(0, -0.19 + i * 0.333, 0), dark)
			rr = 0.05
			plate = Vector3(0.86, 0.08, 0.86)
		"piston_q":  # slim barrel wrapped in a red return spring
			_box(f, Vector3(0.8, 0.1, 0.8), Vector3(0, -0.45, 0), dark)
			_cyl(f, 0.14, 0.14, 0.66, Vector3(0, -0.08, 0), body)
			_coil(f, 0.25, 0.025, -0.38, 0.22, 6, _m(RED, 0.5, 0.3))
			_box(f, Vector3(0.14, 0.18, 0.14), Vector3(0.32, -0.3, 0.0), _m(YEL, 0.2, 0.5))
			_box(f, Vector3(0.18, 0.04, 0.04), Vector3(0.32, -0.18, 0.0), _m(RED, 0.3, 0.4), Vector3(0, 0, 0.5))
			rr = 0.07
			plate = Vector3(0.7, 0.06, 0.7)
		"ram":  # fat octagonal armored cylinder with hose lines
			_box(f, Vector3(0.96, 0.2, 0.96), Vector3(0, -0.4, 0), body)
			_cyl(f, 0.42, 0.42, 0.6, Vector3(0, -0.05, 0), body, Vector3.ZERO, 8)
			for y in [-0.24, 0.18]:
				_cyl(f, 0.45, 0.45, 0.07, Vector3(0, y, 0), dark, Vector3.ZERO, 8)
			for z in [-0.2, 0.2]:
				_cyl(f, 0.035, 0.035, 0.52, Vector3(0.44, -0.04, z), hose)
				_cyl(f, 0.05, 0.05, 0.08, Vector3(0.43, 0.22, z), steel, RZ, 8)
			_cyl(f, 0.3, 0.3, 0.08, Vector3(0, 0.29, 0), steel)
			rr = 0.19
			plate = Vector3(0.92, 0.14, 0.92)
		"hydro":  # tie-rod cylinder with end caps and a hose loop
			_box(f, Vector3(0.72, 0.12, 0.72), Vector3(0, -0.43, 0), body)
			_box(f, Vector3(0.72, 0.12, 0.72), Vector3(0, 0.25, 0), body)
			_cyl(f, 0.29, 0.29, 0.58, Vector3(0, -0.09, 0), steel, Vector3.ZERO, 20)
			for x in [-0.28, 0.28]:
				for z in [-0.28, 0.28]:
					_cyl(f, 0.03, 0.03, 0.84, Vector3(x, -0.09, z), _m(CHROME, 0.9, 0.2), Vector3.ZERO, 8)
			_cyl(f, 0.05, 0.05, 0.1, Vector3(0.4, 0.25, 0), dark, RZ, 8)
			_cyl(f, 0.05, 0.05, 0.1, Vector3(0.4, -0.43, 0), dark, RZ, 8)
			_cyl(f, 0.03, 0.03, 0.68, Vector3(0.46, -0.09, 0), hose)
			rr = 0.12
		"kicker":  # air tank + boxy cylinder + punch plate
			_box(f, Vector3(0.9, 0.08, 0.9), Vector3(0, -0.46, 0), dark)
			_cyl(f, 0.19, 0.19, 0.56, Vector3(0, -0.23, 0.24), body, RZ, 16)
			for x in [-0.28, 0.28]:
				Blocks._mi(f, Blocks.sphere_mesh(0.19), Vector3(x, -0.23, 0.24), body)
			_box(f, Vector3(0.56, 0.6, 0.42), Vector3(0, -0.12, -0.2), dkm)
			_cyl(f, 0.09, 0.09, 0.02, Vector3(-0.15, -0.23, 0.44), _m(Color("#f4f6f9"), 0.1, 0.4), RX, 12)
			_cyl(f, 0.04, 0.04, 0.24, Vector3(0.18, 0.0, 0.24), hose)
			_box(f, Vector3(0.12, 0.1, 0.12), Vector3(0.18, 0.12, 0.2), _m(RED, 0.3, 0.4))
			_cyl(mv, 0.3, 0.34, 0.1, Vector3(0, 0.34, 0), _m(RED, 0.4, 0.4), Vector3.ZERO, 20)
			rr = 0.15
		"jack":  # scissor arms stretch with the rod, crank screw on the base
			_box(f, Vector3(0.96, 0.1, 0.96), Vector3(0, -0.45, 0), dark)
			_box(f, Vector3(0.6, 0.22, 0.6), Vector3(0, -0.3, 0), body)
			_cyl(f, 0.04, 0.04, 0.96, Vector3(0, -0.3, 0.36), steel, RZ, 8)
			_box(f, Vector3(0.04, 0.2, 0.04), Vector3(0.47, -0.22, 0.36), dark)
			for x in [-0.3, 0.3]:
				for s in [-1.0, 1.0]:
					_box(rod, Vector3(0.06, 1.16, 0.07), Vector3(x, 0, 0), body, Vector3(s * 0.54, 0, 0))
			_cyl(rod, 0.035, 0.035, 0.7, Vector3.ZERO, dark, RZ, 8)
			_box(mv, Vector3(0.6, 0.1, 0.12), Vector3(0, 0.33, 0.28), dkm)
			_box(mv, Vector3(0.6, 0.1, 0.12), Vector3(0, 0.33, -0.28), dkm)
			rr = 0.05
		"pump":  # accordion bellows stretch with the rod
			_box(f, Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), body)
			_cyl(f, 0.07, 0.07, 0.2, Vector3(0.42, -0.32, 0), steel, RZ, 10)
			_cyl(f, 0.11, 0.11, 0.04, Vector3(0.48, -0.32, 0), dark, RZ, 10)
			_cyl(f, 0.1, 0.1, 0.16, Vector3(-0.3, -0.12, -0.3), _m(Color("#f4f6f9"), 0.2, 0.4))
			var fold := _m(col.darkened(0.15), 0.0, 0.85)
			var rub := _m(RUBBER, 0.0, 0.9)
			for i in 6:
				var br := 0.33 if i % 2 == 0 else 0.25
				_cyl(rod, br, br, 1.0 / 6.0, Vector3(0, -0.5 + (i + 0.5) / 6.0, 0), fold if i % 2 == 0 else rub, Vector3.ZERO, 20)
			rr = 0.05
		"leg_lift":  # walker knee: twin hydraulic struts beside the rod, glowing status ring
			_box(f, Vector3(0.92, 0.22, 0.92), Vector3(0, -0.39, 0), body)
			_cyl(f, 0.3, 0.34, 0.36, Vector3(0, -0.1, 0), dkm, Vector3.ZERO, 20)
			Blocks._mi(f, Blocks.torus_mesh(0.3, 0.36), Vector3(0, 0.06, 0), _glow(Color("#c05cff"), 3.0))
			for x in [-0.34, 0.34]:
				_cyl(f, 0.07, 0.07, 0.5, Vector3(x, -0.05, 0.3), steel, Vector3.ZERO, 10)
				_cyl(rod, 0.04, 0.04, 1.0, Vector3(x, 0, 0.3), _m(CHROME, 0.95, 0.12), Vector3.ZERO, 8)
			rr = 0.11
		_:
			_box(f, Vector3(0.9, 0.5, 0.9), Vector3(0, -0.22, 0), body)
			_box(f, Vector3(0.92, 0.08, 0.92), Vector3(0, -0.02, 0), dark)
			_cyl(f, 0.3, 0.3, 0.4, Vector3(0, 0.2, 0), steel, Vector3.ZERO, 16)
	_cyl(rod, rr, rr, 1.0, Vector3.ZERO, _m(CHROME, 0.95, 0.12))
	rod.scale = Vector3(1, 0.3, 1)
	_box(mv, plate, Vector3(0, 0.44, 0), dkm)
	_stripes(mv, 0.5)


## Hinges: `mov` pivots about frame X at the top face (0, 0.5, 0).
static func _hinge(f: Node3D, def: Dictionary, col: Color) -> void:
	var body := Blocks.block_mat(col, 0.3, 0.5)
	var dkm := _m(col.darkened(0.35), 0.4, 0.5)
	var steel := _m(STEEL, 0.6, 0.4)
	var dark := _m(DARK, 0.6, 0.35)
	var chrome := _m(CHROME, 0.9, 0.2)
	var white := _m(Color("#f4f6f9"), 0.1, 0.4)
	var mv := Blocks._node(f, "mov", Vector3(0, 0.5, 0))
	match def.id:
		"servo":  # RC servo: boxy case, mounting tabs, side horn
			_box(f, Vector3(0.8, 0.6, 0.6), Vector3(0, -0.18, 0), body)
			_box(f, Vector3(0.98, 0.05, 0.36), Vector3(0, -0.02, 0), dkm)
			for x in [-0.43, 0.43]:
				_cyl(f, 0.035, 0.035, 0.06, Vector3(x, -0.02, 0), dark, Vector3.ZERO, 8)
			_box(f, Vector3(0.5, 0.2, 0.01), Vector3(0, -0.2, 0.3), white)
			var wire: Array[Color] = [RED, Color("#ff9a1f"), Color("#6d4c41")]
			for i in 3:
				_box(f, Vector3(0.04, 0.03, 0.14), Vector3(-0.05 + i * 0.05, -0.4, -0.36), _m(wire[i], 0.1, 0.6))
			for x in [-0.32, 0.32]:
				_box(f, Vector3(0.12, 0.42, 0.42), Vector3(x, 0.22, 0), dkm)
			_cyl(f, 0.09, 0.09, 0.96, Vector3(0, 0.42, 0), dark, RZ, 10)
			_cyl(mv, 0.1, 0.1, 0.05, Vector3(0.44, -0.08, 0), white, RZ, 12)
			_box(mv, Vector3(0.04, 0.07, 0.5), Vector3(0.45, -0.08, 0), white)
			_box(mv, Vector3(0.5, 0.2, 0.4), Vector3(0, -0.12, 0), steel)
		"servo_w":  # piano hinge: low slab, alternating knuckles
			_box(f, Vector3(0.96, 0.3, 0.96), Vector3(0, -0.34, 0), body)
			_box(f, Vector3(0.96, 0.26, 0.06), Vector3(0, 0.2, 0.12), dkm)
			_cyl(f, 0.03, 0.03, 1.0, Vector3(0, 0.42, 0), chrome, RZ, 8)
			for i in 5:
				var p := f if i % 2 == 0 else mv
				_cyl(p, 0.08, 0.08, 0.18, Vector3(-0.4 + i * 0.2, 0.42 if i % 2 == 0 else -0.08, 0), body if i % 2 == 0 else steel, RZ, 12)
			for i in 7:
				_box(f, Vector3(0.02, 0.06, 0.02), Vector3(-0.36 + i * 0.12, -0.17, 0.48), dark)
		"servo_h":  # bolted armored gearbox with side gear
			_box(f, Vector3(0.96, 0.6, 0.96), Vector3(0, -0.2, 0), body)
			for x in [-0.38, 0.38]:
				for y in [-0.42, 0.02]:
					for z in [-0.485, 0.485]:
						_cyl(f, 0.04, 0.04, 0.03, Vector3(x, y, z), steel, RX, 6)
			for x in [-0.36, 0.36]:
				_box(f, Vector3(0.22, 0.4, 0.6), Vector3(x, 0.2, 0), dkm)
			_cyl(f, 0.24, 0.24, 0.04, Vector3(0.49, -0.2, 0), steel, RZ, 16)
			for i in 8:
				var a := i * TAU / 8.0
				_box(f, Vector3(0.04, 0.07, 0.06), Vector3(0.49, -0.2 + sin(a) * 0.26, cos(a) * 0.26), steel, Vector3(PI * 0.5 - a, 0, 0))
			_cyl(f, 0.13, 0.13, 1.0, Vector3(0, 0.38, 0), dark, RZ, 8)
			_box(mv, Vector3(0.48, 0.26, 0.6), Vector3(0, -0.12, 0), steel)
		"servo_f":  # small case with a lightning stripe
			_box(f, Vector3(0.6, 0.42, 0.5), Vector3(0, -0.28, 0), body)
			_box(f, Vector3(0.9, 0.05, 0.3), Vector3(0, -0.1, 0), dkm)
			var bolt := _glow(Color("#fff6a0"), 3.0)
			_box(f, Vector3(0.05, 0.16, 0.01), Vector3(-0.04, -0.2, 0.255), bolt, Vector3(0, 0, -0.5))
			_box(f, Vector3(0.12, 0.04, 0.01), Vector3(0.0, -0.28, 0.255), bolt)
			_box(f, Vector3(0.05, 0.16, 0.01), Vector3(0.04, -0.36, 0.255), bolt, Vector3(0, 0, -0.5))
			for x in [-0.3, 0.3]:
				_box(f, Vector3(0.1, 0.36, 0.3), Vector3(x, 0.24, 0), dkm)
			_cyl(f, 0.06, 0.06, 0.8, Vector3(0, 0.42, 0), dark, RZ, 8)
			_box(mv, Vector3(0.36, 0.18, 0.3), Vector3(0, -0.1, 0), steel)
			_box(mv, Vector3(0.04, 0.12, 0.3), Vector3(0.0, -0.1, -0.2), _m(RED, 0.3, 0.4))
		"steer_hinge":  # steering knuckle: fork, kingpin, tie-rod arm
			_box(f, Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), body)
			for x in [-0.38, 0.38]:
				_box(f, Vector3(0.14, 0.62, 0.36), Vector3(x, 0.1, 0), body)
			_cyl(f, 0.09, 0.09, 0.98, Vector3(0, 0.42, 0), dark, RZ, 10)
			for x in [-0.46, 0.46]:
				_cyl(f, 0.12, 0.12, 0.04, Vector3(x, 0.42, 0), steel, RZ, 6)
			_box(mv, Vector3(0.56, 0.3, 0.4), Vector3(0, -0.15, 0.04), steel)
			_box(mv, Vector3(0.1, 0.1, 0.3), Vector3(0, -0.2, -0.3), dkm)
			Blocks._mi(mv, Blocks.sphere_mesh(0.07), Vector3(0, -0.2, -0.44), chrome)
			_cyl(f, 0.04, 0.04, 0.5, Vector3(0.12, 0.06, -0.44), chrome, RZ, 8)
		"gimbal_p", "gimbal_y", "gimbal_r":
			var ac: Color = {"gimbal_p": RED, "gimbal_y": Color("#3ddc84"), "gimbal_r": Color("#3f7bff")}[def.id]
			var am := _m(ac, 0.4, 0.35)
			_cyl(f, 0.44, 0.46, 0.18, Vector3(0, -0.41, 0), body, Vector3.ZERO, 24)
			for x in [-0.42, 0.42]:
				_box(f, Vector3(0.1, 0.78, 0.16), Vector3(x, 0.04, 0), dkm)
				_cyl(f, 0.06, 0.06, 0.08, Vector3(x * 1.1, 0.42, 0), am, RZ, 10)
			match def.id:
				"gimbal_p":  # vertical ring swinging in the YZ plane
					Blocks._mi(f, Blocks.torus_mesh(0.3, 0.37), Vector3(0, 0.06, 0), body, RZ)
					_box(mv, Vector3(0.7, 0.08, 0.08), Vector3(0, -0.06, 0), am)
					Blocks._mi(mv, Blocks.torus_mesh(0.19, 0.24), Vector3(0, -0.28, 0), steel, RZ)
				"gimbal_y":  # two concentric flat rings on a pin
					Blocks._mi(f, Blocks.torus_mesh(0.34, 0.41), Vector3(0, -0.14, 0), body)
					Blocks._mi(f, Blocks.torus_mesh(0.2, 0.26), Vector3(0, -0.14, 0), am)
					_box(f, Vector3(0.06, 0.06, 0.82), Vector3(0, -0.14, 0), steel)
					_cyl(mv, 0.14, 0.18, 0.3, Vector3(0, -0.2, 0), steel, Vector3.ZERO, 16)
				_:  # roll: bearing barrel with twist marks
					_cyl(f, 0.32, 0.32, 0.36, Vector3(0, -0.12, 0), steel, Vector3.ZERO, 24)
					Blocks._mi(f, Blocks.torus_mesh(0.31, 0.37), Vector3(0, -0.12, 0), am)
					for i in 3:
						var a := i * TAU / 3.0
						_box(f, Vector3(0.14, 0.04, 0.02), Vector3(cos(a) * 0.33, 0.0, sin(a) * 0.33), am, Vector3(0, -a + PI * 0.5, 0.5))
					_cyl(mv, 0.26, 0.26, 0.12, Vector3(0, -0.12, 0), dkm, Vector3.ZERO, 20)
		"gear_hinge":  # landing gear: bracket, folding strut with oleo
			_box(f, Vector3(0.9, 0.12, 0.9), Vector3(0, -0.44, 0), body)
			for x in [-0.3, 0.3]:
				_box(f, Vector3(0.08, 0.74, 0.3), Vector3(x, 0.02, 0), body)
				_box(f, Vector3(0.06, 0.6, 0.06), Vector3(x, -0.08, 0.2), dkm, Vector3(-0.55, 0, 0))
			_cyl(f, 0.08, 0.08, 0.76, Vector3(0, 0.42, 0), dark, RZ, 10)
			_cyl(mv, 0.08, 0.08, 0.5, Vector3(0, -0.16, -0.12), steel, RX, 12)
			_cyl(mv, 0.055, 0.055, 0.3, Vector3(0, -0.16, -0.32), chrome, RX, 12)
			_box(mv, Vector3(0.04, 0.12, 0.16), Vector3(0.09, -0.24, -0.28), dkm, Vector3(0.6, 0, 0))
			_box(mv, Vector3(0.24, 0.06, 0.08), Vector3(0, -0.16, -0.44), dark)
			_box(mv, Vector3(0.5, 0.14, 0.2), Vector3(0, -0.12, 0.18), dkm)
		"tilt_hinge":  # pylons carrying a rotating nacelle collar
			_box(f, Vector3(0.9, 0.12, 0.9), Vector3(0, -0.44, 0), body)
			for x in [-0.4, 0.4]:
				_box(f, Vector3(0.16, 0.78, 0.46), Vector3(x, 0.0, 0), body)
				for i in 3:
					_box(f, Vector3(0.02, 0.04, 0.1), Vector3(x * 1.2, 0.3 - i * 0.12, 0.15), _m(YEL, 0.2, 0.5))
			_cyl(mv, 0.22, 0.22, 0.6, Vector3(0, -0.24, 0), steel, RZ, 20)
			for x in [-0.22, 0.22]:
				Blocks._mi(mv, Blocks.torus_mesh(0.21, 0.25), Vector3(x, -0.24, 0), _glow(Color("#5fd0ff"), 2.0), RZ)
			_cyl(mv, 0.1, 0.16, 0.12, Vector3(0, -0.24, 0.24), dkm, RX, 16)
		"flipper":  # long ribbed paddle on a low wedge
			_box(f, Vector3(0.9, 0.24, 0.9), Vector3(0, -0.38, 0), body)
			_box(f, Vector3(0.9, 0.2, 0.5), Vector3(0, -0.2, 0.2), body, Vector3(-0.35, 0, 0))
			_cyl(f, 0.06, 0.06, 0.48, Vector3(0, -0.04, -0.12), dark, Vector3(0.7, 0, 0), 10)
			for x in [-0.42, 0.42]:
				_box(f, Vector3(0.08, 0.5, 0.2), Vector3(x, 0.2, 0), dkm)
			_cyl(f, 0.08, 0.08, 0.98, Vector3(0, 0.42, 0), dark, RZ, 10)
			for x in [-0.28, 0.0, 0.28]:
				_box(mv, Vector3(0.06, 0.12, 0.92), Vector3(x, -0.12, 0), dkm)
			for z in [-0.46, 0.46]:
				_box(mv, Vector3(0.9, 0.08, 0.06), Vector3(0, -0.1, z), _m(RED, 0.3, 0.4))
		"wiggle":  # fishtail: rounded body, spine knuckles, V tail fins
			_cyl(f, 0.4, 0.44, 0.5, Vector3(0, -0.25, 0), body, Vector3.ZERO, 20)
			for i in 3:
				_cyl(f, 0.3 - i * 0.05, 0.3 - i * 0.05, 0.05, Vector3(0, 0.04 + i * 0.09, 0), dkm if i % 2 == 0 else steel, Vector3.ZERO, 16)
			_cyl(f, 0.07, 0.07, 0.6, Vector3(0, 0.42, 0), dark, RZ, 10)
			for s in [-1.0, 1.0]:
				_box(mv, Vector3(0.7, 0.04, 0.4), Vector3(0, -0.14, s * 0.2), body, Vector3(s * 0.5, 0, 0))
			_cyl(mv, 0.09, 0.09, 0.5, Vector3(0, -0.06, 0), steel, RZ, 10)
		"sweep":  # radar head: pedestal and a sideways dish with feed spike
			_cyl(f, 0.44, 0.46, 0.08, Vector3(0, -0.46, 0), dkm, Vector3.ZERO, 24)
			_cyl(f, 0.24, 0.3, 0.5, Vector3(0, -0.18, 0), body, Vector3.ZERO, 16)
			for x in [-0.36, 0.36]:
				_box(f, Vector3(0.1, 0.4, 0.24), Vector3(x, 0.22, 0), dkm)
			_cyl(f, 0.07, 0.07, 0.8, Vector3(0, 0.42, 0), dark, RZ, 10)
			var dish := Blocks._mi(mv, Blocks.sphere_mesh(0.22, true), Vector3(0, -0.24, 0.12), chrome, Vector3(-PI * 0.5, 0, 0))
			dish.scale = Vector3(1, 0.4, 1)
			_cyl(mv, 0.015, 0.015, 0.24, Vector3(0, -0.24, 0.26), dark, RX, 6)
			Blocks._mi(mv, Blocks.sphere_mesh(0.035), Vector3(0, -0.24, 0.38), _glow(RED, 3.0))
		"leg_servo":  # walker hip: drum motor on a vertical kingpin with a glowing ring
			_box(f, Vector3(0.92, 0.22, 0.92), Vector3(0, -0.39, 0), body)
			_cyl(f, 0.36, 0.4, 0.42, Vector3(0, -0.08, 0), dkm, Vector3.ZERO, 24)
			Blocks._mi(f, Blocks.torus_mesh(0.36, 0.42), Vector3(0, 0.0, 0), _glow(Color("#c05cff"), 3.0))
			for x in [-0.38, 0.38]:
				_box(f, Vector3(0.12, 0.5, 0.44), Vector3(x, 0.2, 0), dkm)
			_cyl(f, 0.1, 0.1, 0.98, Vector3(0, 0.42, 0), dark, RZ, 10)
			_box(mv, Vector3(0.56, 0.26, 0.5), Vector3(0, -0.13, 0), steel)
			_box(mv, Vector3(0.3, 0.06, 0.52), Vector3(0, -0.28, 0), _m(RED, 0.3, 0.4))
		_:
			_box(f, Vector3(0.9, 0.5, 0.9), Vector3(0, -0.22, 0), body)
			for x in [-0.37, 0.37]:
				_box(f, Vector3(0.14, 0.42, 0.5), Vector3(x, 0.22, 0), dkm)
			_cyl(f, 0.1, 0.1, 0.98, Vector3(0, 0.42, 0), dark, RZ, 10)
			_box(mv, Vector3(0.56, 0.24, 0.42), Vector3(0, -0.1, 0), steel)
	_box(mv, Vector3(0.86, 0.06, 0.86), Vector3(0, -0.03, 0), dkm)
	_stripes(mv, 0.0)


## Rotators: `mov` spins about frame Y; its top face carries a yellow marker.
static func _rotator(f: Node3D, def: Dictionary, col: Color) -> void:
	var body := Blocks.block_mat(col, 0.3, 0.5)
	var dkm := _m(col.darkened(0.35), 0.5, 0.4)
	var steel := _m(STEEL, 0.7, 0.3)
	var dark := _m(DARK, 0.6, 0.4)
	var yel := _m(YEL, 0.2, 0.5)
	var mv := Blocks._node(f, "mov")
	match def.id:
		"spinner":  # slim post with a small disc
			_box(f, Vector3(0.9, 0.16, 0.9), Vector3(0, -0.42, 0), body)
			_cyl(f, 0.16, 0.22, 0.56, Vector3(0, -0.06, 0), dark, Vector3.ZERO, 16)
			_cyl(mv, 0.3, 0.3, 0.1, Vector3(0, 0.42, 0), steel, Vector3.ZERO, 24)
			_box(mv, Vector3(0.08, 0.04, 0.24), Vector3(0, 0.48, -0.14), yel)
			_bolts(mv, 3, 0.18, 0.47, dark, 0.03, 0.6)
		"turntable":  # wide low ring bearing with a bolt circle
			_box(f, Vector3(0.96, 0.22, 0.96), Vector3(0, -0.39, 0), body)
			Blocks._mi(f, Blocks.torus_mesh(0.36, 0.46), Vector3(0, -0.22, 0), dark)
			_bolts(f, 12, 0.41, -0.16, steel, 0.035)
			_cyl(mv, 0.48, 0.48, 0.1, Vector3(0, 0.43, 0), steel, Vector3.ZERO, 32)
			_cyl(mv, 0.38, 0.4, 0.3, Vector3(0, 0.23, 0), dkm, Vector3.ZERO, 24)
			_bolts(mv, 8, 0.42, 0.48, dark, 0.03)
			_box(mv, Vector3(0.08, 0.03, 0.34), Vector3(0, 0.49, -0.24), yel)
		"heavymotor":  # finned motor housing with a terminal box and thick hub
			_box(f, Vector3(0.9, 0.1, 0.9), Vector3(0, -0.45, 0), dark)
			_cyl(f, 0.32, 0.32, 0.66, Vector3(0, -0.1, 0), body, Vector3.ZERO, 20)
			for i in 10:
				var a := i * TAU / 10.0
				_box(f, Vector3(0.14, 0.56, 0.05), Vector3(cos(a) * 0.36, -0.12, sin(a) * 0.36), dkm, Vector3(0, -a, 0))
			_box(f, Vector3(0.18, 0.16, 0.2), Vector3(0, -0.3, 0.4), dark)
			_cyl(mv, 0.4, 0.4, 0.18, Vector3(0, 0.39, 0), dark, Vector3.ZERO, 8)
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4.0
				_box(mv, Vector3(0.12, 0.04, 0.06), Vector3(cos(a) * 0.26, 0.48, sin(a) * 0.26), steel, Vector3(0, -a, 0))
			_box(mv, Vector3(0.08, 0.05, 0.3), Vector3(0, 0.49, -0.15), yel)
		"turbospin":  # glowing stacked rings and a bladed disc
			var gl := _glow(col.lightened(0.2), 3.5)
			_box(f, Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), dark)
			for i in 3:
				var rr := 0.42 - i * 0.07
				Blocks._mi(f, Blocks.torus_mesh(rr - 0.03, rr), Vector3(0, -0.14 + i * 0.12, 0), gl)
			_cyl(f, 0.14, 0.18, 0.5, Vector3(0, 0.0, 0), steel, Vector3.ZERO, 12)
			_cyl(mv, 0.42, 0.42, 0.06, Vector3(0, 0.44, 0), body, Vector3.ZERO, 24)
			Blocks._mi(mv, Blocks.torus_mesh(0.4, 0.46), Vector3(0, 0.44, 0), gl)
			for i in 3:
				var a := i * TAU / 3.0
				_box(mv, Vector3(0.34, 0.04, 0.1), Vector3(cos(a) * 0.2, 0.47, sin(a) * 0.2), dark, Vector3(0.3, -a, 0))
			_box(mv, Vector3(0.06, 0.04, 0.16), Vector3(0, 0.47, -0.32), yel)
		_:
			_box(f, Vector3(0.9, 0.55, 0.9), Vector3(0, -0.2, 0), body)
			_cyl(f, 0.32, 0.36, 0.2, Vector3(0, 0.15, 0), dark, Vector3.ZERO, 20)
			_cyl(mv, 0.44, 0.44, 0.14, Vector3(0, 0.42, 0), steel, Vector3.ZERO, 24)
			_box(mv, Vector3(0.12, 0.16, 0.4), Vector3(0, 0.44, -0.22), yel)
			_bolts(mv, 4, 0.32, 0.5, dark, 0.04, 0.6)


## Suspension: `coil` (static spring), `rod` (unit-height, stretched) and `mov` (output plate).
static func _susp(f: Node3D, def: Dictionary, col: Color) -> void:
	var body := Blocks.block_mat(col.darkened(0.2), 0.4, 0.5)
	var cm := _m(col, 0.5, 0.35)
	var steel := _m(STEEL, 0.7, 0.3)
	var dark := _m(DARK, 0.6, 0.35)
	var rubber := _m(RUBBER, 0.0, 0.9)
	var coil := Blocks._node(f, "coil")
	var rod := Blocks._node(f, "rod", Vector3(0, 0.1, 0))
	var mv := Blocks._node(f, "mov")
	var rr := 0.08
	var plate := Vector3(0.7, 0.1, 0.7)
	match def.id:
		"spring":  # bare coil between two thin plates
			_cyl(f, 0.32, 0.32, 0.05, Vector3(0, -0.47, 0), dark, Vector3.ZERO, 20)
			_coil(coil, 0.28, 0.035, -0.44, 0.36, 7, cm)
			rr = 0.03
			plate = Vector3(0.66, 0.06, 0.66)
		"shock":  # coilover with piggyback reservoir
			_cyl(f, 0.09, 0.09, 0.12, Vector3(0, -0.4, 0), steel, RZ, 12)
			_cyl(f, 0.13, 0.13, 0.58, Vector3(0, -0.14, 0), dark, Vector3.ZERO, 16)
			_cyl(f, 0.25, 0.25, 0.04, Vector3(0, -0.36, 0), steel, Vector3.ZERO, 20)
			_coil(coil, 0.22, 0.03, -0.32, 0.3, 6, cm)
			_cyl(f, 0.08, 0.08, 0.46, Vector3(0.36, -0.14, 0), cm, Vector3.ZERO, 12)
			_cyl(f, 0.085, 0.085, 0.05, Vector3(0.36, 0.1, 0), dark, Vector3.ZERO, 12)
			_box(f, Vector3(0.24, 0.06, 0.06), Vector3(0.22, -0.34, 0), dark)
		"heavysusp":  # twin thick coils around a fat damper
			_box(f, Vector3(0.92, 0.14, 0.92), Vector3(0, -0.43, 0), body)
			_cyl(f, 0.12, 0.12, 0.5, Vector3(0, -0.14, 0), dark, Vector3.ZERO, 12)
			for x in [-0.25, 0.25]:
				_coil(coil, 0.17, 0.05, -0.34, 0.32, 5, cm, x)
			rr = 0.1
			plate = Vector3(0.9, 0.14, 0.9)
		"racesusp":  # short stiff coil with a threaded adjuster collar
			_box(f, Vector3(0.6, 0.08, 0.6), Vector3(0, -0.46, 0), body)
			_cyl(f, 0.12, 0.12, 0.4, Vector3(0, -0.24, 0), dark, Vector3.ZERO, 16)
			_cyl(f, 0.26, 0.26, 0.07, Vector3(0, -0.12, 0), steel, Vector3.ZERO, 20)
			_cyl(f, 0.25, 0.25, 0.04, Vector3(0, -0.18, 0), dark, Vector3.ZERO, 20)
			for i in 4:
				var a := i * TAU / 4.0
				_box(f, Vector3(0.05, 0.08, 0.06), Vector3(cos(a) * 0.26, -0.12, sin(a) * 0.26), dark, Vector3(0, -a, 0))
			_coil(coil, 0.22, 0.045, -0.06, 0.3, 4, cm)
			plate = Vector3(0.6, 0.08, 0.6)
		"longsusp":  # long thin damper, long slim coil
			_box(f, Vector3(0.4, 0.06, 0.4), Vector3(0, -0.47, 0), body)
			_cyl(f, 0.07, 0.07, 0.42, Vector3(0, -0.25, 0), dark, Vector3.ZERO, 12)
			_coil(coil, 0.17, 0.02, -0.44, 0.38, 10, cm)
			rr = 0.045
			plate = Vector3(0.5, 0.06, 0.5)
		"airsusp":  # rubber bellows bag with an air line
			_cyl(f, 0.3, 0.3, 0.08, Vector3(0, -0.46, 0), steel, Vector3.ZERO, 20)
			for y in [-0.24, 0.1]:
				Blocks._mi(coil, Blocks.sphere_mesh(0.34), Vector3(0, y, 0), rubber).scale = Vector3(1, 0.5, 1)
			Blocks._mi(coil, Blocks.torus_mesh(0.3, 0.35), Vector3(0, -0.07, 0), cm)
			_cyl(f, 0.03, 0.03, 0.2, Vector3(0.38, -0.44, 0), _m(col, 0.3, 0.5), RZ, 8)
			_cyl(f, 0.05, 0.05, 0.06, Vector3(0.26, -0.44, 0), steel, RZ, 8)
			rr = 0.05
		"leaf":  # stacked curved leaves, shackles and U-bolts
			_box(f, Vector3(0.4, 0.08, 0.3), Vector3(0, -0.46, 0), body)
			for i in 3:
				var ln := 0.92 - i * 0.24
				var y := -i * 0.05
				var lm := _m(col.darkened(i * 0.12), 0.5, 0.4)
				_box(coil, Vector3(0.24, 0.04, ln * 0.4), Vector3(0, y, 0), lm)
				var seg := ln * 0.31
				for s in [-1.0, 1.0]:
					var zc: float = s * (ln * 0.2 + seg * 0.5 * cos(0.3))
					_box(coil, Vector3(0.24, 0.04, seg), Vector3(0, y + seg * 0.5 * sin(0.3), zc), lm, Vector3(-s * 0.3, 0, 0))
			for z in [-0.44, 0.44]:
				_box(coil, Vector3(0.3, 0.18, 0.05), Vector3(0, 0.16, z), dark)
			for x in [-0.15, 0.15]:
				_cyl(f, 0.025, 0.025, 0.42, Vector3(x, -0.24, 0), steel, Vector3.ZERO, 8)
			_box(f, Vector3(0.36, 0.05, 0.14), Vector3(0, -0.06, 0), steel)
			rr = 0.05
			plate = Vector3(0.66, 0.08, 0.66)
		"pogo":  # one big spring, T-handle on top, rubber foot on the output
			_cyl(f, 0.18, 0.18, 0.1, Vector3(0, -0.44, 0), steel, Vector3.ZERO, 16)
			_cyl(f, 0.03, 0.03, 0.94, Vector3(0, -0.45, 0), steel, RZ, 8)
			for x in [-0.4, 0.4]:
				_cyl(f, 0.045, 0.045, 0.14, Vector3(x, -0.45, 0), _m(col, 0.1, 0.6), RZ, 10)
			_coil(coil, 0.34, 0.06, -0.36, 0.3, 4, cm)
			_cyl(mv, 0.36, 0.38, 0.08, Vector3(0, 0.34, 0), rubber, Vector3.ZERO, 20)
			rr = 0.06
			plate = Vector3(0.6, 0.06, 0.6)
		_:
			_box(f, Vector3(0.8, 0.12, 0.8), Vector3(0, -0.44, 0), body)
			_cyl(f, 0.14, 0.14, 0.5, Vector3(0, -0.18, 0), dark)
			for i in 5:
				Blocks._mi(coil, Blocks.torus_mesh(0.2, 0.27), Vector3(0, -0.3 + i * 0.14, 0), cm)
	_cyl(rod, rr, rr, 1.0, Vector3.ZERO, _m(CHROME, 0.95, 0.12))
	rod.scale = Vector3(1, 0.6, 1)
	_box(mv, plate, Vector3(0, 0.42, 0), _m(DARK, 0.4, 0.5))
	_stripes(mv, 0.475, 0.66)


## Decoupler: two halves joined by a red seam ring of explosive bolts.
static func _decoupler(r: Node3D, col: Color) -> void:
	var det := _glow(RED, 2.5)
	var steel := _m(STEEL, 0.7, 0.3)
	_box(r, Vector3(0.95, 0.42, 0.95), Vector3(0, -0.25, 0), _m(DARK, 0.4, 0.5))
	_box(r, Vector3(0.95, 0.42, 0.95), Vector3(0, 0.25, 0), Blocks.block_mat(col, 0.3, 0.5))
	_box(r, Vector3(1.0, 0.06, 1.0), Vector3.ZERO, _m(RED, 0.3, 0.5))
	for i in 8:
		var a := i * TAU / 8.0
		var p := Vector3(cos(a), 0, sin(a))
		p = p / maxf(absf(p.x), absf(p.z)) * 0.45
		_cyl(r, 0.045, 0.045, 0.34, p, steel, Vector3.ZERO, 6)
		Blocks._mi(r, Blocks.sphere_mesh(0.05), p + Vector3(0, 0.17, 0), det)
	Blocks._mi(r, Blocks.torus_mesh(0.3, 0.38), Vector3(0, 0.455, 0), _m(DARK, 0.5, 0.4))
	_bolts(r, 6, 0.34, 0.46, _m(YEL, 0.3, 0.4), 0.035)


# ---------------------------------------------------------------- structure

static func _solid(r: Node3D, def: Dictionary, col: Color) -> void:
	var s: Dictionary = def.get("surf", {})
	var metal: float = s.get("m", 0.1)
	var rough: float = s.get("r", 0.55)
	var shp: String = def.shape
	var deco: String = s.get("deco", "")
	var m: Material
	if s.has("a"):
		m = _m(Color(col.r, col.g, col.b, s.a), metal, rough)
	elif s.has("glow"):
		m = _glow(col, s.glow)
	elif shp == "box":
		m = Blocks.block_mat(col, metal, rough)
	else:
		m = _m(col, metal, rough)
	var dk := col.darkened(0.3)
	if deco == "truss":
		var t := _m(col, metal, rough)
		for a in [-0.45, 0.45]:
			for b in [-0.45, 0.45]:
				_box(r, Vector3(0.1, 1.0, 0.1), Vector3(a, 0, b), t)
				_box(r, Vector3(1.0, 0.1, 0.1), Vector3(0, a, b), t)
				_box(r, Vector3(0.1, 0.1, 1.0), Vector3(a, b, 0), t)
		for side in [-0.45, 0.45]:
			_box(r, Vector3(0.06, 1.3, 0.06), Vector3(side, 0, 0), t, Vector3(PI * 0.25, 0, 0))
			_box(r, Vector3(1.3, 0.06, 0.06), Vector3(0, 0, side), t, Vector3(0, 0, PI * 0.25))
		return
	if deco == "checker":
		for x in 2:
			for y in 2:
				for z in 2:
					var c := col if (x + y + z) % 2 == 0 else Color("#1d1f23")
					_box(r, Vector3.ONE * 0.5, Vector3(x - 0.5, y - 0.5, z - 0.5) * 0.5, Blocks.mat(c, 0.1, 0.5))
		return
	var sm: Array = Blocks.shape_mesh(shp)
	var mi := _mi(r, sm[0], sm[1], m)
	if s.has("a"):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shp != "box" and deco != "hull":
		return
	match deco:
		"planks":
			for i in 3:
				_box(r, Vector3(1.01, 0.03, 1.01), Vector3(0, -0.3 + i * 0.3, 0), _m(dk, 0.0, 0.9))
		"rivets":
			for x in [-0.33, 0.33]:
				for z in [-0.33, 0.33]:
					_cyl(r, 0.05, 0.05, 0.04, Vector3(x, 0.51, z), _m(STEEL, 0.8, 0.3), Vector3.ZERO, 8)
		"weave":
			for i in 4:
				_box(r, Vector3(1.006, 0.02, 1.006), Vector3(0, -0.36 + i * 0.24, 0), _m(col.lightened(0.15), 0.4, 0.3))
				_box(r, Vector3(0.02, 1.006, 1.006), Vector3(-0.36 + i * 0.24, 0, 0), _m(col.lightened(0.15), 0.4, 0.3))
		"ballast":
			for y in [-0.25, 0.25]:
				_box(r, Vector3(1.01, 0.08, 1.01), Vector3(0, y, 0), _m(dk, 0.5, 0.5))
			_box(r, Vector3(0.5, 0.2, 1.02), Vector3(0, 0, 0), _m(YEL, 0.2, 0.5))
		"bricks":
			for i in 3:
				_box(r, Vector3(1.01, 0.03, 1.01), Vector3(0, -0.25 + i * 0.25, 0), _m(col.lightened(0.25), 0, 0.95))
			for p in [Vector3(0, 0.37, 0), Vector3(-0.25, 0.12, 0), Vector3(0.25, 0.12, 0), Vector3(0, -0.12, 0), Vector3(-0.25, -0.37, 0), Vector3(0.25, -0.37, 0)]:
				_box(r, Vector3(0.03, 0.22, 1.01), p, _m(col.lightened(0.25), 0, 0.95))
		"stripes":
			for i in 3:
				_box(r, Vector3(1.01, 0.13, 1.01), Vector3(0, -0.32 + i * 0.32, 0), _m(Color("#1d1f23"), 0.1, 0.6))
		"crate":
			var e := _m(dk, 0.0, 0.9)
			for a in [-0.45, 0.45]:
				for b in [-0.45, 0.45]:
					_box(r, Vector3(0.12, 1.02, 0.12), Vector3(a, 0, b), e)
					_box(r, Vector3(1.02, 0.12, 0.12), Vector3(0, a, b), e)
					_box(r, Vector3(0.12, 0.12, 1.02), Vector3(a, b, 0), e)
		"rust":
			var rc := [Color("#a0522d"), Color("#6d4c41"), Color("#c1773a")]
			var pts := [Vector3(0.2, 0.3, 0.51), Vector3(-0.3, -0.1, 0.51), Vector3(0.51, 0.1, -0.2), Vector3(-0.51, -0.3, 0.2), Vector3(0.1, 0.51, -0.2), Vector3(-0.2, -0.51, 0.1)]
			for i in pts.size():
				var p: Vector3 = pts[i]
				var sz := Vector3(0.3, 0.25, 0.3)
				if absf(p.x) > 0.5: sz.x = 0.02
				if absf(p.y) > 0.5: sz.y = 0.02
				if absf(p.z) > 0.5: sz.z = 0.02
				_box(r, sz, p, _m(rc[i % 3], 0.3, 0.9))
		"bumper":
			_box(r, Vector3(1.01, 0.16, 1.01), Vector3(0, 0, 0), _m(YEL, 0.1, 0.7))
		"camo":
			var cc := [col.darkened(0.4), col.lightened(0.2), Color("#3e3a2a")]
			var pts := [Vector3(0.2, 0.2, 0.505), Vector3(-0.25, -0.2, 0.505), Vector3(0.505, 0.2, -0.1), Vector3(-0.505, -0.1, 0.25), Vector3(0.0, 0.505, 0.2), Vector3(-0.2, 0.505, -0.25), Vector3(0.25, -0.2, -0.505), Vector3(-0.1, 0.25, -0.505)]
			for i in pts.size():
				var p: Vector3 = pts[i]
				var sz := Vector3(0.45, 0.35, 0.45)
				if absf(p.x) > 0.5: sz.x = 0.01
				if absf(p.y) > 0.5: sz.y = 0.01
				if absf(p.z) > 0.5: sz.z = 0.01
				_box(r, sz, p, _m(cc[i % 3], 0.1, 0.8))
		"hull":
			if shp == "box":
				_box(r, Vector3(1.01, 0.35, 1.01), Vector3(0, -0.33, 0), _m(Color("#c62828"), 0.1, 0.5))
				_box(r, Vector3(1.012, 0.05, 1.012), Vector3(0, -0.13, 0), _m(Color("#1e88e5"), 0.1, 0.5))


# ---------------------------------------------------------------- wheels / wings / guns

static func wheel(r: Node3D, def: Dictionary, col: Color) -> void:
	var rad: float = def.radius
	var w: float = rad * 0.8 * float(def.get("wf", 1.0))
	if rad > 0.85:
		w = rad * 0.7
	var rim := col
	var spin := Blocks._node(r, "spin")
	_cyl(spin, rad, rad, w, Vector3.ZERO, _m(RUBBER, 0.0, 0.95), RZ, 24)
	if def.get("whitewall", false):
		for s in [-1, 1]:
			_cyl(spin, rad * 0.78, rad * 0.78, 0.01, Vector3(s * (w * 0.5 + 0.005), 0, 0), _m(Color("#f4f4f4"), 0.0, 0.6), RZ, 20)
	_cyl(spin, rad * 0.62, rad * 0.62, w + 0.02, Vector3.ZERO, _m(rim, 0.5, 0.35), RZ, 16)
	if def.get("glowrim", false):
		for s in [-1, 1]:
			Blocks._mi(spin, Blocks.torus_mesh(rad * 0.55, rad * 0.62), Vector3(s * (w * 0.5 + 0.02), 0, 0), _glow(rim, 3.0), Vector3(0, 0, PI * 0.5))
	_cyl(spin, rad * 0.2, rad * 0.2, w + 0.06, Vector3.ZERO, _m(STEEL, 0.8, 0.3), RZ, 10)
	for i in 3:
		var s := Blocks._node(spin, "s%d" % i)
		s.rotation.x = i * PI / 3.0
		_box(s, Vector3(w + 0.04, rad * 1.15, rad * 0.14), Vector3.ZERO, _m(rim.darkened(0.25), 0.5, 0.4))
	if def.get("slick", false):
		return
	var n := 10 if rad < 1.0 else 16
	for i in n:
		var t := Blocks._node(spin, "t%d" % i)
		t.rotation.x = i * TAU / n
		if def.get("spikes", false):
			_cyl(t, 0.0, 0.07, 0.22, Vector3(0, rad + 0.08, 0), _m(STEEL, 0.9, 0.2), Vector3.ZERO, 8)
		else:
			_box(t, Vector3(w * 0.9, 0.08 if rad < 1.0 else 0.14, rad * 0.22), Vector3(0, rad, 0), _m(RUBBER, 0.0, 1.0))


static func _wing(r: Node3D, def: Dictionary, col: Color) -> void:
	var m := _m(col, 0.2, 0.45)
	match def.get("style", ""):
		"small":
			_box(r, Vector3(1, 0.07, 0.6), Vector3(0, 0, -0.1), m)
			_cyl(r, 0.05, 0.05, 1.0, Vector3(0, 0, -0.4), m, RZ, 10)
		"thick":
			_box(r, Vector3(1, 0.2, 0.9), Vector3(0, 0, 0.05), m)
			_cyl(r, 0.1, 0.1, 1.0, Vector3(0, 0, -0.42), m, RZ, 12)
			_box(r, Vector3(1.0, 0.06, 0.14), Vector3(0, 0, 0.48), _m(col.darkened(0.2), 0.2, 0.5))
		"swept":
			_box(r, Vector3(1.05, 0.09, 0.62), Vector3(0, 0, 0.12), m, Vector3(0, 0.45, 0))
			_box(r, Vector3(0.6, 0.09, 0.4), Vector3(-0.15, 0, -0.25), m)
		"delta":
			var key := "deltawing"
			var pts := [Vector3(-0.5, -0.05, 0.5), Vector3(0.5, -0.05, 0.5), Vector3(-0.5, -0.05, -0.5), Vector3(-0.5, 0.05, 0.5), Vector3(0.5, 0.05, 0.5), Vector3(-0.5, 0.05, -0.5)]
			var faces := [[0, 1, 2], [3, 4, 5], [0, 1, 4, 3], [1, 2, 5, 4], [0, 2, 5, 3]]
			_mi(r, Blocks.poly_mesh(key, pts, faces), Vector3.ZERO, m)
		"glider":
			_box(r, Vector3(1, 0.05, 0.7), Vector3(0, 0, 0.0), m)
			_cyl(r, 0.04, 0.04, 1.0, Vector3(0, 0, -0.35), m, RZ, 8)
		"fin":
			_box(r, Vector3(0.1, 1.0, 0.85), Vector3(0, 0, 0.05), m)
			_cyl(r, 0.06, 0.06, 1.0, Vector3(0, 0, -0.4), m, Vector3.ZERO, 8)
		"winglet":
			_box(r, Vector3(0.08, 0.7, 0.6), Vector3(0, 0.1, 0.1), m, Vector3(0.3, 0, 0))
			_box(r, Vector3(0.5, 0.08, 0.6), Vector3(0, -0.3, 0.1), _m(DARK, 0.3, 0.5))


static func gun(r: Node3D, def: Dictionary, col: Color) -> void:
	var lk: Dictionary = def.get("look", {})
	var body: Vector3 = lk.get("body", Vector3(0.4, 0.36, 0.7))
	var n: int = lk.get("n", 1)
	var blen: float = lk.get("len", 1.0)
	var brad: float = lk.get("rad", 0.06)
	_box(r, Vector3(0.3, 0.15, 0.3), Vector3(0, -0.4, 0), _m(DARK, 0.5, 0.4))
	_box(r, body, Vector3(0, -0.1, 0.12), _m(col, 0.6, 0.35))
	var holder: Node3D = Blocks._node(r, "spin", Vector3(0, -0.06, -0.2 - blen * 0.5)) if lk.get("spin", false) else Blocks._node(r, "barrels", Vector3(0, -0.06, -0.2 - blen * 0.5))
	if n == 1:
		_cyl(holder, brad, brad, blen, Vector3.ZERO, _m(DARK, 0.8, 0.3), RX, 10)
		_cyl(holder, brad * 1.5, brad * 1.5, 0.14, Vector3(0, 0, -blen * 0.5), _m(DARK, 0.8, 0.3), RX, 10)
	elif n == 2:
		for x in [-0.1, 0.1]:
			_cyl(holder, brad, brad, blen, Vector3(x, 0, 0), _m(DARK, 0.8, 0.3), RX, 10)
	else:
		for i in n:
			var a := i * TAU / n
			_cyl(holder, brad, brad, blen, Vector3(cos(a), sin(a), 0) * 0.1, _m(DARK, 0.8, 0.3), RX, 8)
		Blocks._mi(holder, Blocks.torus_mesh(0.1, 0.16), Vector3(0, 0, -blen * 0.4), _m(STEEL, 0.8, 0.3), RX)
	if lk.get("scope", false):
		_cyl(r, 0.07, 0.07, 0.5, Vector3(0, 0.15, 0.0), _m(DARK, 0.6, 0.3), RX, 10)
		_cyl(r, 0.06, 0.06, 0.01, Vector3(0, 0.15, -0.255), _glow(Color("#7fe7ff"), 2.0), RX, 10)
