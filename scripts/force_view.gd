extends Node3D
## Garage overlay that shows what every working part does: lift and downforce
## arrows on wings, thrust arrows on engines and rockets, vertical lift on rotors,
## hover pads and balloons, wheel drive force from the engines, the centre of
## thrust, and animated airflow streaks that bend around the blocks, get pushed
## down behind lifting wings and blown back by engines.
## Forces use the same formulas as vehicle.gd, at the chosen air speed.

const FWD := Vector3(0, 0, -1)
const SPEEDS_KMH := [80, 150, 250, 400]
const FLOW_N := 110
const TRAIL := 9
const COL_LIFT := Color("#3fd6ff")
const COL_DOWN := Color("#c05cff")
const COL_THRUST := Color("#ff9a1f")
const COL_BOOST := Color("#ff4f5e")
const COL_VERT := Color("#3ddc84")
const COL_DRIVE := Color("#ffd23f")
const COL_FLAP := Color("#7fe7ff")

var speed_idx := 1
## Numbers for the garage panel, filled by update().
var summary := {}

var _arrows: Node3D
var _flow_mesh: MeshInstance3D
var _flow_im: ImmediateMesh
var _mats := {}
var _solid := {}      # Vector3i -> true for every cell a block covers
var _push := {}       # Vector3i -> [push direction, strength, tint] (wings, engines, rotors)
var _box := AABB()
var _flow: Array = [] # [pos, vel, tint, trail PackedVector3Array]


func _ready() -> void:
	_arrows = Node3D.new()
	add_child(_arrows)
	_flow_im = ImmediateMesh.new()
	_flow_mesh = MeshInstance3D.new()
	_flow_mesh.mesh = _flow_im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 1
	_flow_mesh.material_override = m
	_flow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flow_mesh)


func air_speed() -> float:
	return SPEEDS_KMH[speed_idx] / 3.6


func cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % SPEEDS_KMH.size()


func _mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.render_priority = 2
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


static func fmt_force(n: float) -> String:
	return "%.1f kN" % (n / 1000.0) if absf(n) >= 1000.0 else "%d N" % int(n)


## Arrow from `from` along `dir` sized by `newtons`, with a label at the tip.
func _arrow(from: Vector3, dir: Vector3, newtons: float, col: Color, text: String) -> void:
	if dir.length_squared() < 0.0001 or newtons <= 0.0:
		return
	var len := clampf(0.5 + sqrt(newtons / 1000.0) * 0.8, 0.5, 6.0)
	var n := Node3D.new()
	_arrows.add_child(n)
	n.transform = Transform3D(Fx.basis_up(dir), from)
	var m := _mat(Color(col, 0.92))
	var shaft := len - 0.32
	var s := Blocks._mi(n, Blocks.cyl_mesh(0.05, 0.05, shaft, 8), Vector3(0, shaft * 0.5, 0), m)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var h := Blocks._mi(n, Blocks.cyl_mesh(0.0, 0.15, 0.32, 10), Vector3(0, len - 0.16, 0), m)
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if text != "":
		var l := Label3D.new()
		l.text = text
		l.font_size = 32
		l.pixel_size = 0.006
		l.outline_size = 8
		l.modulate = col
		l.no_depth_test = true
		l.render_priority = 3
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = from + dir.normalized() * (len + 0.25)
		_arrows.add_child(l)


func _ring(at: Vector3, col: Color, text: String) -> void:
	var m := _mat(col)
	var r := Blocks._mi(_arrows, Blocks.torus_mesh(0.42, 0.52), at, m)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := Label3D.new()
	l.text = text
	l.font_size = 32
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = col
	l.no_depth_test = true
	l.render_priority = 3
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at + Vector3(0, 0.6, 0)
	_arrows.add_child(l)


## Rebuilds the arrows, the flow obstacles and the summary for `d`.
func update(d: Dictionary) -> void:
	for c in _arrows.get_children():
		c.queue_free()
	_solid.clear()
	_push.clear()
	var v := air_speed()
	var st := Designs.stats(d)
	var weight: float = st.mass * 9.8
	var thrust := 0.0
	var boost := 0.0
	var vert := 0.0
	var cot := Vector3.ZERO
	var cot_dir := Vector3.ZERO
	var drive_cap := 0.0
	var driven: Array = []
	var first := true
	for b in d.blocks:
		var def: Dictionary = Blocks.defs.get(b.id, {})
		if def.is_empty():
			continue
		var bas := Blocks.basis_of(b)
		var ctr := Blocks.center_of(b)
		var box := Blocks.cell_box(b)
		_box = box if first else _box.merge(box)
		first = false
		for x in range(roundi(box.position.x + 0.01), roundi(box.end.x - 0.01) + 1):
			for y in range(roundi(box.position.y + 0.01), roundi(box.end.y - 0.01) + 1):
				for z in range(roundi(box.position.z + 0.01), roundi(box.end.z - 0.01) + 1):
					_solid[Vector3i(x, y, z)] = true
		var cfg: Dictionary = def.cfg.duplicate()
		cfg.merge(b.get("cfg", {}), true)
		var pw: float = cfg.get("pow", 100) / 100.0
		match def.kind:
			"wing":
				var k: float = def.get("lift", 0.0)
				if absf(k) < 0.001:
					continue
				var along := maxf((bas * FWD).dot(FWD), 0.0)
				var f := absf(k) * along * along * v * v
				# the force acts along the normal, flipped for negative-lift wings
				var fdir: Vector3 = (bas * def.get("nrm", Vector3.UP)) * signf(k)
				var down := fdir.y < -0.3
				_arrow(ctr, fdir, f, COL_DOWN if down else COL_LIFT, fmt_force(f))
				_solid.erase(Vector3i(roundi(ctr.x), roundi(ctr.y), roundi(ctr.z)))
				_mark_push(ctr, -fdir, clampf(absf(k) / 0.3, 0.3, 2.0), 3 if down else 1, 1)
			"flap":
				var nrm: Vector3 = bas * def.get("nrm", Vector3.UP)
				var f: float = def.get("fp", 1.4) * v * v * pw
				_arrow(ctr, nrm, f * 0.5, COL_FLAP, "")
				_arrow(ctr, -nrm, f * 0.5, COL_FLAP, "steer " + fmt_force(f))
			"engine":
				var dir: Vector3 = bas * def.get("tdir", FWD)
				var t: float = def.thrust * pw
				var is_boost: bool = cfg.get("ch", "") == "boost"
				if def.get("lift_only", false):
					vert += t
					_arrow(ctr, dir, t, COL_VERT, fmt_force(t))
				elif is_boost:
					boost += t
					_arrow(ctr, dir, t, COL_BOOST, "boost " + fmt_force(t))
				else:
					thrust += t
					cot += ctr * t
					cot_dir += dir * t
					var txt := fmt_force(t)
					if def.has("afterburn"):
						txt += " (x%.1f on Shift)" % def.afterburn
					_arrow(ctr, dir, t, COL_THRUST, txt)
				_mark_push(ctr - dir, -dir, 3.0, 2, 4)
			"rotor":
				var t: float = def.thrust * pw
				vert += t
				_arrow(ctr, bas.y, t, COL_VERT, fmt_force(t))
				_mark_push(ctr - bas.y, -bas.y, 2.5, 2, 3)
			"hover":
				var t: float = def.force * pw
				vert += t
				_arrow(ctr, bas.y, t, COL_VERT, "hover " + fmt_force(t))
			"balloon":
				var t: float = def.lift * pw
				vert += t
				_arrow(ctr, Vector3.UP, t, COL_VERT, fmt_force(t))
			"wheel":
				if def.has("kw"):
					var f: float = minf(def.drive * 1.6, def.kw * 1000.0 / 8.0) * pw
					_arrow(ctr, FWD, f, COL_DRIVE, "hub " + fmt_force(f))
				elif cfg.get("drive", true) and def.get("drive", 0.0) > 0.0:
					var cap: float = def.drive * 1.6 * pw
					drive_cap += cap
					driven.append([ctr, cap])
			"motor":
				_ring(ctr + Vector3(0, 0.75, 0), COL_DRIVE, "%d kW" % int(def.kw * pw))
	# engine force reaching each driven wheel from a standstill
	var kw: float = st.engine_kw
	var wheel_force := 0.0
	if drive_cap > 0.0 and kw > 0.0:
		wheel_force = minf(drive_cap, kw * 1000.0 / 5.0)
		for w in driven:
			_arrow(w[0], FWD, wheel_force * w[1] / drive_cap, COL_DRIVE, fmt_force(wheel_force * w[1] / drive_cap))
	# centre of thrust and how far the thrust line misses the centre of mass
	var offset := 0.0
	if thrust > 0.0:
		cot /= thrust
		var td := cot_dir.normalized()
		var rel: Vector3 = st.com - cot
		offset = (rel - td * rel.dot(td)).y
		var m := _mat(COL_THRUST)
		var dot := Blocks._mi(_arrows, Blocks.sphere_mesh(0.2), cot, m)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var line := Blocks._mi(_arrows, Blocks.cyl_mesh(0.025, 0.025, 30.0, 6), Vector3.ZERO, _mat(Color(COL_THRUST, 0.5)))
		line.transform = Transform3D(Fx.basis_up(td), cot)
	summary = {
		"speed_kmh": SPEEDS_KMH[speed_idx], "weight": weight, "lift": st.lift_coef * v * v, "down": st.down_coef * v * v,
		"takeoff_kmh": sqrt(weight / st.lift_coef) * 3.6 if st.lift_coef > 0.0 else 0.0,
		"thrust": thrust, "boost": boost, "vert": vert, "engine_kw": kw + st.hub_kw, "wheel_force": wheel_force,
		"thrust_offset": offset, "driven": st.driven,
	}
	_reset_flow()


## Air passing through cells behind/around `at` gets pushed along `dir`.
func _mark_push(at: Vector3, dir: Vector3, strength: float, tint: int, reach: int) -> void:
	for k in reach:
		var p := at + dir * float(k)
		var key := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
		_push[key] = [dir.normalized(), strength * (1.0 - float(k) / reach * 0.5), tint]


## Human-readable lines for the garage panel.
func summary_text() -> String:
	var s := summary
	if s.is_empty():
		return ""
	var lines := []
	var w: float = s.weight
	var air := []
	if s.lift > 0.0:
		air.append("wing lift %s (%d%% of weight)" % [fmt_force(s.lift), int(s.lift / maxf(w, 1.0) * 100.0)])
	if s.down > 0.0:
		air.append("downforce %s" % fmt_force(s.down))
	if not air.is_empty():
		lines.append("At %d km/h: %s" % [s.speed_kmh, ", ".join(air)])
	if s.takeoff_kmh > 0.0:
		lines.append("Wings carry the weight from about %d km/h" % int(s.takeoff_kmh))
	if s.thrust > 0.0:
		lines.append("Thrust %s (thrust/weight %.2f)" % [fmt_force(s.thrust), s.thrust / maxf(w, 1.0)])
	if s.boost > 0.0:
		lines.append("Boost %s on Shift (%.2f with thrust)" % [fmt_force(s.boost), (s.thrust + s.boost) / maxf(w, 1.0)])
	if absf(s.thrust_offset) > 0.35:
		lines.append("Thrust line %.1f m %s the centre of mass: %s" % [absf(s.thrust_offset),
			"above" if s.thrust_offset < 0.0 else "below", "noses down under power" if s.thrust_offset < 0.0 else "noses up under power"])
	if s.vert > 0.0:
		lines.append("Vertical lift %s (%d%% of weight)" % [fmt_force(s.vert), int(s.vert / maxf(w, 1.0) * 100.0)])
	if s.engine_kw > 0.0:
		lines.append("Engines %d kW: %s at the wheels from a standstill" % [int(s.engine_kw), fmt_force(s.wheel_force)])
	elif s.driven > 0:
		lines.append("No engine: the driven wheels will not turn")
	if lines.is_empty():
		lines.append("Weight %s. Add wings, engines or wheels to see their forces." % fmt_force(w))
	return "\n".join(lines)


# ---------------------------------------------------------------- airflow

func _reset_flow() -> void:
	_flow.clear()
	for i in FLOW_N:
		_flow.append(_spawn_particle(randf()))


func _spawn_particle(progress: float) -> Array:
	var b := _box.grow(1.5)
	var p := Vector3(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y),
		lerpf(b.position.z - 1.0, b.end.z + 2.0, progress))
	var trail := PackedVector3Array()
	trail.resize(TRAIL)
	trail.fill(p)
	return [p, Vector3(0, 0, _flow_speed()), 0, trail, 0.0]


func _flow_speed() -> float:
	return 3.0 + air_speed() * 0.06


func _process(delta: float) -> void:
	if not visible or _flow.is_empty():
		return
	delta = minf(delta, 0.05)
	var free_v := Vector3(0, 0, _flow_speed())
	var end_z := _box.end.z + 3.0
	for i in _flow.size():
		var f: Array = _flow[i]
		var p: Vector3 = f[0]
		var vel: Vector3 = f[1]
		vel = vel.lerp(free_v, clampf(delta * 1.2, 0.0, 1.0))
		var key := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
		if _solid.has(key):
			# flow around the body: over the top, a little to the side
			vel.y += 22.0 * delta
			vel.x += signf(p.x + 0.001) * 6.0 * delta
		if _push.has(key):
			var pu: Array = _push[key]
			vel += (pu[0] as Vector3) * float(pu[1]) * 9.0 * delta
			f[2] = pu[2]
			f[4] = 1.0
		f[4] = maxf(0.0, float(f[4]) - delta * 0.6)
		p += vel * delta
		f[0] = p
		f[1] = vel
		var trail: PackedVector3Array = f[3]
		for k in range(TRAIL - 1, 0, -1):
			trail[k] = trail[k - 1]
		trail[0] = p
		f[3] = trail
		if p.z > end_z or absf(p.y - _box.get_center().y) > _box.size.y + 8.0:
			_flow[i] = _spawn_particle(0.0)
	_draw_flow()


func _draw_flow() -> void:
	_flow_im.clear_surfaces()
	_flow_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for f in _flow:
		var trail: PackedVector3Array = f[3]
		var heat: float = f[4]
		var base := Color(0.85, 0.93, 1.0)
		match int(f[2]):
			1: base = base.lerp(COL_LIFT, heat)
			2: base = base.lerp(COL_THRUST, heat)
			3: base = base.lerp(COL_DOWN, heat)
		for k in TRAIL - 1:
			var a := 0.75 * (1.0 - float(k) / TRAIL)
			_flow_im.surface_set_color(Color(base, a))
			_flow_im.surface_add_vertex(trail[k])
			_flow_im.surface_set_color(Color(base, a * 0.8))
			_flow_im.surface_add_vertex(trail[k + 1])
	_flow_im.surface_end()
