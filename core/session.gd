extends Node
## Session state uses stable IDs, never node paths or live node references.

signal progress_changed
signal language_changed
signal settings_changed
const Repository := preload("res://core/save_repository.gd")
var save_path := "user://progress_v1.json"
var checkpoint_room := "forest"
var checkpoint_spawn := "checkpoint"
var abilities: Array[String] = []
var visited: Array[String] = []
var completed := false
var flags: Array[String] = []
var reduce_shake := false
var reduce_flashes := false
var settings_path := "user://settings.cfg"
var language := "en"
var music_volume := 1.0
var sfx_volume := 1.0
var fullscreen := false
var bindings := InputBindings.new()

func _ready() -> void:
	TextCatalog.install()
	bindings.capture_defaults()
	TextCatalog.input_formatter = bindings.format_text
	load_settings()

func snapshot() -> Dictionary:
	return {"version": Repository.VERSION, "checkpoint_room": checkpoint_room,
		"checkpoint_spawn": checkpoint_spawn, "abilities": abilities.duplicate(),
		"visited": visited.duplicate(), "completed": completed, "flags": flags.duplicate()}

func reset() -> void:
	checkpoint_room = "forest"
	checkpoint_spawn = "checkpoint"
	abilities.clear()
	visited.clear()
	completed = false
	flags.clear()
	progress_changed.emit()

func restore() -> bool:
	var data := Repository.read(save_path)
	if data.is_empty():
		return false
	checkpoint_room = data.checkpoint_room
	checkpoint_spawn = data.checkpoint_spawn
	abilities.assign(data.abilities)
	visited.assign(data.visited)
	completed = data.completed
	flags.assign(data.flags)
	progress_changed.emit()
	return true

func commit() -> Error:
	return Repository.write(save_path, snapshot())

func maximum_health() -> int:
	return 5 + int("heart_bloom" in flags) + int("cistern_heart" in flags)

func unlock(ability: String) -> void:
	if ability not in abilities:
		abilities.append(ability)
		progress_changed.emit()

func visit(room_id: String) -> void:
	if room_id not in visited:
		visited.append(room_id)
		progress_changed.emit()

func set_flag(flag: String) -> void:
	if flag not in flags:
		flags.append(flag)
		progress_changed.emit()

func load_settings() -> void:
	var config := SettingsRepository.read(settings_path)
	if config != null:
		reduce_shake = bool(config.get_value("accessibility", "reduce_shake", false))
		reduce_flashes = bool(config.get_value("accessibility", "reduce_flashes", false))
		var saved_language := str(config.get_value("interface", "language", "en"))
		language = saved_language if saved_language in ["en", "zh_CN"] else "en"
		music_volume = float(config.get_value("audio", "music", 1.0))
		sfx_volume = float(config.get_value("audio", "sfx", 1.0))
		fullscreen = bool(config.get_value("display", "fullscreen", false))
		bindings.apply(config.get_value("input", "bindings", {}))
	TranslationServer.set_locale(language)
	language_changed.emit()
	settings_changed.emit()

func apply_display() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func set_language(value: String) -> Error:
	if value not in ["en", "zh_CN"]:
		return ERR_INVALID_PARAMETER
	language = value
	TranslationServer.set_locale(language)
	language_changed.emit()
	return save_settings()

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("accessibility", "reduce_shake", reduce_shake)
	config.set_value("accessibility", "reduce_flashes", reduce_flashes)
	config.set_value("interface", "language", language)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("input", "bindings", bindings.overrides)
	settings_changed.emit()
	return SettingsRepository.write(settings_path, config)
