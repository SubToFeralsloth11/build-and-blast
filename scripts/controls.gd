extends Node
## Input channels that vehicle blocks listen to. Values update once per physics
## tick before any vehicle runs. `sim` lets tests drive channels directly.

const CHANNELS := [
	["throttle", "Throttle  W / S"],
	["steer", "Steer  A / D"],
	["pitch", "Pitch  Up / Down"],
	["roll", "Roll  Left / Right"],
	["yaw", "Yaw  Q / E"],
	["lift", "Lift  Space / C"],
	["boost", "Boost  Shift"],
	["fire1", "Fire 1  Left Mouse"],
	["fire2", "Fire 2  Right Mouse"],
	["fire3", "Fire 3  G"],
	["act1", "Toggle 1"],
	["act2", "Toggle 2"],
	["act3", "Toggle 3"],
	["act4", "Trigger 4"],
	["horn", "Horn  H"],
	["always", "Always on"],
]

const TOGGLES := ["act1", "act2", "act3"]

var enabled := false
var sim := {}
var vals := {}
var prev := {}
var toggles := {"act1": false, "act2": false, "act3": false}


func _ready() -> void:
	process_physics_priority = -100
	process_priority = -100
	_bind("v_fwd", [KEY_W])
	_bind("v_back", [KEY_S])
	_bind("v_left", [KEY_A])
	_bind("v_right", [KEY_D])
	_bind("v_pitch_up", [KEY_UP, KEY_I])
	_bind("v_pitch_down", [KEY_DOWN, KEY_K])
	_bind("v_roll_left", [KEY_LEFT, KEY_J])
	_bind("v_roll_right", [KEY_RIGHT, KEY_L])
	_bind("v_yaw_left", [KEY_Q])
	_bind("v_yaw_right", [KEY_E])
	_bind("v_up", [KEY_SPACE])
	_bind("v_down", [KEY_C, KEY_CTRL])
	_bind("v_boost", [KEY_SHIFT])
	_bind("v_fire3", [KEY_G])
	_bind("v_act1", [KEY_1])
	_bind("v_act2", [KEY_2])
	_bind("v_act3", [KEY_3])
	_bind("v_act4", [KEY_4])
	_bind("v_horn", [KEY_H])
	for c in CHANNELS:
		vals[c[0]] = 0.0
		prev[c[0]] = 0.0


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


static func label(ch: String) -> String:
	for c in CHANNELS:
		if c[0] == ch:
			return c[1]
	return ch


static func index_of(ch: String) -> int:
	for i in CHANNELS.size():
		if CHANNELS[i][0] == ch:
			return i
	return 0


func reset_toggles() -> void:
	for k in toggles:
		toggles[k] = false


func _physics_process(_delta: float) -> void:
	prev = vals.duplicate()
	if not sim.is_empty():
		for c in CHANNELS:
			vals[c[0]] = float(sim.get(c[0], 0.0))
		vals["always"] = 1.0
		return
	for c in CHANNELS:
		vals[c[0]] = 0.0
	vals["always"] = 1.0
	if not enabled:
		for t in TOGGLES:
			vals[t] = 1.0 if toggles[t] else 0.0
		return
	vals["throttle"] = Input.get_axis("v_back", "v_fwd")
	vals["steer"] = Input.get_axis("v_left", "v_right")
	vals["pitch"] = Input.get_axis("v_pitch_down", "v_pitch_up")
	vals["roll"] = Input.get_axis("v_roll_left", "v_roll_right")
	vals["yaw"] = Input.get_axis("v_yaw_left", "v_yaw_right")
	vals["lift"] = Input.get_axis("v_down", "v_up")
	vals["boost"] = 1.0 if Input.is_action_pressed("v_boost") else 0.0
	vals["fire1"] = 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
	vals["fire2"] = 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	vals["fire3"] = 1.0 if Input.is_action_pressed("v_fire3") else 0.0
	vals["act4"] = 1.0 if Input.is_action_pressed("v_act4") else 0.0
	vals["horn"] = 1.0 if Input.is_action_pressed("v_horn") else 0.0
	for t in TOGGLES:
		if Input.is_action_just_pressed("v_" + t):
			toggles[t] = not toggles[t]
		vals[t] = 1.0 if toggles[t] else 0.0


func value(ch: String) -> float:
	return vals.get(ch, 0.0)


func on(ch: String) -> bool:
	return vals.get(ch, 0.0) > 0.5


func just(ch: String) -> bool:
	return vals.get(ch, 0.0) > 0.5 and prev.get(ch, 0.0) <= 0.5
