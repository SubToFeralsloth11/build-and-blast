extends RefCounted
## Theme and small widget helpers shared by the garage UI and the HUD.

const BG := Color(0.07, 0.085, 0.11, 0.9)
const BG2 := Color(0.12, 0.14, 0.18, 0.95)
const LINE := Color(1, 1, 1, 0.08)
const TEXT := Color("#e8edf3")
const MUTED := Color("#93a0b0")
const ACCENT := Color("#3fa9ff")
const HOT := Color("#ff7a2f")
const GOOD := Color("#3ddc84")
const BAD := Color("#ff4f5e")


static func box(col: Color, radius := 10, border := LINE, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(BG, 12, LINE, 12))
	t.set_stylebox("panel", "Panel", box(BG, 12, LINE, 12))
	t.set_stylebox("normal", "Button", box(BG2, 8, LINE, 10))
	t.set_stylebox("hover", "Button", box(BG2.lightened(0.12), 8, Color(1, 1, 1, 0.18), 10))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.25), 8, ACCENT, 10))
	t.set_stylebox("hover_pressed", "Button", box(ACCENT.darkened(0.15), 8, ACCENT, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", box(BG2.darkened(0.3), 8, LINE, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	for kind in ["MenuButton", "OptionButton"]:
		t.set_stylebox("normal", kind, box(BG2, 8, LINE, 10))
		t.set_stylebox("hover", kind, box(BG2.lightened(0.12), 8, Color(1, 1, 1, 0.18), 10))
		t.set_stylebox("pressed", kind, box(ACCENT.darkened(0.25), 8, ACCENT, 10))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, TEXT)
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.35), 8, LINE, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.45), 8, ACCENT, 10))
	t.set_stylebox("panel", "PopupMenu", box(BG2, 8, Color(1, 1, 1, 0.15), 6))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT.darkened(0.3), 6, Color(0, 0, 0, 0), 6))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.06, 0.08, 0.97), 6, Color(1, 1, 1, 0.15), 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 4, Color(0, 0, 0, 0), 2))
	return t


static func label(text: String, size := 15, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


static func accent_button(text: String, cb: Callable, col: Color, tip := "") -> Button:
	var b := button(text, cb, tip)
	b.add_theme_stylebox_override("normal", box(col.darkened(0.25), 8, col, 12))
	b.add_theme_stylebox_override("hover", box(col.darkened(0.05), 8, col.lightened(0.3), 12))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.4), 8, col, 12))
	return b


static func panel(col := BG) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(col, 12, LINE, 12))
	return p
