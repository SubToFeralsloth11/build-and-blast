extends Control
## Garage UI: block palette, tools, paint palette, block settings, stats,
## presets/save/load and the "test drive" buttons.

signal test_requested(loc: String)

const UI := preload("res://scripts/ui_kit.gd")
const PAINT := ["#f2f2f2", "#9aa4b1", "#59616c", "#2b2f36", "#e53935", "#ff7a2f", "#ffcc00", "#3ddc84",
	"#1d8a4a", "#3fd6c6", "#3fa9ff", "#1e40af", "#b98cff", "#ff5ec4", "#8d6e63", "#b67a44"]

var builder: Node
var _cat := "Structure"
var _grid: GridContainer
var _cat_buttons := {}
var _block_buttons := {}
var _tool_buttons := {}
var _mirror_btn: Button
var _name_edit: LineEdit
var _right: VBoxContainer
var _stats: Label
var _hint: Label
var _toast: Label
var _toast_t := 0.0
var _load_menu: MenuButton
var _preset_menu: MenuButton
var _presets: Array = []


func setup(b: Node) -> void:
	builder = b
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	_presets = Designs.presets()
	_build_top()
	_build_left()
	_build_right_panel()
	_build_bottom()
	builder.changed.connect(_on_changed)
	builder.selected.connect(func(_c): _rebuild_right())
	builder.message.connect(toast)
	_select_cat("Structure")
	_on_changed()


# ---------------------------------------------------------------- top bar

func _build_top() -> void:
	var bar := UI.panel()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 10
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	var title := UI.label("BUILD & BLAST", 20, UI.HOT)
	h.add_child(title)
	h.add_child(VSeparator.new())
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(190, 0)
	_name_edit.placeholder_text = "Vehicle name"
	_name_edit.text_changed.connect(func(t): builder.design_name = t)
	_name_edit.text_submitted.connect(func(_t): _name_edit.release_focus())
	h.add_child(_name_edit)
	h.add_child(UI.button("New", _on_new, "Start over with just a seat"))
	_preset_menu = MenuButton.new()
	_preset_menu.text = "Presets"
	_preset_menu.flat = false
	_preset_menu.tooltip_text = "Load a ready-made vehicle"
	for i in _presets.size():
		_preset_menu.get_popup().add_item(_presets[i].name, i)
	_preset_menu.get_popup().id_pressed.connect(func(id): _load(_presets[id].duplicate(true), "Loaded preset"))
	h.add_child(_preset_menu)
	_load_menu = MenuButton.new()
	_load_menu.text = "Load"
	_load_menu.flat = false
	_load_menu.about_to_popup.connect(_fill_load_menu)
	_load_menu.get_popup().id_pressed.connect(_on_load_pick)
	h.add_child(_load_menu)
	h.add_child(UI.button("Save", _on_save, "Save to your garage"))
	h.add_child(UI.accent_button("Random!", _on_random, Color("#b98cff"), "Generate a surprise contraption"))
	h.add_child(VSeparator.new())
	h.add_child(UI.button("Undo", func(): builder.undo(), "Ctrl+Z"))
	h.add_child(UI.button("Redo", func(): builder.redo(), "Ctrl+Y"))
	h.add_child(VSeparator.new())
	for t in [["build", "Build", "B"], ["paint", "Paint", "P"], ["config", "Configure", "C"]]:
		var b := UI.button(t[1], func(): builder.set_tool(t[0]), "%s tool (%s)" % [t[1], t[2]])
		b.toggle_mode = true
		_tool_buttons[t[0]] = b
		h.add_child(b)
	_mirror_btn = UI.button("Mirror", func(): builder.toggle_mirror(), "Mirror building across the center (M)")
	_mirror_btn.toggle_mode = true
	h.add_child(_mirror_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UI.label("TEST:", 14, UI.MUTED))
	h.add_child(UI.accent_button("Desert", func(): test_requested.emit("desert"), Color("#e0a050"), "Stunt park, ramps, loop and targets"))
	h.add_child(UI.accent_button("Sea", func(): test_requested.emit("sea"), Color("#3fa9ff"), "Harbor, open sea and islands"))
	h.add_child(UI.accent_button("Runway", func(): test_requested.emit("runway"), Color("#9aa4b1"), "Airfield for planes"))
	h.add_child(UI.accent_button("Sky", func(): test_requested.emit("sky"), Color("#b98cff"), "Spawn mid-air at 230 m"))


func _fill_load_menu() -> void:
	var p := _load_menu.get_popup()
	p.clear()
	var saved := Designs.list_saved()
	if saved.is_empty():
		p.add_item("(no saved vehicles yet)", -1)
		p.set_item_disabled(0, true)
		return
	for i in saved.size():
		p.add_item(saved[i], i)


func _on_load_pick(id: int) -> void:
	var saved := Designs.list_saved()
	if id < 0 or id >= saved.size():
		return
	var d := Designs.load_design(saved[id])
	if d.is_empty():
		toast("Couldn't read that file")
		return
	_load(d, "Loaded")


func _load(d: Dictionary, msg: String) -> void:
	builder.load_design(d)
	_name_edit.text = builder.design_name
	toast("%s: %s" % [msg, builder.design_name])
	Sfx.play("score", null, -8.0)


func _on_new() -> void:
	builder.load_design(Designs.empty_design())
	_name_edit.text = builder.design_name
	toast("Fresh start. Build out from the seat!")


func _on_save() -> void:
	var path := Designs.save_design(builder.to_design())
	toast("Saved \"%s\"" % builder.design_name if path != "" else "Save failed")
	Sfx.play("score", null, -8.0)


func _on_random() -> void:
	_load(Designs.random_design(), "Random build")


# ---------------------------------------------------------------- palette

func _build_left() -> void:
	var p := UI.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p.offset_left = 10
	p.offset_top = 74
	p.offset_bottom = -74
	p.offset_right = 330
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UI.label("BLOCKS", 13, UI.MUTED))
	var cats := HFlowContainer.new()
	cats.add_theme_constant_override("h_separation", 4)
	cats.add_theme_constant_override("v_separation", 4)
	v.add_child(cats)
	for c in Blocks.CATS:
		var b := UI.button(c, _select_cat.bind(c))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 13)
		var col: Color = Blocks.CAT_COLORS[c]
		b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.45), 8, col, 8))
		b.add_theme_stylebox_override("normal", UI.box(UI.BG2, 8, UI.LINE, 8))
		b.add_theme_stylebox_override("hover", UI.box(UI.BG2.lightened(0.1), 8, col.darkened(0.2), 8))
		_cat_buttons[c] = b
		cats.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(_grid)


func _select_cat(c: String) -> void:
	_cat = c
	for k in _cat_buttons:
		_cat_buttons[k].button_pressed = k == c
	for ch in _grid.get_children():
		ch.queue_free()
	_block_buttons.clear()
	for id in Blocks.ids_in(c):
		var def: Dictionary = Blocks.defs[id]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(94, 112)
		b.tooltip_text = "%s\n%s\nMass %d kg   Armor %d" % [def.name, def.desc, def.mass, def.hp]
		b.pressed.connect(_pick_block.bind(id))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var tr := TextureRect.new()
		tr.texture = Blocks.icon(id)
		tr.custom_minimum_size = Vector2(72, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		var l := UI.label(def.name, 12, UI.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(88, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		_grid.add_child(b)
		_block_buttons[id] = b
	_on_changed()


func _pick_block(id: String) -> void:
	builder.set_block(id)
	Sfx.play("click", null, -8.0)


# ---------------------------------------------------------------- right panel

func _build_right_panel() -> void:
	var p := UI.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p.offset_right = -10
	p.offset_top = 74
	p.offset_bottom = -74
	p.offset_left = -320
	add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 10)
	sc.add_child(_right)


func _rebuild_right() -> void:
	for ch in _right.get_children():
		ch.queue_free()
	match builder.tool:
		"build":
			_right_build()
		"paint":
			_right_paint()
		"config":
			_right_config()


func _right_build() -> void:
	var def: Dictionary = Blocks.defs[builder.block_id]
	_right.add_child(UI.label("SELECTED BLOCK", 13, UI.MUTED))
	var tr := TextureRect.new()
	tr.texture = Blocks.icon(builder.block_id)
	tr.custom_minimum_size = Vector2(0, 140)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right.add_child(tr)
	_right.add_child(UI.label(def.name, 22, Blocks.CAT_COLORS[def.cat]))
	var d := UI.label(def.desc, 14, UI.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(d)
	_right.add_child(UI.label("Mass %d kg    Armor %d" % [def.mass, def.hp], 14, UI.MUTED))
	if def.cfg.has("ch"):
		_right.add_child(UI.label("Default key: %s" % Controls.label(def.cfg.ch), 14, UI.MUTED))
	_right.add_child(HSeparator.new())
	var tips := UI.label("Left click: place\nRight click: delete\nRight drag: orbit   Middle drag: pan\nWheel: zoom   Middle click: pick block\nR / T / F: rotate (Shift = back)\nM: mirror   Ctrl+Z: undo", 13, UI.MUTED)
	_right.add_child(tips)
	if def.auto_rot:
		_right.add_child(UI.label("Wheels orient themselves.", 13, UI.GOOD))
	if def.kind in Blocks.MOVERS or def.kind == "susp":
		var ml := UI.label("The yellow/black striped face is the moving side. Rotate it (R/T/F) to point where you want to push or swing. Anything touching the moving side gets carried, so keep it from touching the rest of the vehicle.", 13, UI.GOOD)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(ml)


func _right_paint() -> void:
	_right.add_child(UI.label("PAINT", 13, UI.MUTED))
	_right.add_child(UI.label("Click or drag over blocks to paint.\nNew blocks use this color too.", 13, UI.MUTED))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_right.add_child(g)
	for hex in PAINT:
		var c := Color(hex)
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 44)
		b.focus_mode = Control.FOCUS_NONE
		var sel: bool = builder.paint_color != null and builder.paint_color.is_equal_approx(c)
		b.add_theme_stylebox_override("normal", UI.box(c, 8, Color.WHITE if sel else Color(0, 0, 0, 0.4), 4))
		b.add_theme_stylebox_override("hover", UI.box(c.lightened(0.15), 8, Color.WHITE, 4))
		b.add_theme_stylebox_override("pressed", UI.box(c, 8, Color.WHITE, 4))
		b.pressed.connect(_set_paint.bind(c))
		g.add_child(b)
	var row := HBoxContainer.new()
	_right.add_child(row)
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(130, 40)
	pick.color = builder.paint_color if builder.paint_color != null else Color.WHITE
	pick.text = "Custom"
	pick.color_changed.connect(func(c): builder.paint_color = c)
	row.add_child(pick)
	var def_btn := UI.button("Original colors", func(): _set_paint(null))
	def_btn.toggle_mode = true
	def_btn.button_pressed = builder.paint_color == null
	row.add_child(def_btn)


func _set_paint(c: Variant) -> void:
	builder.paint_color = c
	Sfx.play("click", null, -8.0)
	_rebuild_right()


func _right_config() -> void:
	_right.add_child(UI.label("CONFIGURE", 13, UI.MUTED))
	var c = builder.selected_cell
	if c == null or not builder.cells.has(c):
		var l := UI.label("Click a block to change its keys, power and options.\n\nEvery engine, weapon and gadget can be bound to any control, inverted, or boosted up to 200%.", 14, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(l)
		return
	var b: Dictionary = builder.cells[c]
	var def: Dictionary = Blocks.defs[b.id]
	var cfg: Dictionary = b.cfg
	var head := HBoxContainer.new()
	_right.add_child(head)
	var tr := TextureRect.new()
	tr.texture = Blocks.icon(b.id)
	tr.custom_minimum_size = Vector2(64, 64)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(tr)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(UI.label(def.name, 18, Blocks.CAT_COLORS[def.cat]))
	hv.add_child(UI.label("at %d, %d, %d" % [c.x, c.y, c.z], 12, UI.MUTED))
	if def.kind in Blocks.MOVERS:
		var n: int = Designs.mech_status(builder.to_design().blocks, c)
		var msg := "Moves %d block%s attached to its striped face." % [n, "" if n == 1 else "s"]
		var mc := UI.GOOD
		if n < 0:
			msg = "JAMMED: the moving side also touches the rest of the vehicle, so it can't move. Leave a gap around the moving part."
			mc = UI.BAD
		elif n == 0:
			msg = "Nothing attached to its striped face yet."
			mc = UI.MUTED
		var ml := UI.label(msg, 13, mc)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(ml)
	if def.cfg.is_empty() and def.kind != "flap":
		_right.add_child(UI.label("This block has no settings.\nIt just works.", 14, UI.MUTED))
		return
	if def.cfg.has("ch"):
		_right.add_child(UI.label("Control", 13, UI.MUTED))
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for i in Controls.CHANNELS.size():
			ob.add_item(Controls.CHANNELS[i][1], i)
		ob.selected = Controls.index_of(cfg.get("ch", def.cfg.ch))
		ob.item_selected.connect(func(i): builder.set_cfg(c, "ch", Controls.CHANNELS[i][0]))
		_right.add_child(ob)
		var inv := CheckBox.new()
		inv.text = "Invert (use the other key / start switched on)"
		inv.focus_mode = Control.FOCUS_NONE
		inv.button_pressed = cfg.get("inv", false)
		inv.toggled.connect(func(on): builder.set_cfg(c, "inv", on))
		_right.add_child(inv)
	if def.cfg.has("steer"):
		_right.add_child(UI.label("Steering", 13, UI.MUTED))
		var so := OptionButton.new()
		so.focus_mode = Control.FOCUS_NONE
		var modes := ["auto", "on", "off", "inv"]
		for m in ["Auto (front wheels)", "Always steer", "No steering", "Reverse steer"]:
			so.add_item(m)
		modes.append("tank")
		so.add_item("Tank (skid steer)")
		so.selected = modes.find(cfg.get("steer", "auto"))
		so.item_selected.connect(func(i): builder.set_cfg(c, "steer", modes[i]))
		_right.add_child(so)
		var dr := CheckBox.new()
		dr.text = "Powered (drives on W/S)"
		dr.focus_mode = Control.FOCUS_NONE
		dr.button_pressed = cfg.get("drive", true)
		dr.toggled.connect(func(on): builder.set_cfg(c, "drive", on))
		_right.add_child(dr)
	if def.cfg.has("mode"):
		_right.add_child(UI.label("Movement", 13, UI.MUTED))
		var mo := OptionButton.new()
		mo.focus_mode = Control.FOCUS_NONE
		var modes := ["return", "hold", "osc"]
		for m in ["Return: follows the key", "Hold: stays where you leave it", "Auto: swings by itself while on"]:
			mo.add_item(m)
		mo.selected = maxi(modes.find(cfg.get("mode", def.cfg.mode)), 0)
		mo.item_selected.connect(func(i): builder.set_cfg(c, "mode", modes[i]))
		_right.add_child(mo)
	if def.cfg.has("pow"):
		var pl := UI.label("Power: %d%%" % cfg.get("pow", 100), 13, UI.MUTED)
		_right.add_child(pl)
		var s := HSlider.new()
		s.min_value = 25
		s.max_value = 200
		s.step = 5
		s.value = cfg.get("pow", 100)
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(func(v): pl.text = "Power: %d%%" % v)
		s.drag_ended.connect(func(_ch): builder.set_cfg(c, "pow", int(s.value)))
		_right.add_child(s)
	if def.kind == "flap":
		var fl := UI.label("Flaps steer automatically: put them far from the center of mass. Behind = pitch, out on the wings = roll, upright = yaw.", 13, UI.GOOD)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(fl)
	_right.add_child(HSeparator.new())
	_right.add_child(UI.button("Apply to all %ss" % def.name, func(): toast("Updated %d blocks" % builder.apply_cfg_to_all(c))))
	_right.add_child(UI.accent_button("Delete block", func(): builder.remove(c), UI.BAD))


# ---------------------------------------------------------------- bottom

func _build_bottom() -> void:
	var p := UI.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_left = 10
	p.offset_right = -10
	p.offset_bottom = -10
	p.offset_top = -62
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	_stats = UI.label("", 15, UI.TEXT)
	h.add_child(_stats)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_hint = UI.label("", 14, UI.MUTED)
	h.add_child(_hint)
	_toast = UI.label("", 22, Color.WHITE)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 86
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func toast(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.0
	_toast_t = 2.2


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t < 0.5:
			_toast.modulate.a = maxf(0.0, _toast_t / 0.5)
	if builder == null or not visible:
		return
	var hb: Dictionary = builder.hovered_block()
	if not hb.is_empty():
		var def: Dictionary = Blocks.defs[hb.id]
		var key := ""
		var cfg: Dictionary = def.cfg.duplicate()
		cfg.merge(hb.cfg, true)
		if cfg.has("ch"):
			key = "   [%s%s]" % [Controls.label(cfg.ch), " inverted" if cfg.get("inv", false) else ""]
		_hint.text = "%s%s" % [def.name, key]
	else:
		_hint.text = "Tools: B build  P paint  C configure   Enter: test drive"


func _on_changed() -> void:
	if builder == null:
		return
	for k in _tool_buttons:
		_tool_buttons[k].button_pressed = builder.tool == k
	_mirror_btn.button_pressed = builder.mirror
	for id in _block_buttons:
		_block_buttons[id].button_pressed = id == builder.block_id and builder.tool == "build"
	if _name_edit.text != builder.design_name and not _name_edit.has_focus():
		_name_edit.text = builder.design_name
	var s := Designs.stats(builder.to_design())
	var tw: float = s.thrust / maxf(s.mass * 9.8, 1.0)
	var parts := ["Blocks %d" % s.blocks, "Mass %d kg" % s.mass]
	if s.thrust > 0:
		parts.append("Thrust/Weight %.2f" % tw)
	if s.wings > 0:
		var v := sqrt(s.mass * 9.8 / (0.35 * s.wings + 0.4))
		parts.append("Wings %d (takeoff ~%d km/h)" % [s.wings, int(v * 3.6)])
	if s.lift_max > 0:
		parts.append("Lift %d%%" % int(s.lift_max / (s.mass * 9.8) * 100.0))
	if s.wheels > 0:
		parts.append("Wheels %d" % s.wheels)
	if s.weapons > 0:
		parts.append("Weapons %d" % s.weapons)
	parts.append("Floats" if s.floats > s.mass * 9.8 else "Sinks")
	var txt := "   ".join(parts)
	if s.loose > 0:
		txt += "   |   %d loose blocks will fall off!" % s.loose
	_stats.text = txt
	_stats.add_theme_color_override("font_color", UI.BAD if s.loose > 0 else UI.TEXT)
	_rebuild_right()
