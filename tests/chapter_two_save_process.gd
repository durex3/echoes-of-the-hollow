extends SceneTree
const PATH := "user://test_chapter_two_cross_process.json"

func _initialize() -> void:
	if "--write" in OS.get_cmdline_user_args():
		var data := {"version":2,"checkpoint_room":"echo_vault","checkpoint_spawn":"checkpoint","abilities":["double_jump","dash"],"visited":["heart_chamber","ember_quay","valve_gallery","cistern_archive","furnace_core","sluice_shaft","pump_chamber","echo_vault"],"completed":false,"flags":["warden_defeated","journey_restored","flow_seal","pressure_seal","cistern_restored","cistern_heart"]}
		if SaveRepository.write(PATH,data) != OK:
			push_error("Chapter II cross-process write failed")
			quit(1)
			return
		print("CHAPTER_TWO_SAVE_WRITE_OK")
	else:
		var data := SaveRepository.read(PATH)
		if data.is_empty() or data.checkpoint_room != "echo_vault" or data.visited.size() != 8 or "cistern_restored" not in data.flags or "flow_seal" not in data.flags or "pressure_seal" not in data.flags or "cistern_heart" not in data.flags:
			push_error("Chapter II cross-process restore failed")
			quit(1)
			return
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(PATH+suffix):
				DirAccess.remove_absolute(PATH+suffix)
		print("CHAPTER_TWO_SAVE_READ_OK")
	quit()
