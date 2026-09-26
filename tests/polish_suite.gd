extends Node

func key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func run(h: Node, game: Node) -> void:
	var ui: GameUI = game.ui
	var player: Player = game.player
	Session.set_language("zh_CN")
	game.load_room("atrium", "checkpoint")
	await h.frames(4)
	h.check(ui.vitality_pips.current == player.health.current and ui.vitality_pips.maximum == player.health.maximum, "Vitality icons follow actual health events")
	h.check(ui.dash_status == "Dash ready", "Grounded unlocked dash displays ready")
	await h.press("jump", 12)
	await h.press("dash", 3)
	h.check(ui.dash_status == "Dashing", "Dash state signal updates HUD during actual dash")
	await h.frames(25)
	h.check(ui.dash_status in ["Dash: land to recharge", "Dash recharging"], "Air dash availability reflects cooldown and landing restriction")
	await h.frames(45)
	h.check(ui.dash_status == "Dash ready", "Landing restores dash status")
	await h.shot("58_vitality_dash")
	get_tree().paused = true
	ui.show_menu("pause")
	(ui.menu.get_node("SettingsButton") as Button).pressed.emit()
	await h.frames(3)
	var panel: SettingsPanel = ui.settings_panel
	h.check(panel.visible and not ui.modal.visible and panel.back_button.has_focus(), "Settings opens with focus above paused gameplay")
	var at := player.position
	var volume := panel.find_child("music_volume", true, false) as HSlider
	volume.value = 35
	h.check(is_equal_approx(Session.music_volume, 0.35) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.35)) < 0.01, "Music slider changes the actual bus at the requested gain")
	(panel.find_child("sfx_volume", true, false) as HSlider).value = 0
	h.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Zero sound volume truly mutes the effects bus")
	await h.shot("59_settings_chinese")
	if h.visual:
		var full: CheckButton
		for child: Node in panel.rows.get_children():
			if child is CheckButton and child.text == "全屏显示":
				full = child
		full.button_pressed = true
		await h.frames(4)
		h.check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen control changes the actual game window mode")
		full.button_pressed = false
		await h.frames(4)
		h.check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode restores through the same control")
	(panel.binding_buttons["jump"] as Button).pressed.emit()
	Input.parse_input_event(key(KEY_J))
	await h.frames(2)
	Input.parse_input_event(key(KEY_J, false))
	h.check(panel.capture_action == "jump" and panel.status.text.begins_with("该按键已用于"), "Rebinding rejects an occupied key with a visible translated explanation")
	Input.parse_input_event(key(KEY_ESCAPE))
	await h.frames(2)
	Input.parse_input_event(key(KEY_ESCAPE, false))
	h.check(panel.visible and panel.capture_action.is_empty() and get_tree().paused, "Escape cancels capture without closing settings or resuming gameplay")
	(panel.binding_buttons["jump"] as Button).pressed.emit()
	var cancel_pad := InputEventJoypadButton.new()
	cancel_pad.button_index = JOY_BUTTON_START
	cancel_pad.pressed = true
	Input.parse_input_event(cancel_pad)
	await h.frames(2)
	cancel_pad.pressed = false
	Input.parse_input_event(cancel_pad)
	h.check(panel.capture_action.is_empty() and panel.visible, "Gamepad Start cancels binding capture without trapping controller users")
	(panel.binding_buttons["jump"] as Button).pressed.emit()
	Input.parse_input_event(key(KEY_U))
	await h.frames(2)
	Input.parse_input_event(key(KEY_U, false))
	h.check(Session.bindings.hint("jump", false) == "U" and ui.controls.text.contains("U 跳跃"), "Accepted keyboard rebind updates InputMap and displayed controls")
	h.check(TextCatalog.text("Press SPACE again in the air.").contains("U"), "Ability reward instructions use the rebound jump key")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	(panel.binding_buttons["attack"] as Button).pressed.emit()
	Input.parse_input_event(button)
	await h.frames(2)
	button.pressed = false
	Input.parse_input_event(button)
	h.check(Session.bindings.gamepad and ui.controls.text.contains("B / Circle") and TextCatalog.text("E / REST & SAVE").begins_with("Y / Triangle"), "Gamepad rebind changes device hints and interaction prompts")
	panel.scroll.ensure_control_visible(panel.binding_buttons["attack"])
	await h.frames(3)
	await h.shot("60_settings_bindings")
	h.check(player.position == at, "Rebinding and menus never move the paused player")
	var path := Session.settings_path
	Session.settings_path = "user://missing_polish_settings_directory/settings.cfg"
	panel.save()
	h.check(panel.status.text.contains("设置保存失败"), "Settings write failure stays visible inside the settings panel")
	await h.shot("61_settings_failure")
	Session.settings_path = path
	panel.close()
	h.check(get_tree().paused and ui.modal.visible and ui.menu.get_node("SettingsButton").has_focus(), "Back returns focus to Settings without resuming gameplay")
	game.resume()
	await h.frames(3)
	await h.shot("66_gamepad_hud")
	h.check(ui.controls.get_minimum_size().x <= 600, "Gamepad controls fit the reference viewport width")
	Session.bindings.observe(key(KEY_U))
	Input.parse_input_event(key(KEY_U))
	await h.frames(4)
	h.check(player.velocity.y < 0, "Rebound physical key actually jumps in gameplay")
	Input.parse_input_event(key(KEY_U, false))
	await h.frames(55)
	Session.save_settings()
	Session.bindings.apply({})
	Session.music_volume = 1
	Session.load_settings()
	h.check(Session.bindings.hint("jump", false) == "U" and is_equal_approx(Session.music_volume, 0.35), "Reload restores custom bindings and volume together")
	Session.save_settings()
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("[broken")
	corrupt.close()
	h.check(SettingsRepository.read(path) != null, "Corrupt settings primary recovers its validated backup")
	h.check(Session.save_settings() == OK, "Recovered settings can repair the primary")
	var invalid := ConfigFile.new()
	invalid.set_value("meta", "version", 99)
	h.check(not SettingsRepository.valid(invalid), "Settings reject future versions")
	invalid.set_value("meta", "version", 1)
	invalid.set_value("audio", "music", -0.1)
	h.check(not SettingsRepository.valid(invalid), "Settings reject out-of-range volume")
	invalid.set_value("audio", "music", 0.5)
	invalid.set_value("input", "bindings", {"jump": {"key": KEY_J}})
	h.check(not SettingsRepository.valid(invalid), "Settings reject persisted duplicate bindings")
	invalid.set_value("input", "bindings", {"pause": {"key": KEY_L}})
	h.check(not SettingsRepository.valid(invalid), "Persisted bindings cannot remove the escape route to menus")
	Session.bindings.apply({})
	Session.bindings.observe(key(KEY_A))
	Session.music_volume = 1
	Session.sfx_volume = 1
	Session.save_settings()
	h.check(Session.bindings.hint("jump", false) == "Space" and Session.bindings.hint("attack", true) == "X / Square", "Reset restores original keyboard and gamepad bindings")
	# No actual restart: cancelling must retain the existing session and saved bytes.
	get_tree().paused = true
	ui.show_menu("title", true)
	var before := FileAccess.get_file_as_string(Session.save_path)
	ui.request_new_journey()
	await h.frames(3)
	h.check(ui.confirmation.visible, "New journey with a valid save requires a native confirmation")
	await h.shot("62_new_journey_confirmation")
	ui.confirmation.get_cancel_button().pressed.emit()
	ui.confirmation.hide()
	h.check(FileAccess.get_file_as_string(Session.save_path) == before and "journey_restored" in Session.flags, "Cancelling new journey preserves progress and file contents")
	ui.show_menu("pause")
	ui.show_map("atrium")
	await h.frames(3)
	h.check(ui.map_progress.text.count("[+]") == 3, "Map shows all three earned marks from persistent flags")
	await h.shot("63_map_marks")
	var map: WorldMap = ui.world_map
	map.configure("forest", ["forest"], "forest", [], [])
	h.check(map.room_label("ruins") == "尚未探索" and not map.revealed("scriptorium") and map.target_room() == "ruins", "Next-objective marker does not reveal hidden room names")
	h.check(map.gate_requirement("forest", "atrium") == "Three marks" and map.gate_requirement("training", "scriptorium").is_empty(), "Only known source rooms reveal gate requirements")
	Session.flags.erase("belfry_cleared")
	Session.flags.erase("journey_restored")
	Session.flags.erase("warden_defeated")
	ui.show_map("forest")
	await h.frames(3)
	await h.shot("64_map_missing_mark")
	Session.flags.append("belfry_cleared")
	Session.flags.append("journey_restored")
	Session.flags.append("warden_defeated")
	game.resume()
	Session.set_language("en")
	get_tree().paused = true
	ui.show_menu("pause")
	(ui.menu.get_node("SettingsButton") as Button).pressed.emit()
	await h.frames(3)
	await h.shot("65_settings_english")
	panel.close()
	game.resume()
	# Frame contents, not just resource references: every used frame must be visible.
	var armor := preload("res://features/enemies/living_armor.tscn").instantiate() as LivingArmor
	game.add_child(armor)
	armor.set_physics_process(false)
	var visible_frames := true
	for clip: StringName in armor.sprite.sprite_frames.get_animation_names():
		for index: int in range(armor.sprite.sprite_frames.get_frame_count(clip)):
			var texture := armor.sprite.sprite_frames.get_frame_texture(clip, index) as AtlasTexture
			visible_frames = visible_frames and not texture.atlas.get_image().get_region(Rect2i(texture.region)).is_invisible()
	h.check(visible_frames, "All ordinary armor frames contain visible pixels including death")
	armor._enter(LivingArmor.State.RECOVER)
	var frames := armor.sprite.sprite_frames
	var duration := frames.get_frame_count("recover") / (frames.get_animation_speed("recover") * armor.sprite.speed_scale)
	h.check(absf(duration - armor.config.attack.recovery) < 0.001, "Corrected four-frame recovery preserves the original combat window")
	armor.sprite.frame = 3
	armor._enter(LivingArmor.State.RECOVER)
	h.check(armor.sprite.frame == 0, "Repeated recovery restarts the animation from its first frame")
	armor.queue_free()
	await h.frames(2)
