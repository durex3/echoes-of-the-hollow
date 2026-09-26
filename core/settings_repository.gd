class_name SettingsRepository
extends RefCounted
## Versioned ConfigFile; legacy unversioned settings remain readable.
static func valid(config: ConfigFile) -> bool:
	if not config.has_section("accessibility") and not config.has_section("interface") and not config.has_section("meta"):
		return false
	var version: Variant = config.get_value("meta", "version", 0)
	if not version is int or version not in [0, 1]:
		return false
	for key: String in ["music", "sfx"]:
		var value: Variant = config.get_value("audio", key, 1.0)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0 or float(value) > 1:
			return false
	for key: String in ["reduce_shake", "reduce_flashes"]:
		if not config.get_value("accessibility", key, false) is bool:
			return false
	if not config.get_value("display", "fullscreen", false) is bool or config.get_value("interface", "language", "en") not in ["en", "zh_CN"]:
		return false
	var bindings: Variant = config.get_value("input", "bindings", {})
	if not bindings is Dictionary:
		return false
	for action: Variant in bindings:
		if action not in InputBindings.ACTIONS or action == "pause" or not bindings[action] is Dictionary:
			return false
		for kind: Variant in bindings[action]:
			var code: Variant = bindings[action][kind]
			if not code is int or kind not in ["key", "button"]:
				return false
			if (kind == "key" and (code < 1 or code > 0x7fffff)) or (kind == "button" and (code < 0 or code >= JOY_BUTTON_MAX)):
				return false
			if (kind == "key" and code in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]) or (kind == "button" and code in [JOY_BUTTON_START, JOY_BUTTON_GUIDE]):
				return false
	bindings = InputBindings.with_ward_defaults(bindings)
	var used_keys: Array[int] = []
	var used_buttons: Array[int] = []
	for action: String in InputBindings.ACTIONS:
		var custom: Dictionary = bindings.get(action, {})
		var keys: Array[int] = []
		var buttons: Array[int] = []
		var defaults: Dictionary = ProjectSettings.get_setting("input/" + action)
		for event: InputEvent in defaults.events:
			if event is InputEventKey and not custom.has("key"):
				keys.append(event.physical_keycode if event.physical_keycode else event.keycode)
			elif event is InputEventJoypadButton and not custom.has("button"):
				buttons.append(event.button_index)
		if custom.has("key"):
			keys.append(int(custom.key))
		if custom.has("button"):
			buttons.append(int(custom.button))
		for code: int in keys:
			if code in used_keys:
				return false
			used_keys.append(code)
		for code: int in buttons:
			if code in used_buttons:
				return false
			used_buttons.append(code)
	return true

static func load_candidate(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var config := ConfigFile.new()
	# Malformed user data is an expected recoverable case, not an engine fault.
	# Suppression is scoped to the synchronous parser only; all other errors remain visible.
	var print_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	var error := config.load(path)
	Engine.print_error_messages = print_errors
	return config if error == OK and valid(config) else null

static func read(path: String) -> ConfigFile:
	if not path.begins_with("user://"):
		return null
	for suffix: String in ["", ".bak"]:
		var config := load_candidate(path + suffix)
		if config != null:
			return config
	return null

static func write(path: String, config: ConfigFile) -> Error:
	if not path.begins_with("user://") or not valid(config):
		return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(config.encode_to_text())
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if load_candidate(path) != null:
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(path + ".tmp", path)
