extends SceneTree
const Repository := preload("res://core/save_repository.gd")
const PATH := "user://test_cross_process.json"

func _initialize() -> void:
	if "--write" in OS.get_cmdline_user_args():
		var result := Repository.write(PATH, {"version":1,"checkpoint_room":"ruins",
			"checkpoint_spawn":"checkpoint","abilities":["double_jump"],"visited":["forest","ruins"],"completed":true})
		if result != OK:
			push_error("Cross-process write failed")
			quit(1)
			return
		print("SAVE_PROCESS_WRITE_OK")
	else:
		var data := Repository.read(PATH)
		if data.is_empty() or data.checkpoint_room != "ruins" or not data.completed or "double_jump" not in data.abilities:
			push_error("Cross-process restore failed")
			quit(1)
			return
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(PATH+suffix):
				DirAccess.remove_absolute(PATH+suffix)
		print("SAVE_PROCESS_READ_OK")
	quit()
