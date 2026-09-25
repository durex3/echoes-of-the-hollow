extends SceneTree
const PATH := "user://test_language_cross_process.cfg"

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var session := root.get_node("Session")
	session.settings_path = PATH
	if "--write" in OS.get_cmdline_user_args():
		session.reduce_shake = true
		if session.set_language("zh_CN") != OK:
			quit(1)
			return
		print("LANGUAGE_PROCESS_WRITE_OK")
	else:
		session.load_settings()
		if session.language != "zh_CN" or not session.reduce_shake or TextCatalog.text("PAUSED") != "已暂停":
			push_error("Language did not survive process restart")
			quit(1)
			return
		DirAccess.remove_absolute(PATH)
		print("LANGUAGE_PROCESS_READ_OK")
	quit()
