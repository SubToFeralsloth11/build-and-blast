extends Control
## Test-drive HUD: speedometer, altitude, damage, score, event feed,
## crosshair, help card, wreck overlay and pause menu.

signal resume
signal respawn
signal relocate(loc: String)
signal garage
signal enemies_toggled(on: bool)

const UI := preload("res://scripts/ui_kit.gd")


class Crosshair extends Control:
	var hit := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.9)
		draw_arc(c, 10.0, 0.0, TAU, 32, col, 2.0, true)
		draw_circle(c, 2.0, col)
		if hit > 0.0:
			var hc := Color(1, 0.35, 0.3, hit)
			for a in 4:
				var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
				draw_line(c + d * 14.0, c + d * 22.0, hc, 3.0, true)


var _speed: Label
var _speed_unit: Label
var _alt: Label
var _intact: Label
var _intact_bar: ProgressBar
var _name: Label
var _score: Label
var _stats: Label
var _toggles: Label
var _feed: VBoxContainer
var _help: PanelContainer
var _wreck: PanelContainer
var _pause: PanelContainer
var _enemy_btn: Button
var _cross: Crosshair
var _ring: Label


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	# speed panel
	var sp := UI.panel()
	sp.position = Vector2(16, 16)
	sp.custom_minimum_size = Vector2(250, 0)
	add_child(sp)
	var v := VBoxContainer.new()
	sp.add_child(v)
	_name = UI.label("", 14, UI.MUTED)
	v.add_child(_name)
	var row := HBoxContainer.new()
	v.add_child(row)
	_speed = UI.label("0", 46, Color.WHITE)
	row.add_child(_speed)
	_speed_unit = UI.label(" km/h", 16, UI.MUTED)
	_speed_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_speed_unit)
	_alt = UI.label("", 15, UI.TEXT)
	v.add_child(_alt)
	_intact = UI.label("Intact 100%", 13, UI.MUTED)
	v.add_child(_intact)
	_intact_bar = ProgressBar.new()
	_intact_bar.show_percentage = false
	_intact_bar.custom_minimum_size = Vector2(0, 8)
	_intact_bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.1), 4, Color(0, 0, 0, 0), 0))
	_intact_bar.add_theme_stylebox_override("fill", UI.box(UI.GOOD, 4, Color(0, 0, 0, 0), 0))
	v.add_child(_intact_bar)
	_toggles = UI.label("", 13, UI.MUTED)
	v.add_child(_toggles)
	# score panel
	var scp := UI.panel()
	scp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	scp.offset_left = -270
	scp.offset_right = -16
	scp.offset_top = 16
	scp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(scp)
	var sv := VBoxContainer.new()
	scp.add_child(sv)
	_score = UI.label("SCORE 0", 26, UI.HOT)
	sv.add_child(_score)
	_stats = UI.label("", 14, UI.TEXT)
	sv.add_child(_stats)
	_ring = UI.label("", 14, Color("#ffd23f"))
	sv.add_child(_ring)
	# event feed
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_feed.offset_left = -300
	_feed.offset_right = 300
	_feed.offset_top = 24
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	# crosshair
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.custom_minimum_size = Vector2(60, 60)
	_cross.offset_left = -30
	_cross.offset_top = -30
	_cross.offset_right = 30
	_cross.offset_bottom = 30
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cross)
	_build_help()
	_build_wreck()
	_build_pause()


func _build_help() -> void:
	_help = UI.panel()
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 16
	_help.offset_bottom = -16
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_help)
	var l := UI.label("""W / S  throttle + brake      A / D  steer + yaw
Arrows  pitch + roll      Q / E  yaw      Space / C  lift
Shift  boost      Mouse  look + aim      LMB / RMB / G  fire
1 2 3  toggles      4  trigger (TNT)      H  horn
R  respawn      F  flip upright      V  camera mode
Tab  back to garage      Esc  menu      F1  hide this""", 13, UI.TEXT)
	_help.add_child(l)


func _build_wreck() -> void:
	_wreck = UI.panel(Color(0.25, 0.04, 0.06, 0.92))
	_wreck.set_anchors_preset(Control.PRESET_CENTER)
	_wreck.offset_left = -230
	_wreck.offset_right = 230
	_wreck.offset_top = 70
	_wreck.offset_bottom = 170
	add_child(_wreck)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_wreck.add_child(v)
	var t := UI.label("WRECKED!", 34, UI.BAD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.label("R  respawn        Tab  back to garage", 16, UI.TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_wreck.visible = false


func _build_pause() -> void:
	_pause = UI.panel(Color(0.06, 0.07, 0.1, 0.96))
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.offset_left = -200
	_pause.offset_right = 200
	_pause.offset_top = -230
	_pause.offset_bottom = 230
	add_child(_pause)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_pause.add_child(v)
	var t := UI.label("PAUSED", 30, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.accent_button("Resume", func(): resume.emit(), UI.GOOD))
	v.add_child(UI.button("Respawn vehicle", func(): respawn.emit()))
	v.add_child(UI.label("Teleport to", 13, UI.MUTED))
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	for loc in [["desert", "Desert"], ["sea", "Sea"], ["runway", "Runway"], ["sky", "Sky"]]:
		var b := UI.button(loc[1], func(): relocate.emit(loc[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	_enemy_btn = UI.button("Enemy turrets: ON", _toggle_enemies)
	_enemy_btn.toggle_mode = true
	_enemy_btn.button_pressed = true
	v.add_child(_enemy_btn)
	v.add_child(UI.accent_button("Back to garage", func(): garage.emit(), UI.ACCENT))
	v.add_child(UI.button("Quit game", func(): get_tree().quit()))
	_pause.visible = false


func _toggle_enemies() -> void:
	var on := _enemy_btn.button_pressed
	_enemy_btn.text = "Enemy turrets: %s" % ("ON" if on else "OFF")
	enemies_toggled.emit(on)


func set_paused(on: bool) -> void:
	_pause.visible = on
	_cross.visible = not on


func set_wrecked(on: bool) -> void:
	_wreck.visible = on


func toggle_help() -> void:
	_help.visible = not _help.visible


func hit_marker() -> void:
	_cross.hit = 1.0


func toast(text: String, col := Color.WHITE) -> void:
	var l := UI.label(text, 22, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_feed.add_child(l)
	if _feed.get_child_count() > 5:
		_feed.get_child(0).queue_free()
	l.scale = Vector2(1.3, 1.3)
	l.pivot_offset = Vector2(300, 14)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func update(d: Dictionary) -> void:
	_name.text = d.get("name", "")
	_speed.text = "%d" % int(d.get("speed", 0.0) * 3.6)
	_alt.text = "Altitude %d m    Ground %d m" % [int(d.get("alt", 0.0)), int(d.get("agl", 0.0))]
	var it: float = d.get("intact", 1.0)
	_intact.text = "Intact %d%%" % int(it * 100.0)
	_intact_bar.value = it * 100.0
	var fill := UI.GOOD if it > 0.6 else (Color("#ffcc00") if it > 0.3 else UI.BAD)
	(_intact_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = fill
	var tg := []
	for k in ["act1", "act2", "act3"]:
		if Controls.toggles[k]:
			tg.append(k.substr(3))
	_toggles.text = "Toggles on: %s" % ", ".join(tg) if not tg.is_empty() else ""
	_score.text = "SCORE %d" % d.get("score", 0)
	_stats.text = "Targets %d\nTop speed %d km/h\nMax altitude %d m\nBest airtime %.1f s\nBest lap %s" % [
		d.get("targets", 0), int(d.get("top_speed", 0.0) * 3.6), int(d.get("max_alt", 0.0)),
		d.get("best_air", 0.0), ("%.1f s" % d.best_lap) if d.get("best_lap", 0.0) > 0.0 else "-"]
	var rd: float = d.get("ring_dist", -1.0)
	_ring.text = ("Next ring %d  -  %d m" % [d.get("ring_idx", 0) + 1, int(rd)]) if rd >= 0.0 else ""


func _process(delta: float) -> void:
	if _cross.hit > 0.0:
		_cross.hit = maxf(0.0, _cross.hit - delta * 4.0)
		_cross.queue_redraw()
