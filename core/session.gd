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

func snapshot() -> Dictionary:
	return {"version": 1, "checkpoint_room": checkpoint_room,
		"checkpoint_spawn": checkpoint_spawn, "abilities": abilities.duplicate(),
		"visited": visited.duplicate(), "completed": completed}

func reset() -> void:
	checkpoint_room = "forest"
	checkpoint_spawn = "checkpoint"
	abilities.clear()
	visited.clear()
	completed = false
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
