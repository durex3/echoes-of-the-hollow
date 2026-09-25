extends Node

func run(h: Node, game: Node) -> void:
	var ui: GameUI = game.ui
	var notice: RewardNotice = ui.reward_notice
	# Switch using the actual title button; continue availability and focus survive rebuild.
	get_tree().paused = true
	ui.show_menu("title",true)
	(ui.menu.get_node("LanguageButton") as Button).pressed.emit()
	await h.frames(3)
	h.check(Session.language == "zh_CN" and ui.menu.get_child(0).text == "空谷回响", "Title language control switches immediately to Chinese")
	h.check(ui.menu_can_continue and ui.menu.get_node("LanguageButton").has_focus(), "Language switch preserves continue availability and keyboard focus")
	await h.shot("33_chinese_title")
	game.resume()
	game.load_room("belfry","checkpoint")
	await h.frames(4)
	h.check(ui.area_label.text == "07 / 寂静钟楼" and ui.health_label.text.begins_with("生命"), "Current room and vitality use selected Chinese language")
	h.check(ui.prompt.text == "E / 休息并保存", "Interaction prompt is translated")
	Session.flags.erase("belfry_cleared")
	game.room.update_progress()
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await h.frames(3)
	game.player.revive(Vector2(1140,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(notice.visible and notice.title_label.text == "已点亮 · 风信标", "Actual reward interaction displays prominent Chinese reward card")
	h.check(notice.effect_label.text.contains("森林高台") and notice.detail_label.text.contains("生命已全部恢复") and notice.save_label.text == "进度已保存", "Reward explains shortcut healing and confirmed save result")
	h.check(not get_tree().paused and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Reward notice does not pause or capture gameplay input")
	await h.shot("34_chinese_reward")
	var remaining := notice.remaining
	await h.press("interact",2)
	h.check(notice.remaining < remaining, "Repeated claimed reward does not restart notification")
	ui.notify("Restored & saved")
	h.check(notice.title_label.text == "已点亮 · 风信标", "Ordinary toast cannot replace reward explanation")
	get_tree().paused = true
	ui.show_menu("pause")
	await h.frames(2)
	remaining = notice.remaining
	await h.frames(10)
	h.check(notice.remaining == remaining and not notice.visible, "Pause hides reward card and preserves reading time")
	await h.shot("35_chinese_pause")
	(ui.menu.get_node("LanguageButton") as Button).pressed.emit()
	await h.frames(2)
	h.check(Session.language == "en" and get_tree().paused and notice.title_label.text == "WIND BEACON LIT", "Pause language control translates pending reward without resuming")
	game.resume()
	await h.frames(3)
	h.check(notice.visible and notice.remaining < remaining, "Reward returns after pause with remaining reading time")
	await h.shot("36_english_reward")
	Session.set_language("zh_CN")
	game.map_return_paused = false
	get_tree().paused = true
	ui.show_map(game.room.room_id)
	await h.frames(3)
	remaining = notice.remaining
	await h.frames(4)
	h.check(notice.remaining == remaining and ui.world_map.room_label("belfry") == "寂静钟楼", "Chinese map preserves reward timer and translates room names")
	await h.shot("37_chinese_map")
	game.close_map()
	await h.frames(370)
	h.check(not notice.visible and notice.remaining == 0, "Reward card expires after six seconds of visible gameplay")
	# Force a real failed save in the isolated path; reward must not claim saved.
	Session.flags.erase("belfry_cleared")
	game.room.update_progress()
	var save_path := Session.save_path
	Session.save_path = "user://missing_reward_test_directory/save.json"
	await h.press("interact",2)
	h.check(notice.visible and not notice.save_succeeded and notice.save_label.text.contains("保存失败"), "Failed reward save keeps benefit but reports failure truthfully")
	Session.save_path = save_path
	await h.shot("38_chinese_save_failure")
	h.check(Session.set_language("zh_CN") == OK, "Language choice saves to isolated settings")
	Session.language = "en"
	TranslationServer.set_locale("en")
	Session.load_settings()
	h.check(Session.language == "zh_CN" and ui.area_label.text == "07 / 寂静钟楼", "Reloading settings restores language and refreshes existing UI")
	h.check(Session.set_language("invalid") == ERR_INVALID_PARAMETER and Session.language == "zh_CN", "Unsupported language is rejected without changing current selection")
	var catalog_complete := true
	for packed: PackedScene in game.ROOMS.values():
		var room := packed.instantiate() as GameRoom
		catalog_complete = catalog_complete and TextCatalog.ZH.has(room.display_name)
		for point: WorldInteraction in room.get_node("Interactions").get_children():
			catalog_complete = catalog_complete and TextCatalog.ZH.has(point.prompt)
		room.free()
	for values: Array in RewardNotice.REWARDS.values():
		for source: String in values:
			catalog_complete = catalog_complete and TextCatalog.ZH.has(source)
	h.check(catalog_complete, "Every authored room interaction and reward has Chinese translation")
	Session.set_language("en")
	ui.show_menu("pause")
	get_tree().paused = true
	await h.shot("39_english_pause")
	game.resume()
	notice.remaining = 0
	await h.frames(2)
