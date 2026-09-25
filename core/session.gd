extends Node
## Session state uses stable IDs, never node paths or live node references.

signal progress_changed
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

func _ready() -> void:
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
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		reduce_shake = bool(config.get_value("accessibility", "reduce_shake", false))
		reduce_flashes = bool(config.get_value("accessibility", "reduce_flashes", false))

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("accessibility", "reduce_shake", reduce_shake)
	config.set_value("accessibility", "reduce_flashes", reduce_flashes)
	return config.save(settings_path)
