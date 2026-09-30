extends Node
## Isolated component/flow tests. Continuous traversal lives in chapter_two_route.

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	game.ui.reward_notice.remaining = 0
	Session.flags.erase("journey_restored")
	Session.flags.erase("warden_defeated")
	game.load_room("heart_chamber","chapter_return")
	await h.frames(4)
	var entry: WorldInteraction = game.room.get_node("Interactions/ChapterDoor")
	h.check(not entry.visible and not entry.locked_message(Session.abilities,Session.flags).is_empty(), "Chapter II door stays hidden before the warden falls")
	game.room.get_node("Enemies/Warden/Health").take_damage(99, player.position)
	await h.frames(3)
	game.room.update_progress()
	h.check(entry.visible and entry.position.x == 560, "Warden victory reveals the right Chapter II door")
	player.revive(entry.position)
	await h.frames(3)
	await h.press("interact",2)
	# First use presents the ending; using the door again continues to Chapter II.
	h.check("journey_restored" in Session.flags and game.ui.menu_mode == "finale", "Right victory door presents the first chapter ending")
	game.resume()
	await h.press("interact",2)
	h.check(game.room.room_id == "ember_quay", "Right victory door enters Chapter II after its ending")
	await h.frames(25)
	h.check(player.is_on_floor(), "Chapter II entry lands on authored tile collision")
	player.revive(Vector2(180,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.checkpoint_room == "ember_quay" and Session.commit() == OK, "New chapter shrine persists a valid checkpoint")
	var gate: WorldInteraction = game.room.get_node("Interactions/CoreDoor")
	for mask: int in range(3):
		Session.flags.erase("flow_seal")
		Session.flags.erase("pressure_seal")
		if mask & 1:
			Session.set_flag("flow_seal")
		if mask & 2:
			Session.set_flag("pressure_seal")
		h.check(not gate.locked_message(Session.abilities,Session.flags).is_empty(), "Furnace requires both valve seals: combination %d" % mask)
	Session.flags.erase("pressure_seal")
	var vent := game.room.get_node("Hazards").get_child(0) as SteamVent
	player.revive(Vector2(440,480))
	vent.phase = SteamVent.Phase.REST
	vent.elapsed = 0
	await h.frames(8)
	var hp := player.health.current
	h.check(player.health.current == hp and hp == player.health.maximum, "Resting steam vent is harmless while overlapping")
	vent.phase = SteamVent.Phase.WARNING
	vent.elapsed = 0
	await h.frames(12)
	h.check(player.health.current == hp, "Steam warning does not deal damage")
	Session.set_language("zh_CN")
	game.ui.set_text(game.ui.toast, "")
	await h.shot("70_steam_warning")
	vent.phase = SteamVent.Phase.ACTIVE
	vent.elapsed = 0
	await h.frames(3)
	h.check(player.health.current == hp - 1, "Actual steam overlap deals exactly one damage initially")
	var frozen := vent.elapsed
	get_tree().paused = true
	await h.frames(8)
	h.check(vent.elapsed == frozen, "Pause freezes steam cycle timing")
	get_tree().paused = false
	await h.shot("71_steam_active")
	player.revive(Vector2(180,480))
	# Observe a full unmodified physical cycle; shared config is never rewritten.
	vent.phase = SteamVent.Phase.REST
	vent.elapsed = 0
	await h.frames(145)
	h.check(vent.phase == SteamVent.Phase.WARNING, "Steam naturally advances from rest to its full warning")
	await h.frames(60)
	h.check(vent.phase == SteamVent.Phase.ACTIVE, "Steam naturally begins its active plume after warning")
	await h.frames(60)
	h.check(vent.phase == SteamVent.Phase.REST, "Steam naturally returns to a safe rest window")
	var bounds := vent.config.plume_size
	h.check(bounds == Vector2(64,80) and (vent.get_node("Shape").shape as RectangleShape2D).size == bounds, "Steam visible plume and damage shape share the same configured dimensions")
	await h.frames(4)
	await h.press("interact",2)
	player.health.invulnerability_left = 0
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "ember_quay" and player.health.current == player.health.maximum and absf(player.position.x-180)<2, "Chapter II death returns to its safe shrine with full health")
	for id: String in ["sluice_shaft", "pump_chamber"]:
		game.load_room(id,"entry")
		await h.frames(4)
		var seal: WorldInteraction = game.room.get_node("Interactions/Seal")
		game._on_interaction(seal)
		h.check(seal.stable_id not in Session.flags, "Uncleared %s cannot award a valve seal" % id)
		# Component test isolates claim semantics; route tests fight these enemies normally.
		for enemy: Node in game.room.get_node("Enemies").get_children():
			enemy.queue_free()
		await h.frames(3)
		player.revive(seal.position)
		await h.frames(4)
		await h.press("interact",2)
		h.check(seal.stable_id in Session.flags and not seal.visible and game.ui.reward_notice.save_succeeded, "%s seal is unique, hidden and saved after claiming" % id)
		game._on_interaction(seal)
		h.check(Session.flags.count(seal.stable_id) == 1, "%s duplicate reward is rejected" % id)
		await h.shot("72_" + id + "_reward")
	game.load_room("ember_quay","core_return")
	await h.frames(4)
	gate = game.room.get_node("Interactions/CoreDoor")
	h.check(gate.locked_message(Session.abilities,Session.flags).is_empty(), "Both valve seals open the furnace gate")
	game.ui.reward_notice.remaining = 0
	game.ui.set_text(game.ui.toast, "")
	game.ui.show_map("ember_quay")
	h.check(game.ui.world_map.room_label("furnace_core") == TextCatalog.room_name("furnace_core") and game.ui.world_map.target_room() == "furnace_core", "Unlocked boss destination is named before the first visit")
	await h.shot("72b_furnace_route_map")
	game.ui.hide_map()
	player.revive(Vector2(1160,480))
	await h.frames(3)
	await h.shot("72c_furnace_gold_door")
	player.health.take_damage(1,player.position)
	var entry_health := player.health.current
	await h.press("interact",2)
	h.check(game.room.room_id == "furnace_core" and Session.checkpoint_room == "ember_quay" and player.health.current == entry_health, "Entering finale saves a safe retry point without healing")
	var finale: WorldInteraction = game.room.get_node("Interactions/CoreEcho")
	h.check(not finale.visible, "Chapter II central ending door stays hidden while its boss lives")
	game._on_interaction(finale)
	h.check("cistern_restored" not in Session.flags, "Cistern cannot be restored before the encounter is cleared")
	await h.frames(20)
	await h.shot("73_furnace_entry")
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await h.frames(3)
	Session.set_flag("furnace_keeper_defeated")
	game.room.update_progress()
	h.check(finale.visible and finale.position.x == 1080 and game.room.get_node("Interactions/Return").visible, "Keeper victory reveals the right chapter door and left run-out")
	player.revive(finale.position)
	await h.frames(3)
	await h.press("interact",2)
	h.check("cistern_restored" in Session.flags and get_tree().paused and game.ui.menu_mode == "chapter_two", "Furnace completion opens a distinct paused chapter ending")
	h.check(game.ui.menu.get_child(0).text == "余烬水道复苏" and game.ui.finale_saved, "Chapter II ending is translated and confirms a successful save")
	await h.shot("74_cistern_ending_zh")
	Session.set_language("en")
	await h.frames(3)
	await h.shot("75_cistern_ending_en")
	game.resume()
	h.check(Session.restore() and "flow_seal" in Session.flags and "pressure_seal" in Session.flags and "cistern_restored" in Session.flags, "Both seals and the second ending survive restore")
	game.load_room("ember_quay","checkpoint")
	await h.frames(4)
	var chapter_three_door := game.room.get_node("Interactions/ChapterThreeDoor") as WorldInteraction
	player.revive(chapter_three_door.position)
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "windworn_steps" and Session.checkpoint_room == "windworn_steps" and Session.checkpoint_spawn == "entry", "Chapter II right door enters Chapter III and moves the retry checkpoint across the chapter boundary")
	game.load_room("ember_quay","checkpoint")
	await h.frames(4)
	vent = game.room.get_node("Hazards").get_child(0) as SteamVent
	h.check(not vent.enabled, "Reloading a completed chapter keeps its steam safely disabled")
	player.revive(Vector2(440,480))
	await h.frames(270)
	h.check(player.health.current == player.health.maximum, "Disabled steam remains harmless for a full cycle")
	Session.set_language("zh_CN")
	player.revive(Vector2(650,480))
	await h.frames(3)
	var door_target: String = game.room.nearby_exit_target()
	h.check(door_target == "valve_gallery" and game.ui.prompt.text == "E / 前往 阀门长廊", "Quay door names the same destination used by the map")
	game.ui.show_map("ember_quay",door_target)
	get_tree().paused = true
	await h.frames(3)
	h.check(game.ui.world_map.door_target == "valve_gallery" and game.ui.world_map.room_label(door_target) == "阀门长廊", "Map highlights the door's actual destination")
	h.check(game.ui.world_map.chapter == 2 and game.ui.world_map.room_label("furnace_core") == "炉心", "Chapter map selects the current chapter and translates discovered rooms")
	var close := game.ui.map_panel.find_child("CloseMap",true,false) as Button
	h.check(close.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y and game.ui.map_panel.get_global_rect().position.y >= 0, "Chapter switch and map Back button fit the reference viewport")
	await h.shot("76_chapter_two_map")
	game.ui.chapter_button.pressed.emit()
	await h.frames(3)
	if game.ui.world_map.chapter == 3:
		game.ui.chapter_button.pressed.emit()
		await h.frames(3)
	h.check(game.ui.world_map.chapter == 1 and game.ui.map_progress.text.contains("守望者"), "Map can switch back to Chapter I with its own progress checklist")
	await h.shot("77_chapter_one_map_page")
	game.resume()
	# Ending failure must remain visible, retain session benefit and permit shrine retry.
	Session.flags.erase("cistern_restored")
	game.load_room("furnace_core","entry")
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await h.frames(3)
	finale = game.room.get_node("Interactions/CoreEcho")
	var save_path := Session.save_path
	Session.save_path = "user://missing_chapter_two_test_directory/save.json"
	player.revive(finale.position)
	await h.frames(3)
	await h.press("interact",2)
	h.check(get_tree().paused and not game.ui.finale_saved and "cistern_restored" in Session.flags, "Failed second ending save remains visible and keeps session progress")
	await h.shot("78_cistern_save_failure")
	Session.save_path = save_path
	game.resume()
	game.load_room("ember_quay","checkpoint")
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.restore() and "cistern_restored" in Session.flags, "Shrine retry persists the second ending after save failure")
	player.revive(Vector2(48,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "heart_chamber", "Chapter II return door preserves access to Chapter I")
	Session.set_language("en")
	game.ui.reward_notice.remaining = 0
