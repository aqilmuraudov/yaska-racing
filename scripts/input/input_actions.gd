class_name InputActions
extends RefCounted
## Single source of truth for gameplay input actions.
##
## Keyboard, controller and touch all drive these actions; gameplay code only
## reads actions (through PlayerInput), never devices. Defaults are registered
## at boot and user remaps are layered on top from Settings.

const ACCELERATE := &"accelerate"
const BRAKE := &"brake"
const STEER_LEFT := &"steer_left"
const STEER_RIGHT := &"steer_right"
const DRIFT := &"drift"
const BOOST := &"boost"
const USE_ITEM := &"use_item"
const LOOK_BACK := &"look_back"
const RECOVER := &"recover"
const PAUSE := &"pause"
const CAMERA := &"camera_cycle"
const NITRO := &"nitro" ## garage add-on (0.8.0); not in the remap list

## Order used by the remapping screen.
const GAMEPLAY_ACTIONS: Array[StringName] = [
	ACCELERATE, BRAKE, STEER_LEFT, STEER_RIGHT, DRIFT, BOOST, USE_ITEM, LOOK_BACK, CAMERA, RECOVER, PAUSE,
]

## Analog actions read with strength (deadzone applied by InputMap).
const ANALOG_ACTIONS: Array[StringName] = [ACCELERATE, BRAKE, STEER_LEFT, STEER_RIGHT]

# Descriptors: ["key", Key] | ["joy_button", JoyButton] | ["joy_axis", JoyAxis, sign]
const DEFAULTS := {
	ACCELERATE: [["key", KEY_W], ["key", KEY_UP], ["joy_button", JOY_BUTTON_A], ["joy_axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	BRAKE: [["key", KEY_S], ["key", KEY_DOWN], ["joy_button", JOY_BUTTON_X], ["joy_axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	STEER_LEFT: [["key", KEY_A], ["key", KEY_LEFT], ["joy_button", JOY_BUTTON_DPAD_LEFT], ["joy_axis", JOY_AXIS_LEFT_X, -1.0]],
	STEER_RIGHT: [["key", KEY_D], ["key", KEY_RIGHT], ["joy_button", JOY_BUTTON_DPAD_RIGHT], ["joy_axis", JOY_AXIS_LEFT_X, 1.0]],
	DRIFT: [["key", KEY_SPACE], ["key", KEY_K], ["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	BOOST: [["key", KEY_SHIFT], ["key", KEY_J], ["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	USE_ITEM: [["key", KEY_E], ["key", KEY_L], ["joy_button", JOY_BUTTON_B]],
	LOOK_BACK: [["key", KEY_Q], ["key", KEY_I], ["joy_button", JOY_BUTTON_Y]],
	CAMERA: [["key", KEY_C], ["joy_button", JOY_BUTTON_RIGHT_STICK]],
	RECOVER: [["key", KEY_R], ["joy_button", JOY_BUTTON_BACK]],
	NITRO: [["key", KEY_N], ["key", KEY_H]],
	PAUSE: [["key", KEY_ESCAPE], ["key", KEY_P], ["joy_button", JOY_BUTTON_START]],
}

const DEFAULT_DEADZONE := 0.2


static func register_defaults(deadzone: float = DEFAULT_DEADZONE) -> void:
	for action in DEFAULTS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, deadzone)
		for desc in DEFAULTS[action]:
			InputMap.action_add_event(action, descriptor_to_event(desc))


static func set_deadzone(deadzone: float) -> void:
	for action in ANALOG_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, deadzone)


## Applies remaps: { action: [descriptor, ...] } replacing that action's events.
static func apply_overrides(overrides: Dictionary) -> void:
	for action in overrides.keys():
		var sn := StringName(action)
		if not InputMap.has_action(sn) or typeof(overrides[action]) != TYPE_ARRAY:
			continue
		var events: Array[InputEvent] = []
		for desc in overrides[action]:
			var ev := descriptor_to_event(desc)
			if ev != null:
				events.append(ev)
		if events.is_empty():
			continue # never leave an action unbound by a bad save
		InputMap.action_erase_events(sn)
		for ev in events:
			InputMap.action_add_event(sn, ev)


static func descriptor_to_event(desc: Array) -> InputEvent:
	if desc.is_empty():
		return null
	match String(desc[0]):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(desc[1])
			return k
		"joy_button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(desc[1])
			b.device = -1
			return b
		"joy_axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(desc[1])
			a.axis_value = float(desc[2]) if desc.size() > 2 else 1.0
			a.device = -1
			return a
	return null


static func event_to_descriptor(ev: InputEvent) -> Array:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return ["key", code]
	if ev is InputEventJoypadButton:
		return ["joy_button", ev.button_index]
	if ev is InputEventJoypadMotion:
		return ["joy_axis", ev.axis, signf(ev.axis_value)]
	return []


static func describe_descriptor(desc: Array, prefer_pad_style: String = "xbox") -> String:
	if desc.is_empty():
		return "—"
	match String(desc[0]):
		"key":
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(int(desc[1])))
		"joy_button":
			return joy_button_name(int(desc[1]), prefer_pad_style)
		"joy_axis":
			return joy_axis_name(int(desc[1]), float(desc[2]) if desc.size() > 2 else 1.0)
	return "?"


static func joy_button_name(button: int, style: String) -> String:
	var xbox := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "View",
		JOY_BUTTON_START: "Menu", JOY_BUTTON_DPAD_LEFT: "D-Pad ←", JOY_BUTTON_DPAD_RIGHT: "D-Pad →",
		JOY_BUTTON_DPAD_UP: "D-Pad ↑", JOY_BUTTON_DPAD_DOWN: "D-Pad ↓", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"}
	var ps := {JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "Share",
		JOY_BUTTON_START: "Options", JOY_BUTTON_DPAD_LEFT: "D-Pad ←", JOY_BUTTON_DPAD_RIGHT: "D-Pad →",
		JOY_BUTTON_DPAD_UP: "D-Pad ↑", JOY_BUTTON_DPAD_DOWN: "D-Pad ↓", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}
	var nintendo := {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_BACK: "−",
		JOY_BUTTON_START: "+"}
	var table: Dictionary = xbox
	if style == "playstation":
		table = ps
	elif style == "nintendo":
		table = nintendo
	if table.has(button):
		return table[button]
	if xbox.has(button):
		return xbox[button]
	return "Btn %d" % button


static func joy_axis_name(axis: int, sign_value: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		JOY_AXIS_LEFT_X: return "L-Stick ←" if sign_value < 0 else "L-Stick →"
		JOY_AXIS_LEFT_Y: return "L-Stick ↑" if sign_value < 0 else "L-Stick ↓"
	return "Axis %d" % axis


## Guesses the pad family for button prompts from the device name.
static func pad_style_for_device(device: int) -> String:
	var n := Input.get_joy_name(device).to_lower()
	if n.contains("ps") or n.contains("dualshock") or n.contains("dualsense") or n.contains("playstation") or n.contains("sony"):
		return "playstation"
	if n.contains("nintendo") or n.contains("switch") or n.contains("joy-con"):
		return "nintendo"
	return "xbox"
