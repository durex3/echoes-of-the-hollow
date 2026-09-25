extends SceneTree
const PATH := "user://test_language_cross_process.cfg"

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var session := root.get_node("Session")
	session.settings_path = PATH
	if "--write" in OS.get_cmdline_user_args():
		session.reduce_shake = true
		session.music_volume = 0.35
		session.sfx_volume = 0.7
		session.fullscreen = true
		session.bindings.apply({"jump": {"key": KEY_L}})
		if session.set_language("zh_CN") != OK:
			quit(1)
			return
		print("LANGUAGE_PROCESS_WRITE_OK")
	else:
		session.load_settings()
		if session.language != "zh_CN" or not session.reduce_shake or TextCatalog.text("PAUSED") != "已暂停" or not is_equal_approx(session.music_volume, 0.35) or not is_equal_approx(session.sfx_volume, 0.7) or not session.fullscreen or session.bindings.hint("jump", false) != "L":
			push_error("Language did not survive process restart")
			quit(1)
			return
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(PATH + suffix):
				DirAccess.remove_absolute(PATH + suffix)
		print("LANGUAGE_PROCESS_READ_OK")
	quit()
