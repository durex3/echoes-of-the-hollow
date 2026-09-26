class_name InputBindings
extends RefCounted
## Owns mappings and prompt formatting; gameplay still reads InputMap actions.
signal changed
const ACTIONS := ["move_left", "move_right", "jump", "attack", "dash", "interact", "world_map", "pause", "mute", "steam_ward"]
const TITLES := ["Move left", "Move right", "Jump", "Attack", "Dash", "Interact", "Map", "Pause", "Mute", "Steam ward"]
const PAD_NAMES := {0: "A / Cross", 1: "B / Circle", 2: "X / Square", 3: "Y / Triangle", 4: "Back", 6: "Start", 9: "LB / L1", 10: "RB / R1", 11: "D-pad Up", 12: "D-pad Down", 13: "D-pad Left", 14: "D-pad Right"}
var defaults: Dictionary = {}
var overrides: Dictionary = {}
var gamepad := false

func capture_defaults() -> void:
	for action: String in ACTIONS:
		defaults[action] = InputMap.action_get_events(action)

func observe(event: InputEvent) -> void:
	var next := gamepad
	if event is InputEventKey and event.pressed:
		next = false
	elif event is InputEventJoypadButton and event.pressed:
		next = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.55:
		next = true
	if next != gamepad:
		gamepad = next
		changed.emit()

func apply(values: Dictionary) -> void:
	overrides = with_ward_defaults(values)
	for action: String in ACTIONS:
		InputMap.action_erase_events(action)
		var custom: Dictionary = overrides.get(action, {})
		for event: InputEvent in defaults[action]:
			if event is InputEventKey and custom.has("key"):
				continue
			if event is InputEventJoypadButton and custom.has("button"):
				continue
			InputMap.action_add_event(action, event)
		if custom.has("key"):
			var key := InputEventKey.new()
			key.physical_keycode = int(custom.key) as Key
			InputMap.action_add_event(action, key)
		if custom.has("button"):
			var button := InputEventJoypadButton.new()
			button.button_index = int(custom.button) as JoyButton
			InputMap.action_add_event(action, button)
	changed.emit()

static func with_ward_defaults(values: Dictionary) -> Dictionary:
	# Preserve legacy rebinds that occupied the newly introduced L / LB defaults.
	var result := values.duplicate(true)
	var ward: Dictionary = result.get("steam_ward", {})
	for kind: String in ["key", "button"]:
		if ward.has(kind):
			continue
		var used: Array[int] = []
		for action: String in ACTIONS:
			if action == "steam_ward":
				continue
			var custom: Dictionary = result.get(action, {})
			if custom.has(kind):
				used.append(int(custom[kind]))
				continue
			var definition: Dictionary = ProjectSettings.get_setting("input/"+action)
			for event: InputEvent in definition.events:
				if kind == "key" and event is InputEventKey:
					used.append(event.physical_keycode if event.physical_keycode else event.keycode)
				elif kind == "button" and event is InputEventJoypadButton:
					used.append(event.button_index)
		var default_code: int = KEY_L if kind == "key" else JOY_BUTTON_LEFT_SHOULDER
		if default_code not in used:
			continue
		var candidates: Array = range(KEY_A, KEY_Z+1) if kind == "key" else range(JOY_BUTTON_MAX)
		for code: int in candidates:
			if code in used or (kind == "button" and code in [JOY_BUTTON_START, JOY_BUTTON_GUIDE]):
				continue
			ward[kind] = code
			break
	if not ward.is_empty():
		result["steam_ward"] = ward
	return result

func rebind(action: String, event: InputEvent) -> String:
	if action not in ACTIONS:
		return "Unsupported input"
	if action == "pause":
		return "Reserved for menu navigation"
	var kind := ""
	var code := 0
	if event is InputEventKey:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
			return "Use a single key without modifiers"
		kind = "key"
		code = event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] or code == 0:
			return "Reserved for menu navigation"
	elif event is InputEventJoypadButton:
		kind = "button"
		code = event.button_index
		if code in [JOY_BUTTON_START, JOY_BUTTON_GUIDE]:
			return "Reserved for menu navigation"
	else:
		return "Press a keyboard key or gamepad button"
	for other: String in ACTIONS:
		if other == action:
			continue
		for mapped: InputEvent in InputMap.action_get_events(other):
			if (kind == "key" and mapped is InputEventKey and (mapped.physical_keycode == code or mapped.keycode == code)) or (kind == "button" and mapped is InputEventJoypadButton and mapped.button_index == code):
				return "Already assigned: " + TextCatalog.text(TITLES[ACTIONS.find(other)])
	var next := overrides.duplicate(true)
	if not next.has(action):
		next[action] = {}
	next[action][kind] = code
	apply(next)
	return ""

func hint(action: String, pad_override := -1) -> String:
	var pad := gamepad if pad_override == -1 else bool(pad_override)
	for event: InputEvent in InputMap.action_get_events(action):
		if pad and event is InputEventJoypadButton:
			return str(PAD_NAMES.get(event.button_index, "Button %d" % (event.button_index + 1)))
		if not pad and event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	return "--"

func format_text(source: String, translated: String) -> String:
	if source == "L: ward for 1.5s. Blocks one steam plume; cooldown 5s.":
		return ("按 %s 防护1.5秒，抵挡一轮喷流；冷却5秒。" if TranslationServer.get_locale() == "zh_CN" else "%s: ward for 1.5s. Blocks one steam plume; cooldown 5s.") % hint("steam_ward")
	if source.begins_with("E "):
		return hint("interact") + translated.substr(1)
	if source == "Press SPACE again in the air.":
		return ("在空中再次按 %s，即可二段跳。" if TranslationServer.get_locale() == "zh_CN" else "Press %s again in the air.") % hint("jump")
	if source in ["K / Right shoulder to dash. No invincibility.", "K: dash through wind. No invincibility."]:
		return ("按 %s 冲刺；冲刺不提供无敌。" if TranslationServer.get_locale() == "zh_CN" else "%s: dash through wind. No invincibility.") % hint("dash")
	return translated
