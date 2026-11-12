extends Node
## Battery use: frame-rate limits and the battery saver.
##
## - Caps the game at 60 FPS. High-refresh screens (120 Hz MacBooks) would
##   otherwise draw twice as many frames for no gameplay benefit.
## - In the garage and the pause menu, drops to IDLE_FPS after IDLE_AFTER
##   seconds without input. Any input brings back the full rate.
## - While the window is unfocused, runs at BACKGROUND_FPS.
## - Battery saver (Auto turns it on while unplugged) renders the 3D view at a
##   lower resolution with FSR upscaling, halves the shadow map and turns off
##   MSAA. The UI stays sharp and the frame rate stays at 60.

signal changed

const ACTIVE_FPS := 60
const IDLE_FPS := 20
const BACKGROUND_FPS := 8
const IDLE_AFTER := 1.5
const BATTERY_POLL := 30.0
const SETTINGS := "user://settings.cfg"
const MODES := ["auto", "on", "off"]
const MODE_NAMES := {"auto": "Auto", "on": "On", "off": "Off"}

var mode := "auto"
var on_battery := false
## True while gameplay needs every frame (test drive, not paused).
var interactive := false

var _enabled := true
var _focused := true
var _idle_t := 0.0
var _poll_t := 0.0
var _polling := false
var _shadow_size := 4096
var _msaa := Viewport.MSAA_2X


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shadow_size = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
	_msaa = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_2X)
	var args := OS.get_cmdline_user_args()
	# The headless sim harness must run as fast as possible.
	if DisplayServer.get_name() == "headless" or "--simtest" in args or "--shots" in args:
		_enabled = false
		set_process(false)
		set_process_input(false)
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		var m: String = cfg.get_value("power", "battery_saver", "auto")
		if m in MODES:
			mode = m
	Engine.max_fps = ACTIVE_FPS
	_apply_saver()


func _input(_e: InputEvent) -> void:
	_idle_t = 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_idle_t = 0.0


func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = BATTERY_POLL
		_poll_battery()
	_idle_t += delta
	var fps := ACTIVE_FPS
	if not _focused:
		fps = BACKGROUND_FPS
	elif not interactive and _idle_t > IDLE_AFTER:
		fps = IDLE_FPS
	if Engine.max_fps != fps:
		Engine.max_fps = fps


func saver_active() -> bool:
	return mode == "on" or (mode == "auto" and on_battery)


func label() -> String:
	var t := "Battery saver: %s" % MODE_NAMES[mode]
	if mode == "auto":
		t += " (%s)" % ("on" if on_battery else "off")
	return t


## Steps Auto -> On -> Off and saves the choice.
func cycle() -> void:
	mode = MODES[(MODES.find(mode) + 1) % MODES.size()]
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("power", "battery_saver", mode)
	cfg.save(SETTINGS)
	_apply_saver()
	changed.emit()


func _apply_saver() -> void:
	if not _enabled:
		return
	var on := saver_active()
	var vp := get_tree().root
	if on:
		# Retina screens render 4x the pixels; draw 3D at logical resolution there.
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.5 if DisplayServer.screen_get_scale() >= 2.0 else 0.75
		vp.msaa_3d = Viewport.MSAA_DISABLED
		RenderingServer.directional_shadow_atlas_set_size(mini(_shadow_size, 2048), true)
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = _msaa
		RenderingServer.directional_shadow_atlas_set_size(_shadow_size, true)


# ---------------------------------------------------------------- battery

func _poll_battery() -> void:
	if _polling:
		return
	match OS.get_name():
		"macOS":
			# pmset spawns a process; keep it off the main thread so frames never hitch.
			_polling = true
			WorkerThreadPool.add_task(_poll_macos)
		"Linux":
			_set_battery(_linux_on_battery())


func _poll_macos() -> void:
	var out := []
	var on := false
	if OS.execute("pmset", ["-g", "batt"], out) == 0 and not out.is_empty():
		on = "Battery Power" in str(out[0])
	_finish_poll.call_deferred(on)


func _finish_poll(on: bool) -> void:
	_polling = false
	_set_battery(on)


func _linux_on_battery() -> bool:
	var base := "/sys/class/power_supply"
	var found_ac := false
	for d in DirAccess.get_directories_at(base):
		var t := FileAccess.get_file_as_string("%s/%s/type" % [base, d]).strip_edges()
		if t == "Mains":
			found_ac = true
			if FileAccess.get_file_as_string("%s/%s/online" % [base, d]).strip_edges() == "1":
				return false
	return found_ac


func _set_battery(on: bool) -> void:
	if on == on_battery:
		return
	var was := saver_active()
	on_battery = on
	if saver_active() != was:
		_apply_saver()
	changed.emit()
