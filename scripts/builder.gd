extends Node3D
## The garage: building with ghost preview, mirror mode, paint, per-block
## configuration, undo/redo and an orbit camera. Blocks snap flush against the
## face you point at, so they sit on half blocks, plates, resized blocks and
## blocks turned 45 degrees. Each block is stored under a unique key cell `p`
## plus an optional centre offset `o`, size `s` and free rotation `q`.

signal changed
signal selected(cell: Variant)
signal message(text: String)

const MAX_BLOCKS := 400
const SIZE_MIN := 0.25
const SIZE_MAX := 8.0

var design_name := "My Vehicle"
var cells := {}            # Vector3i key -> block dict
var nodes := {}            # Vector3i key -> StaticBody3D
var block_id := "cube"
var rot := Basis.IDENTITY  # orientation of the block being placed
var rot_step := 45.0       # degrees per R / T / F press (G toggles 45 / 90)
var size := Vector3.ONE    # size of resizable blocks being placed
var tool := "build"        # build | paint | config
var mirror := true
var paint_color: Variant = null   # Color or null = block default
var selected_cell: Variant = null
var active := true

var cam: Camera3D
var yaw := -0.7
var pitch := -0.45
var dist := 14.0
var focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO

var _ghost: Node3D
var _ghost_m: Node3D
var _ghost_id := ""
var _ghost_ok := -1
var _ghost_m_ok := -1
var _hover_box: Node3D
var _sel_box: Node3D
var _mirror_plane: MeshInstance3D
var _com_marker: Node3D
var _col_marker: Node3D
var _loose_root: Node3D
var _floor: MeshInstance3D
var _mouse := Vector2.ZERO
var _hover_cell: Variant = null
var _target: Variant = null    # [centre: Vector3, basis: Basis] where the next block goes
var _press_pos := {}
var _undo: Array = []
var _redo: Array = []


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	add_child(cam)
	_build_floor()
	_hover_box = _wire_box(Color(1, 1, 1, 0.9), 1.04)
	_sel_box = _wire_box(Color("#ffd23f"), 1.08)
	_sel_box.visible = false
	var pm := QuadMesh.new()
	pm.size = Vector2(14, 8)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.3, 0.8, 1.0, 0.035)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mirror_plane = MeshInstance3D.new()
	_mirror_plane.mesh = pm
	_mirror_plane.material_override = mm
	_mirror_plane.rotation.y = PI * 0.5
	_mirror_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mirror_plane)
	_com_marker = _marker(Color("#ffd23f"), "MASS", 0.5)
	_col_marker = _marker(Color("#3fd6ff"), "LIFT", -0.45)
	_loose_root = Node3D.new()
	add_child(_loose_root)
	load_design(Designs.empty_design(), false)


func _build_floor() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec4 base : source_color = vec4(0.13, 0.15, 0.19, 1.0);
uniform vec4 line : source_color = vec4(0.3, 0.75, 1.0, 1.0);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wp.xz) - 0.5) / fwidth(wp.xz);
	float l = 1.0 - min(min(g.x, g.y), 1.0);
	vec2 w5 = (wp.xz + 0.5) / 5.0;
	vec2 g5 = abs(fract(w5) - 0.5) / fwidth(w5);
	float l5 = 1.0 - min(min(g5.x, g5.y), 1.0);
	float fade = 1.0 - smoothstep(8.0, 34.0, length(wp.xz));
	float ring = smoothstep(0.3, 0.0, abs(length(wp.xz) - 30.0));
	ALBEDO = mix(base.rgb, line.rgb, clamp(max(l * 0.18, l5 * 0.45) * fade + ring * 0.6, 0.0, 1.0));
	ROUGHNESS = 0.7;
	METALLIC = 0.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var cm := CylinderMesh.new()
	cm.top_radius = 34
	cm.bottom_radius = 35
	cm.height = 0.4
	cm.radial_segments = 64
	_floor = MeshInstance3D.new()
	_floor.mesh = cm
	_floor.material_override = m
	add_child(_floor)


func _wire_box(col: Color, s: float) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 2
	var h := s * 0.5
	var t := 0.035
	for a in 3:
		for i in [-1, 1]:
			for j in [-1, 1]:
				var sz := Vector3(t, t, t)
				var pos := Vector3.ZERO
				match a:
					0:
						sz.x = s
						pos = Vector3(0, i * h, j * h)
					1:
						sz.y = s
						pos = Vector3(i * h, 0, j * h)
					2:
						sz.z = s
						pos = Vector3(i * h, j * h, 0)
				var mi := Blocks._mi(n, Blocks.box_mesh(sz), pos, m)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.visible = false
	return n


func _marker(col: Color, text: String, label_y: float) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 3
	Blocks._mi(n, Blocks.sphere_mesh(0.22), Vector3.ZERO, m)
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.outline_size = 10
	l.modulate = col
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, label_y, 0)
	l.pixel_size = 0.006
	n.add_child(l)
	add_child(n)
	return n


# ---------------------------------------------------------------- geometry

## Transform that maps a unit box at the origin onto block `b`'s tight box.
func _box_xform(b: Dictionary) -> Transform3D:
	var bs := Blocks.basis_of(b)
	var bx := Blocks.local_box(b.id, Blocks.size_of(b))
	return Transform3D(bs * Basis.from_scale(bx.size), Blocks.center_of(b) + bs * bx.get_center())


## [centre, basis, half extents] of the tight box of `id` placed at `center`.
func _obb(id: String, center: Vector3, basis: Basis, sz: Vector3) -> Array:
	var bx := Blocks.local_box(id, sz)
	return [center + basis * bx.get_center(), basis, bx.size * 0.5]


## Separating-axis test between two oriented boxes, shrunk slightly so
## blocks that only share a face don't count as overlapping.
static func _obb_overlap(a: Array, b: Array) -> bool:
	var ca: Vector3 = a[0]
	var cb: Vector3 = b[0]
	var A: Basis = a[1]
	var B: Basis = b[1]
	var ha: Vector3 = (a[2] - Vector3.ONE * 0.03).max(Vector3.ONE * 0.005)
	var hb: Vector3 = (b[2] - Vector3.ONE * 0.03).max(Vector3.ONE * 0.005)
	var d := cb - ca
	if d.length() > ha.length() + hb.length():
		return false
	var ax_a := [A.x, A.y, A.z]
	var ax_b := [B.x, B.y, B.z]
	var axes := ax_a + ax_b
	for u: Vector3 in ax_a:
		for v: Vector3 in ax_b:
			var c := u.cross(v)
			if c.length_squared() > 0.000001:
				axes.append(c.normalized())
	for ax: Vector3 in axes:
		var ra := ha.x * absf(A.x.dot(ax)) + ha.y * absf(A.y.dot(ax)) + ha.z * absf(A.z.dot(ax))
		var rb := hb.x * absf(B.x.dot(ax)) + hb.y * absf(B.y.dot(ax)) + hb.z * absf(B.z.dot(ax))
		if absf(d.dot(ax)) > ra + rb:
			return false
	return true


func _place_size(id: String) -> Vector3:
	return size if Blocks.resizable(id) else Vector3.ONE


func _place_basis(id: String, basis: Basis) -> Basis:
	return Basis.IDENTITY if Blocks.defs[id].auto_rot else basis


## Unused key cell nearest to `center`.
func _free_key(center: Vector3) -> Vector3i:
	var k := Vector3i(center.round())
	if not cells.has(k):
		return k
	for r in range(1, 12):
		var best := Vector3i.MAX
		var bd := INF
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					if maxi(absi(x), maxi(absi(y), absi(z))) != r:
						continue
					var c := k + Vector3i(x, y, z)
					var dd := Vector3(c).distance_squared_to(center)
					if not cells.has(c) and dd < bd:
						bd = dd
						best = c
		if best != Vector3i.MAX:
			return best
	return k


## Key of the block mirrored across X from block `c` (same type), or null.
func _mirror_key(c: Vector3i) -> Variant:
	if not cells.has(c):
		return null
	var b: Dictionary = cells[c]
	var m := Blocks.center_of(b) * Vector3(-1, 1, 1)
	if absf(m.x) < 0.01:
		return null
	for k in cells:
		if k != c and cells[k].id == b.id and Blocks.center_of(cells[k]).distance_to(m) < 0.02:
			return k
	return null


func _with_mirror(c: Vector3i) -> Array:
	var out := [c]
	if mirror:
		var mk = _mirror_key(c)
		if mk != null:
			out.append(mk)
	return out


# ---------------------------------------------------------------- design io

func load_design(d: Dictionary, record := true) -> void:
	if record:
		_push_undo()
	for c in nodes:
		nodes[c].queue_free()
	nodes.clear()
	cells.clear()
	design_name = d.get("name", "My Vehicle")
	for b in d.get("blocks", []):
		if not Blocks.defs.has(b.id):
			continue
		var c := Designs.cell_of(b)
		if cells.has(c):
			continue
		var nb := {"id": b.id, "p": [c.x, c.y, c.z], "r": int(b.get("r", 0)), "c": b.get("c", ""), "cfg": b.get("cfg", {}).duplicate()}
		for k in ["o", "s", "q"]:
			if b.has(k):
				nb[k] = b[k].duplicate()
		cells[c] = nb
		_spawn_node(c)
	if not _has_seat():
		var s := {"id": "seat", "p": [0, 0, 0], "r": 0, "c": "", "cfg": {}}
		cells[Vector3i.ZERO] = s
		_spawn_node(Vector3i.ZERO)
	_select(null)
	_refresh()
	_focus_goal = _center()
	dist = clampf(_radius() * 2.6 + 6.0, 8.0, 40.0)


func to_design() -> Dictionary:
	var blocks := []
	for c in cells:
		blocks.append(cells[c].duplicate(true))
	return {"name": design_name, "blocks": blocks}


func _has_seat() -> bool:
	for c in cells:
		if cells[c].id == "seat":
			return true
	return false


func _center() -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for c in cells:
		var p := Blocks.center_of(cells[c])
		lo = lo.min(p)
		hi = hi.max(p)
	return (lo + hi) * 0.5


func _radius() -> float:
	var r := 1.0
	var cc := _center()
	for c in cells:
		r = maxf(r, Blocks.center_of(cells[c]).distance_to(cc))
	return r


func _spawn_node(c: Vector3i) -> void:
	var b: Dictionary = cells[c]
	var def: Dictionary = Blocks.defs[b.id]
	var bs := Blocks.basis_of(b)
	var sz := Blocks.size_of(b)
	var body := StaticBody3D.new()
	body.collision_layer = Fx.L_BUILD
	body.collision_mask = 0
	body.transform = Transform3D(bs, Blocks.center_of(b))
	body.set_meta("cell", c)
	var cs := CollisionShape3D.new()
	var bx := Blocks.local_box(b.id, sz)
	var shape := BoxShape3D.new()
	shape.size = bx.size
	cs.shape = shape
	cs.position = bx.get_center()
	body.add_child(cs)
	var col: Color = Color(b.c) if b.c != "" else def.color
	var vis := Blocks.make_visual(b.id, col)
	vis.scale = sz
	for ln in ["lamp", "lamp1", "lamp2"]:
		var lamp := vis.find_child(ln, true, false)
		if lamp:
			lamp.queue_free()
	body.add_child(vis)
	add_child(body)
	nodes[c] = body


func _respawn_node(c: Vector3i) -> void:
	if nodes.has(c):
		nodes[c].queue_free()
		nodes.erase(c)
	if cells.has(c):
		_spawn_node(c)


# ---------------------------------------------------------------- editing

func _push_undo() -> void:
	_undo.append(to_design())
	if _undo.size() > 80:
		_undo.pop_front()
	_redo.clear()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(to_design())
	load_design(_undo.pop_back(), false)
	message.emit("Undo")


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(to_design())
	load_design(_redo.pop_back(), false)
	message.emit("Redo")


func can_place_at(id: String, center: Vector3, basis: Basis) -> bool:
	if id == "seat":
		return false
	var me := _obb(id, center, _place_basis(id, basis), _place_size(id))
	for k in cells:
		var b: Dictionary = cells[k]
		if _obb_overlap(me, _obb(b.id, Blocks.center_of(b), Blocks.basis_of(b), Blocks.size_of(b))):
			return false
	return true


## Places the current block on the grid cell `c` with the current rotation and size.
func place(c: Vector3i) -> void:
	place_at(Vector3(c), rot)


func place_at(center: Vector3, basis: Basis) -> void:
	if not can_place_at(block_id, center, basis):
		if block_id == "seat":
			message.emit("Only one pilot seat allowed")
		return
	if cells.size() >= MAX_BLOCKS:
		message.emit("Block limit reached (%d)" % MAX_BLOCKS)
		return
	_push_undo()
	var k := _add(center, basis, block_id)
	var mc := center * Vector3(-1, 1, 1)
	var mb := Blocks.mirror_basis(basis)
	if mirror and absf(center.x) > 0.01 and can_place_at(block_id, mc, mb):
		_add(mc, mb, block_id)
	Sfx.play("place", null, -6.0, randf_range(0.9, 1.15))
	_pop(k)
	_refresh()


func _add(center: Vector3, basis: Basis, id: String) -> Vector3i:
	var k := _free_key(center)
	var b := {"id": id, "p": [k.x, k.y, k.z], "r": 0, "c": paint_color.to_html(false) if paint_color != null else "",
		"cfg": Blocks.defs[id].cfg.duplicate()}
	Blocks.set_basis(b, _place_basis(id, basis))
	var o := center - Vector3(k)
	if o.length() > 0.0005:
		b.o = [snappedf(o.x, 0.0001), snappedf(o.y, 0.0001), snappedf(o.z, 0.0001)]
	var sz := _place_size(id)
	if not sz.is_equal_approx(Vector3.ONE):
		b.s = [sz.x, sz.y, sz.z]
	cells[k] = b
	_spawn_node(k)
	return k


func _pop(c: Vector3i) -> void:
	if nodes.has(c):
		var n: Node3D = nodes[c].get_child(1)
		var full := n.scale
		n.scale = full * 0.6
		n.create_tween().tween_property(n, "scale", full, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func remove(c: Vector3i) -> void:
	if not cells.has(c):
		return
	if cells[c].id == "seat":
		message.emit("The pilot seat can't be removed")
		return
	_push_undo()
	for cc in _with_mirror(c):
		if cells.has(cc) and cells[cc].id != "seat":
			cells.erase(cc)
			if nodes.has(cc):
				nodes[cc].queue_free()
				nodes.erase(cc)
	if selected_cell != null and not cells.has(selected_cell):
		_select(null)
	Sfx.play("remove", null, -6.0)
	_refresh()


func paint(c: Vector3i) -> void:
	if not cells.has(c):
		return
	var hex: String = paint_color.to_html(false) if paint_color != null else ""
	if cells[c].c == hex:
		return
	_push_undo()
	for cc in _with_mirror(c):
		cells[cc].c = hex
		_respawn_node(cc)
	Sfx.play("click", null, -8.0, 1.3)
	changed.emit()


func set_cfg(c: Vector3i, key: String, value: Variant) -> void:
	if not cells.has(c):
		return
	_push_undo()
	for cc in _with_mirror(c):
		cells[cc].cfg[key] = value
	changed.emit()


func apply_cfg_to_all(c: Vector3i) -> int:
	if not cells.has(c):
		return 0
	_push_undo()
	var n := 0
	for cc in cells:
		if cc != c and cells[cc].id == cells[c].id:
			cells[cc].cfg = cells[c].cfg.duplicate()
			n += 1
	return n


static func clamp_size(v: Vector3) -> Vector3:
	return v.snapped(Vector3.ONE * 0.25).clamp(Vector3.ONE * SIZE_MIN, Vector3.ONE * SIZE_MAX)


## Size used for the next resizable block (and its ghost).
func set_size(v: Vector3) -> void:
	size = clamp_size(v)
	changed.emit()


## Resizes a placed block (and its mirror twin) in place.
func resize_block(c: Vector3i, v: Vector3) -> void:
	if not cells.has(c) or not Blocks.resizable(cells[c].id):
		return
	v = clamp_size(v)
	if v.is_equal_approx(Blocks.size_of(cells[c])):
		return
	_push_undo()
	for cc in _with_mirror(c):
		if v.is_equal_approx(Vector3.ONE):
			cells[cc].erase("s")
		else:
			cells[cc].s = [v.x, v.y, v.z]
		_respawn_node(cc)
	_select(c)
	_refresh()


func rotate_block(axis: Vector3, steps := 1) -> void:
	rot = Blocks.snap_basis(Basis(axis, deg_to_rad(rot_step) * steps) * rot)
	Sfx.play("click", null, -10.0)
	changed.emit()


func toggle_rot_step() -> void:
	rot_step = 90.0 if rot_step < 60.0 else 45.0
	message.emit("Rotation step %d degrees" % int(rot_step))
	changed.emit()


func set_block(id: String) -> void:
	block_id = id
	rot = Basis.IDENTITY
	_ghost_id = ""
	if tool != "build":
		tool = "build"
	_select(null)
	changed.emit()


func set_tool(t: String) -> void:
	tool = t
	if t != "config":
		_select(null)
	changed.emit()


func toggle_mirror() -> void:
	mirror = not mirror
	_mirror_plane.visible = mirror
	message.emit("Mirror mode %s" % ("ON" if mirror else "OFF"))
	changed.emit()


func _select(c: Variant) -> void:
	selected_cell = c
	_sel_box.visible = c != null and cells.has(c)
	if _sel_box.visible:
		_sel_box.transform = _box_xform(cells[c])
	selected.emit(c)


func _refresh() -> void:
	var d := to_design()
	var s := Designs.stats(d)
	_com_marker.position = s.com
	_col_marker.visible = s.wings > 0
	_col_marker.position = s.col
	# loose blocks in red
	for ch in _loose_root.get_children():
		ch.queue_free()
	var conn := Designs.connected(d.blocks)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.15, 0.15, 0.45)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for c: Vector3i in cells:
		if not conn.has(c):
			var mi := Blocks._mi(_loose_root, Blocks.box_mesh(Vector3.ONE * 1.06), Vector3.ZERO, red)
			mi.transform = _box_xform(cells[c])
	var lo := 0.0
	for c in cells:
		lo = minf(lo, Blocks.cell_box(cells[c]).position.y)
	_floor.position.y = lo - 0.95
	_mirror_plane.position = Vector3(0, _center().y, _center().z)
	_mirror_plane.scale = Vector3.ONE * maxf(1.0, _radius() / 4.0)
	changed.emit()


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press_pos[mb.button_index] = mb.position
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					dist = maxf(3.0, dist * 0.9)
				MOUSE_BUTTON_WHEEL_DOWN:
					dist = minf(60.0, dist * 1.1)
				MOUSE_BUTTON_LEFT:
					if tool == "paint" and _hover_cell != null:
						paint(_hover_cell)
		else:
			var start: Vector2 = _press_pos.get(mb.button_index, mb.position)
			var moved := start.distance_to(mb.position) > 6.0
			_press_pos.erase(mb.button_index)
			if not moved:
				match mb.button_index:
					MOUSE_BUTTON_LEFT:
						_click()
					MOUSE_BUTTON_RIGHT:
						if _hover_cell != null:
							remove(_hover_cell)
					MOUSE_BUTTON_MIDDLE:
						if _hover_cell != null:
							_pick(_hover_cell)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		_mouse = mm.position
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch - mm.relative.y * 0.008, -1.45, 1.2)
		elif mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var right := cam.global_basis.x
			var up := cam.global_basis.y
			_focus_goal += (-right * mm.relative.x + up * mm.relative.y) * dist * 0.0018
		elif mm.button_mask & MOUSE_BUTTON_MASK_LEFT and tool == "paint" and _hover_cell != null:
			paint(_hover_cell)
	elif e is InputEventKey and e.is_pressed() and not e.is_echo():
		var k := e as InputEventKey
		var shift := k.shift_pressed
		var ctrl := k.ctrl_pressed or k.meta_pressed
		match k.physical_keycode:
			KEY_R:
				rotate_block(Vector3.UP, -1 if shift else 1)
			KEY_T:
				rotate_block(Vector3.RIGHT, -1 if shift else 1)
			KEY_F:
				if not ctrl:
					rotate_block(Vector3.BACK, -1 if shift else 1)
			KEY_G:
				toggle_rot_step()
			KEY_BRACKETLEFT:
				set_size(size - Vector3.ONE * 0.25)
			KEY_BRACKETRIGHT:
				set_size(size + Vector3.ONE * 0.25)
			KEY_M:
				toggle_mirror()
			KEY_Z:
				if ctrl:
					if shift:
						redo()
					else:
						undo()
			KEY_Y:
				if ctrl:
					redo()
			KEY_B:
				set_tool("build")
			KEY_P:
				set_tool("paint")
			KEY_C:
				set_tool("config")
			KEY_DELETE, KEY_BACKSPACE, KEY_X:
				if selected_cell != null:
					remove(selected_cell)
				elif _hover_cell != null:
					remove(_hover_cell)
			KEY_HOME:
				_focus_goal = _center()


func _pick(c: Vector3i) -> void:
	var b: Dictionary = cells[c]
	if b.id == "seat":
		return
	block_id = b.id
	rot = Blocks.basis_of(b)
	if Blocks.resizable(b.id):
		size = Blocks.size_of(b)
	_ghost_id = ""
	tool = "build"
	changed.emit()
	message.emit("Picked %s" % Blocks.defs[b.id].name)


func _click() -> void:
	if _hover_cell == null:
		return
	match tool:
		"build":
			if _target != null:
				place_at(_target[0], _target[1])
		"paint":
			pass
		"config":
			_select(_hover_cell)
			Sfx.play("click", null, -8.0)


## Where the current block goes when pointing at block `hk` at world point `hit`
## with surface normal `n`: flush against that face, in the hovered block's frame
## (so it follows 45 degree turns), sliding along big faces in whole-block steps.
func target_for(hk: Vector3i, hit: Vector3, n: Vector3) -> Array:
	var hb: Dictionary = cells[hk]
	var bh := Blocks.basis_of(hb)
	var g := Blocks.nearest_grid(bh)
	var t := Blocks.snap_basis(bh * g.inverse())
	var ti := t.inverse()
	var ch := Blocks.center_of(hb)
	# hovered block's tight box, expressed in the (axis-aligned) frame t
	var h_box := Transform3D(g, ti * ch) * Blocks.local_box(hb.id, Blocks.size_of(hb))
	var p := ti * hit
	var nl := ti * n
	var an := nl.abs()
	var k := 0 if an.x >= an.y and an.x >= an.z else (1 if an.y >= an.z else 2)
	var sg := signf(nl[k])
	# on a turned block, new blocks line up with its frame (rounded to the grid there)
	var nb := _place_basis(block_id, rot)
	if t != Basis.IDENTITY and not Blocks.defs[block_id].auto_rot:
		nb = t * Blocks.nearest_grid(ti * nb)
	var n_box := Transform3D(ti * nb, Vector3.ZERO) * Blocks.local_box(block_id, _place_size(block_id))
	var c := Vector3.ZERO
	for a in 3:
		if a == k:
			c[a] = h_box.end[a] - n_box.position[a] if sg > 0.0 else h_box.position[a] - n_box.end[a]
			continue
		var l: float = n_box.size[a]
		var lo: float = h_box.position[a] + l * 0.5
		var hi: float = h_box.end[a] - l * 0.5
		var bc: float
		if hi - lo < 0.01:
			bc = h_box.get_center()[a]
		else:
			var step := 0.5 if l < 0.99 else 1.0
			bc = clampf(lo + roundf((p[a] - lo) / step) * step, lo, hi)
		c[a] = bc - n_box.get_center()[a]
	var center := t * c
	if t == Basis.IDENTITY:
		center = center.snapped(Vector3.ONE * 0.0625)
	return [center, nb]


func _physics_process(_delta: float) -> void:
	if not active or cam == null:
		return
	var from := cam.project_ray_origin(_mouse)
	var dir := cam.project_ray_normal(_mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0, Fx.L_BUILD)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty() or get_viewport().gui_get_hovered_control() != null:
		_hover_cell = null
		_target = null
	else:
		_hover_cell = h.collider.get_meta("cell")
		_target = target_for(_hover_cell, h.position, h.normal) if cells.has(_hover_cell) else null


func _process(delta: float) -> void:
	if not active:
		return
	focus = focus.lerp(_focus_goal, clampf(delta * 8.0, 0.0, 1.0))
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)
	_update_ghost()


func _update_ghost() -> void:
	var show_ghost := tool == "build" and _target != null
	if block_id != _ghost_id:
		_ghost_id = block_id
		for g in [_ghost, _ghost_m]:
			if g:
				g.queue_free()
		_ghost = _make_ghost()
		_ghost_m = _make_ghost()
		_ghost_ok = -1
		_ghost_m_ok = -1
	_ghost.visible = show_ghost
	_ghost_m.visible = false
	if not show_ghost:
		_hover_box.visible = _hover_cell != null and cells.has(_hover_cell)
		if _hover_box.visible:
			_hover_box.transform = _box_xform(cells[_hover_cell])
		return
	_hover_box.visible = false
	var sz := _place_size(block_id)
	var center: Vector3 = _target[0]
	var basis: Basis = _place_basis(block_id, _target[1])
	_ghost.transform = Transform3D(basis * Basis.from_scale(sz), center)
	var ok := can_place_at(block_id, center, basis)
	# Re-tinting walks the whole ghost; only do it when the colour changes.
	if int(ok) != _ghost_ok:
		_ghost_ok = int(ok)
		Blocks.ghostify(_ghost, ok)
	var mc := center * Vector3(-1, 1, 1)
	_ghost_m.visible = mirror and absf(center.x) > 0.01
	if _ghost_m.visible:
		var mb := _place_basis(block_id, Blocks.mirror_basis(basis))
		_ghost_m.transform = Transform3D(mb * Basis.from_scale(sz), mc)
		var mok := can_place_at(block_id, mc, mb)
		if int(mok) != _ghost_m_ok:
			_ghost_m_ok = int(mok)
			Blocks.ghostify(_ghost_m, mok)


func _make_ghost() -> Node3D:
	var g := Blocks.make_visual(block_id, Color.WHITE)
	Blocks.ghostify(g, true)
	add_child(g)
	g.visible = false
	return g


func hovered_block() -> Dictionary:
	if _hover_cell != null and cells.has(_hover_cell):
		return cells[_hover_cell]
	return {}
