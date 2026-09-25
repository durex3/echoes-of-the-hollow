extends SceneTree
const Repository := preload("res://core/save_repository.gd")
const PATH := "user://test_cross_process.json"

func _initialize() -> void:
	if "--write" in OS.get_cmdline_user_args():
		var result := Repository.write(PATH, {"version":2,"checkpoint_room":"atrium",
			"checkpoint_spawn":"checkpoint","abilities":["double_jump","dash"],"visited":["forest","ruins","training","scriptorium","sanctuary","wind_hall","belfry","atrium"],"completed":true,"flags":["training_cleared","scriptorium_cleared","heart_bloom","wind_passage_open","belfry_cleared"]})
		if result != OK:
			push_error("Cross-process write failed")
			quit(1)
			return
		print("SAVE_PROCESS_WRITE_OK")
	else:
		var data := Repository.read(PATH)
		if data.is_empty() or data.checkpoint_room != "atrium" or data.checkpoint_spawn != "checkpoint" or not data.completed or "double_jump" not in data.abilities or "dash" not in data.abilities or "training_cleared" not in data.flags or "scriptorium_cleared" not in data.flags or "heart_bloom" not in data.flags or "wind_passage_open" not in data.flags or "belfry_cleared" not in data.flags or "wind_hall" not in data.visited or "belfry" not in data.visited or "atrium" not in data.visited:
			push_error("Cross-process restore failed")
			quit(1)
			return
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(PATH+suffix):
				DirAccess.remove_absolute(PATH+suffix)
		print("SAVE_PROCESS_READ_OK")
	quit()
