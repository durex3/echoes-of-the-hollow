extends Node
## Gate combinations and real traversal; all persistence uses the runner's test path.

func run(h: Node, game: Node) -> void:
	check_route_graph(h,game)
	check_objectives(h)
	var player: Player = game.player
	var original_flags := Session.flags.duplicate()
	Session.flags.clear()
	Session.visited.erase("atrium")
	Session.progress_changed.emit()
	game.load_room("forest","atrium_return")
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await h.frames(4)
	var gate := game.room.get_node("Interactions/ConvergenceDoor") as WorldInteraction
	var marks: Array[String] = ["training_cleared","scriptorium_cleared","belfry_cleared"]
	for mask: int in range(7):
		Session.flags.clear()
		for index: int in range(3):
			if mask & (1 << index):
				Session.flags.append(marks[index])
		Session.progress_changed.emit()
		player.revive(Vector2(1000,480))
		await h.frames(3)
		await h.press("interact",2)
		h.check(game.room.room_id == "forest" and not game.ui.toast.text.is_empty(), "Incomplete mark combination %d cannot enter antechamber" % mask)
	Session.flags.assign(["belfry_cleared"])
	Session.progress_changed.emit()
	h.check(game.ui.objective.text.contains("Watchers seal"), "Wind-first route points back to the missing combat branch")
	h.check(gate.locked_message(Session.abilities,Session.flags).contains("Watchers seal"), "Gate identifies the first missing seal and its location")
	Session.flags.assign(["training_cleared","scriptorium_cleared"])
	Session.progress_changed.emit()
	h.check(game.ui.objective.text.contains("wind beacon"), "Combat-first route points to the missing wind beacon")
	Session.set_language("zh_CN")
	player.revive(Vector2(1000,480))
	await h.frames(3)
	await h.press("interact",2)
	await h.frames(30)
	h.check(game.ui.toast.text.contains("尚未点亮风信标"), "Locked gate gives translated actionable guidance")
	await h.shot("40_three_mark_gate_locked")
	Session.set_flag("belfry_cleared")
	h.check(game.ui.objective.text.contains("三印已齐"), "Last mark updates the main objective immediately")
	await h.frames(3)
	await h.shot("41_three_mark_gate_open")
	# Optional heart and old high-shrine completion are not additional gate conditions.
	var completed := Session.completed
	Session.completed = false
	await h.press("interact",2)
	await h.frames(6)
	h.check(game.room.room_id == "atrium" and "heart_bloom" not in Session.flags, "Three marks enter without optional heart or high-shrine completion")
	h.check(game.room.get_node("Enemies").get_child_count() == 0 and player.is_on_floor(), "Antechamber entry has safe authored floor and no enemies")
	await h.press("move_right",32)
	player.health.take_damage(1,player.position)
	var shrine_health := player.health.current
	await h.press("interact",2)
	h.check(Session.checkpoint_room == "atrium" and player.health.current == shrine_health, "Walking to antechamber shrine saves without healing")
	h.check(Session.restore() and Session.checkpoint_room == "atrium", "Antechamber checkpoint survives save restore")
	await h.frames(30)
	await h.shot("42_atrium_checkpoint")
	await h.press("move_right",32)
	Input.action_press("jump")
	Input.action_press("move_right")
	await h.frames(25)
	Input.action_release("jump")
	Input.action_release("move_right")
	await h.frames(28)
	h.check(player.is_on_floor() and absf(player.position.y-416)<2, "First antechamber step reachable by normal jump")
	await h.press("move_right",7)
	Input.action_press("jump")
	Input.action_press("move_right")
	await h.frames(31)
	Input.action_release("jump")
	Input.action_release("move_right")
	await h.frames(28)
	h.check(player.is_on_floor() and absf(player.position.y-352)<2, "Second antechamber step reachable by normal jump")
	await h.press("move_right",47)
	await h.frames(30)
	h.check(game.ui.prompt.text.contains("挑战空谷守门者"), "Inner threshold identifies the guardian challenge")
	await h.shot("43_atrium_inner_door")
	game.ui.show_map("atrium")
	get_tree().paused = true
	await h.frames(3)
	h.check(game.ui.world_map.room_label("atrium") == "回响前庭" and game.ui.world_map.checkpoint_room == "atrium", "Map identifies the eighth room and its checkpoint in Chinese")
	await h.shot("44_atrium_map")
	game.resume()
	player.health.invulnerability_left = 0
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "atrium" and absf(player.position.x-240)<2 and player.health.current == player.health.maximum, "Death restores the safe antechamber checkpoint")
	await h.press("move_left",45)
	await h.press("interact",2)
	h.check(game.room.room_id == "forest" and absf(player.position.x-950)<3, "Antechamber return door leads safely back to the grove")
	Session.completed = completed
	Session.flags.assign(original_flags)
	Session.set_language("en")
	Session.progress_changed.emit()
	game.load_room("atrium","checkpoint")
	await h.frames(30)
	await h.shot("45_atrium_english")

func check_objectives(h: Node) -> void:
	var abilities: Array[String] = []
	var flags: Array[String] = []
	var visited: Array[String] = []
	var source := JourneyProgress.objective(abilities,flags,visited)
	h.check(source.contains("sky echo") and TextCatalog.ZH.has(source), "Fresh journey points to translated ability source")
	abilities.append("double_jump")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("Watchers seal"), "Sky echo leads to Watchers Hall")
	flags.append("training_cleared")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("Ink seal"), "Watchers seal points to the newly unlocked ink entrance")
	flags.append("scriptorium_cleared")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("wind echo"), "Both combat seals lead to the wind ability source")
	abilities.append("dash")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("wind beacon"), "Wind ability points toward its beacon encounter")
	flags.append("belfry_cleared")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("ground-level gate"), "All marks point to the ground-level convergence gate")
	visited.append("atrium")
	h.check(JourneyProgress.objective(abilities,flags,visited).contains("Antechamber reached"), "Discovered antechamber no longer asks the player to find it")

func check_route_graph(h: Node, game: Node) -> void:
	# Structural reachability only: existing suites validate battles and physical ability gates.
	var rooms: Dictionary = {}
	for id: String in game.ROOMS:
		rooms[id] = (game.ROOMS[id] as PackedScene).instantiate()
	var connections_valid := true
	for room: GameRoom in rooms.values():
		for point: WorldInteraction in room.get_node("Interactions").get_children():
			if point.kind == "exit":
				connections_valid = connections_valid and rooms.has(point.target_room)
				if rooms.has(point.target_room):
					connections_valid = connections_valid and rooms[point.target_room].has_node("Spawns/"+point.target_spawn)
	h.check(connections_valid, "Every authored exit targets an existing room and spawn")
	var visited: Array[String] = ["forest"]
	var abilities: Array[String] = []
	var flags: Array[String] = []
	for pass_index: int in range(16):
		var prior := visited.size()+abilities.size()+flags.size()
		for id: String in visited.duplicate():
			var room: GameRoom = rooms[id]
			# Structural model assumes encounter victory, as it already does for seals.
			# Actual boss/completion prerequisites are exercised by continuous routes.
			if id == "heart_chamber" and "warden_defeated" not in flags:
				flags.append("warden_defeated")
			for point: WorldInteraction in room.get_node("Interactions").get_children():
				if point.kind == "ability" and point.stable_id not in abilities:
					abilities.append(point.stable_id)
				elif point.kind in ["reward", "finale", "chapter_end"] and point.stable_id not in flags and point.locked_message(abilities,flags).is_empty():
					flags.append(point.stable_id)
				elif point.kind == "exit" and point.locked_message(abilities,flags).is_empty() and point.target_room not in visited:
					visited.append(point.target_room)
			var gates := room.get_node_or_null("Gates")
			if gates and "dash" in abilities:
				for gate: WindGate in gates.get_children():
					if gate.stable_id not in flags:
						flags.append(gate.stable_id)
		if visited.size()+abilities.size()+flags.size() == prior:
			break
	var chapter_one_two := ["forest", "ruins", "training", "scriptorium", "sanctuary", "wind_hall", "belfry", "atrium", "heart_chamber", "ember_quay", "valve_gallery", "sluice_shaft", "echo_vault", "cistern_archive", "pump_chamber", "furnace_core"]
	var first_two_complete := true
	for id: String in chapter_one_two:
		first_two_complete = first_two_complete and id in visited
	h.check(first_two_complete and visited.size() == chapter_one_two.size(), "First two chapter graph remains complete without relying on Chapter III")
	h.check("heart_bloom" not in flags, "Main route graph requires neither optional health nor high-shrine completion")
	var third_ids := ["windworn_steps", "bell_guard_walk", "broken_bell_atrium", "echo_cloister", "hanging_gallery", "bell_weight_chamber", "quiet_reliquary", "confluence_bridge", "terminal_platform"]
	var third_graph_valid := true
	for id: String in third_ids:
		third_graph_valid = third_graph_valid and rooms.has(id)
		if rooms.has(id):
			var third_room: GameRoom = rooms[id]
			for point: WorldInteraction in third_room.get_node("Interactions").get_children():
				if point.kind == "exit":
					third_graph_valid = third_graph_valid and rooms.has(point.target_room) and rooms[point.target_room].has_node("Spawns/"+point.target_spawn)
	h.check(third_graph_valid, "All nine Chapter III rooms and authored exit spawns are registered")
	var quay_door := (rooms["ember_quay"].get_node("Interactions/ChapterThreeDoor") as WorldInteraction)
	h.check(not quay_door.locked_message([], ["cistern_restored"]).is_empty(), "Legacy cistern-only save cannot enter Chapter III")
	h.check(quay_door.locked_message([], ["cistern_restored", "furnace_keeper_defeated"]).is_empty(), "Chapter III entry opens only after actual Furnace Keeper victory")
	var chapter_three_goal := JourneyProgress.objective([], ["cistern_restored", "furnace_keeper_defeated"], [])
	h.check(chapter_three_goal.contains("Bell Court") and chapter_three_goal.contains("rightmost door"), "Completed Chapter II objective points directly to the Chapter III entrance")
	var gallery_preview_end := (rooms["hanging_gallery"].get_node("Interactions/PreviewEnd") as WorldInteraction)
	rooms["hanging_gallery"].rehearsal = false
	rooms["hanging_gallery"].update_progress()
	h.check(not gallery_preview_end.visible, "Preview endpoint cannot complete the formal Chapter III route")
	var old_goal := JourneyProgress.objective([], ["cistern_restored"], [])
	h.check(old_goal.contains("Furnace Keeper") and not old_goal.contains("Echo Cloister"), "Legacy objective still points to the unbeaten Chapter II boss")
	for room: GameRoom in rooms.values():
		room.free()
