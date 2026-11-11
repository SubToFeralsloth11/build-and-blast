extends Node3D
## The garage: grid building with ghost preview, mirror mode, paint,
## per-block configuration, undo/redo and an orbit camera.

signal changed
signal selected(cell: Variant)
signal message(text: String)

const NEIGHBORS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const MAX_BLOCKS := 400

var design_name := "My Vehicle"
var cells := {}            # Vector3i -> block dict
var nodes := {}            # Vector3i -> StaticBody3D
var block_id := "cube"
var rot := 0
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
var _ghost_key := ""
var _hover_box: Node3D
var _sel_box: Node3D
var _mirror_plane: MeshInstance3D
var _com_marker: Node3D
var _col_marker: Node3D
var _loose_root: Node3D
var _floor: MeshInstance3D
var _mouse := Vector2.ZERO
var _hover_cell: Variant = null
var _hover_normal := Vector3i.ZERO
var _press_pos := {}
var _dragging := ""
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
				var size := Vector3(t, t, t)
				var pos := Vector3.ZERO
				match a:
					0:
						size.x = s
						pos = Vector3(0, i * h, j * h)
					1:
						size.y = s
						pos = Vector3(i * h, 0, j * h)
					2:
						size.z = s
						pos = Vector3(i * h, j * h, 0)
				var mi := Blocks._mi(n, Blocks.box_mesh(size), pos, m)
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
	for c: Vector3i in cells:
		lo = lo.min(Vector3(c))
		hi = hi.max(Vector3(c))
	return (lo + hi) * 0.5


func _radius() -> float:
	var r := 1.0
	var cc := _center()
	for c: Vector3i in cells:
		r = maxf(r, Vector3(c).distance_to(cc))
	return r


func _spawn_node(c: Vector3i) -> void:
	var b: Dictionary = cells[c]
	var def: Dictionary = Blocks.defs[b.id]
	var body := StaticBody3D.new()
	body.collision_layer = Fx.L_BUILD
	body.collision_mask = 0
	body.position = Vector3(c)
	body.set_meta("cell", c)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE
	cs.shape = bs
	body.add_child(cs)
	var col: Color = Color(b.c) if b.c != "" else def.color
	var vis := Blocks.make_visual(b.id, col)
	if not def.auto_rot:
		vis.basis = Blocks.rots[b.r]
	if b.id == "light":
		var lamp := vis.get_node_or_null("lamp")
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


func _mirror_cell(c: Vector3i) -> Vector3i:
	return Vector3i(-c.x, c.y, c.z)


func _can_place(c: Vector3i, id: String) -> bool:
	if cells.has(c):
		return false
	if id == "seat":
		return false
	return true


func place(c: Vector3i) -> void:
	if not _can_place(c, block_id):
		if block_id == "seat":
			message.emit("Only one pilot seat allowed")
		return
	if cells.size() >= MAX_BLOCKS:
		message.emit("Block limit reached (%d)" % MAX_BLOCKS)
		return
	_push_undo()
	_add(c, block_id, rot)
	var mc := _mirror_cell(c)
	if mirror and mc != c and _can_place(mc, block_id):
		_add(mc, block_id, Blocks.mirror_index(rot))
	Sfx.play("place", null, -6.0, randf_range(0.9, 1.15))
	_pop(c)
	_refresh()


func _add(c: Vector3i, id: String, r: int) -> void:
	var cfg: Dictionary = Blocks.defs[id].cfg.duplicate()
	cells[c] = {"id": id, "p": [c.x, c.y, c.z], "r": r, "c": paint_color.to_html(false) if paint_color != null else "", "cfg": cfg}
	_spawn_node(c)


func _pop(c: Vector3i) -> void:
	if nodes.has(c):
		var n: Node3D = nodes[c].get_child(1)
		n.scale = Vector3.ONE * 0.6
		n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func remove(c: Vector3i) -> void:
	if not cells.has(c):
		return
	if cells[c].id == "seat":
		message.emit("The pilot seat can't be removed")
		return
	_push_undo()
	for cc in ([c, _mirror_cell(c)] if mirror else [c]):
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
	for cc in ([c, _mirror_cell(c)] if mirror else [c]):
		if cells.has(cc):
			cells[cc].c = hex
			_respawn_node(cc)
	Sfx.play("click", null, -8.0, 1.3)
	changed.emit()


func set_cfg(c: Vector3i, key: String, value: Variant) -> void:
	if not cells.has(c):
		return
	_push_undo()
	cells[c].cfg[key] = value
	var mc := _mirror_cell(c)
	if mirror and mc != c and cells.has(mc) and cells[mc].id == cells[c].id:
		cells[mc].cfg[key] = value
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


func rotate_block(axis: Vector3, steps := 1) -> void:
	rot = Blocks.rotate_index(rot, axis, steps)
	_ghost_key = ""
	Sfx.play("click", null, -10.0)


func set_block(id: String) -> void:
	block_id = id
	rot = 0
	_ghost_key = ""
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
	_sel_box.visible = c != null
	if c != null:
		_sel_box.position = Vector3(c)
	selected.emit(c)


func _refresh() -> void:
	var s := Designs.stats(to_design())
	_com_marker.position = s.com
	_col_marker.visible = s.wings > 0
	_col_marker.position = s.col
	# loose blocks in red
	for ch in _loose_root.get_children():
		ch.queue_free()
	var conn := Designs.connected(to_design().blocks)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.15, 0.15, 0.45)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for c: Vector3i in cells:
		if not conn.has(c):
			Blocks._mi(_loose_root, Blocks.box_mesh(Vector3.ONE * 1.06), Vector3(c), red)
	var lo := 0.0
	for c: Vector3i in cells:
		lo = minf(lo, c.y)
	_floor.position.y = lo - 0.5 - 0.95
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
							var b: Dictionary = cells[_hover_cell]
							if b.id != "seat":
								block_id = b.id
								rot = b.r
								_ghost_key = ""
								tool = "build"
								changed.emit()
								message.emit("Picked %s" % Blocks.defs[b.id].name)
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


func _click() -> void:
	if _hover_cell == null:
		return
	match tool:
		"build":
			place(_hover_cell + _hover_normal)
		"paint":
			pass
		"config":
			_select(_hover_cell)
			Sfx.play("click", null, -8.0)


func _physics_process(_delta: float) -> void:
	if not active or cam == null:
		return
	var from := cam.project_ray_origin(_mouse)
	var dir := cam.project_ray_normal(_mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0, Fx.L_BUILD)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty() or get_viewport().gui_get_hovered_control() != null:
		_hover_cell = null
	else:
		_hover_cell = h.collider.get_meta("cell")
		var n: Vector3 = h.normal
		var an := n.abs()
		if an.x >= an.y and an.x >= an.z:
			_hover_normal = Vector3i(int(signf(n.x)), 0, 0)
		elif an.y >= an.z:
			_hover_normal = Vector3i(0, int(signf(n.y)), 0)
		else:
			_hover_normal = Vector3i(0, 0, int(signf(n.z)))


func _process(delta: float) -> void:
	if not active:
		return
	focus = focus.lerp(_focus_goal, clampf(delta * 8.0, 0.0, 1.0))
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.global_position = focus + off
	cam.look_at(focus, Vector3.UP)
	_update_ghost()


func _update_ghost() -> void:
	var show_ghost := tool == "build" and _hover_cell != null
	var target := Vector3i.ZERO
	if show_ghost:
		target = _hover_cell + _hover_normal
	var key := "%s_%d" % [block_id, rot]
	if key != _ghost_key:
		_ghost_key = key
		for g in [_ghost, _ghost_m]:
			if g:
				g.queue_free()
		_ghost = _make_ghost(rot)
		_ghost_m = _make_ghost(Blocks.mirror_index(rot))
	var ok := show_ghost and _can_place(target, block_id)
	_ghost.visible = show_ghost
	if show_ghost:
		_ghost.position = Vector3(target)
		Blocks.ghostify(_ghost, ok)
	var mc := _mirror_cell(target)
	_ghost_m.visible = show_ghost and mirror and mc != target
	if _ghost_m.visible:
		_ghost_m.position = Vector3(mc)
		Blocks.ghostify(_ghost_m, _can_place(mc, block_id))
	_hover_box.visible = _hover_cell != null and tool != "build"
	if _hover_box.visible:
		_hover_box.position = Vector3(_hover_cell)


func _make_ghost(r: int) -> Node3D:
	var g := Blocks.make_visual(block_id, Color.WHITE)
	if not Blocks.defs[block_id].auto_rot:
		g.basis = Blocks.rots[r]
	Blocks.ghostify(g, true)
	add_child(g)
	g.visible = false
	return g


func hovered_block() -> Dictionary:
	if _hover_cell != null and cells.has(_hover_cell):
		return cells[_hover_cell]
	return {}
