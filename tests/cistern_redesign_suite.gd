extends Node
## Chapter identity, real duel timings, exploration links and isolated rewards.

func setup(h: Node, game: Node, at := Vector2(590,480)) -> RoseSentinel:
	game.load_room("cistern_archive","entry")
	game.player.revive(at)
	game.ui.reward_notice.remaining = 0
	game.ui.set_text(game.ui.toast,"")
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vent.enabled = false
	await h.frames(5)
	return game.room.get_node("Enemies/RoseSentinel") as RoseSentinel

func run(h: Node, game: Node) -> void:
	var second := ["ember_quay","valve_gallery","cistern_archive","furnace_core","sluice_shaft","pump_chamber","echo_vault"]
	var first_types: Array[String] = []
	var second_types: Array[String] = []
	var links_valid := true
	for id: String in game.ROOMS:
		var room := (game.ROOMS[id] as PackedScene).instantiate() as GameRoom
		for enemy: Node in room.get_node("Enemies").get_children():
			var script_path: String = enemy.get_script().resource_path
			if id in second:
				second_types.append(script_path)
			else:
				first_types.append(script_path)
		for point: WorldInteraction in room.get_node("Interactions").get_children():
			if point.kind == "exit":
				if not game.ROOMS.has(point.target_room):
					links_valid = false
					continue
				var destination := (game.ROOMS[point.target_room] as PackedScene).instantiate()
				links_valid = links_valid and destination.has_node("Spawns/"+point.target_spawn)
				destination.free()
		room.free()
	var unique_roster := not second_types.is_empty()
	for type: String in second_types:
		unique_roster = unique_roster and type not in first_types
	h.check(unique_roster, "Chapter II enemy roster never reuses any Chapter I enemy script")
	h.check(links_valid, "Every authored door across sixteen rooms resolves an existing native spawn")
	var old_save := {"version":2,"checkpoint_room":"valve_gallery","checkpoint_spawn":"checkpoint","abilities":["double_jump","dash"],"visited":["ember_quay","valve_gallery"],"completed":false,"flags":["journey_restored","flow_seal","pressure_seal"]}
	h.check(SaveRepository.validate(old_save) and SaveRepository.migrate(old_save) == old_save, "Pre-expansion saves retain both valve flags and original checkpoints without migration loss")
	var player: Player = game.player
	var duelist: RoseSentinel = await setup(h,game,Vector2(480,480))
	Session.set_language("zh_CN")
	await h.frames(3)
	h.check(game.ui.prompt.text.contains("粉焰剑士"), "Archive teaches the new duelist in Chinese before close combat")
	await h.shot("85_rose_lesson")
	Session.set_language("en")
	duelist = await setup(h,game)
	var initial := duelist.position.x
	await h.frames(8)
	h.check(duelist.state == RoseSentinel.State.RETREAT and duelist.position.x > initial and not duelist.attack_box.active, "Duelist creates space by retreating before its attack")
	await h.frames(10)
	h.check(duelist.state == RoseSentinel.State.WARNING and not duelist.attack_box.active, "Duelist has a distinct harmless full warning after retreat")
	var timer := duelist.timer
	get_tree().paused = true
	await h.frames(8)
	h.check(duelist.timer == timer, "Pause freezes duelist warning and animation lifecycle")
	get_tree().paused = false
	var locked := duelist.facing
	player.revive(duelist.position+Vector2(35,0))
	await h.frames(3)
	h.check(duelist.facing == locked, "Duelist commits to its original side even when player crosses behind")
	await h.shot("86_rose_warning")
	for step: int in range(45):
		if duelist.state == RoseSentinel.State.STRIKE:
			break
		await h.frames(1)
	await h.frames(5)
	h.check(duelist.attack_box.active and duelist.velocity.x < 0, "New swordsman performs its committed ground dash slash")
	await h.shot("87_rose_slash")
	await h.frames(15)
	h.check(duelist.state == RoseSentinel.State.RECOVER and not duelist.attack_box.active, "Duelist exposes a full harmless recovery after the dash")
	duelist = await setup(h,game,Vector2(610,480))
	var hp := player.health.current
	await h.frames(80)
	h.check(player.health.current == hp-1, "Real duelist slash overlap deals one damage per attack")
	duelist = await setup(h,game,Vector2(610,480))
	await h.frames(47)
	Input.action_press("jump")
	await h.frames(35)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum, "Input jump evades a fully committed duelist slash")
	duelist = await setup(h,game,Vector2(625,480))
	player.facing = 1
	await h.press("attack",12)
	h.check(duelist.health.current == 2 and duelist.state == RoseSentinel.State.RECOVER and not duelist.attack_box.active, "Actual sword interrupts duelist preparation")
	duelist.target = null
	await h.frames(2)
	h.check(duelist.state == RoseSentinel.State.IDLE and not duelist.attack_box.active, "Duelist cancels combat when target is removed")
	duelist = await setup(h,game)
	player.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(duelist.state == RoseSentinel.State.IDLE and not duelist.attack_box.active, "Player death cancels duelist damage immediately")
	await h.frames(65)
	duelist = await setup(h,game)
	duelist.health.take_damage(99,player.position)
	await h.frames(8)
	h.check(not duelist.attack_box.active and duelist.sprite.animation == "death", "Duelist death disables damage and uses its own source death frames")
	await h.shot("88_rose_death")
	await h.frames(60)
	h.check(not is_instance_valid(duelist), "Duelist releases scene after death clip")
	# Physics world occlusion and ledge protection, independently of attack choreography.
	duelist = await setup(h,game,Vector2(110,480))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	shape.shape = rectangle
	wall.add_child(shape)
	game.room.add_child(wall)
	wall.position = Vector2(620,440)
	player.revive(Vector2(570,480))
	await h.frames(5)
	h.check(not duelist.can_see_target() and duelist.state == RoseSentinel.State.IDLE, "World wall blocks the new duelist's detection")
	wall.position.x = 300
	await h.frames(8)
	wall.position.x = 620
	await h.frames(90)
	h.check(duelist.position.x >= 635 and player.health.current == player.health.maximum, "Locked duelist dash cannot cross or hit through a world wall")
	wall.queue_free()
	await h.frames(2)
	game.load_room("pump_chamber","entry")
	duelist = game.room.get_node("Enemies/RoseSentinel")
	duelist.position = Vector2(635,480)
	player.revive(Vector2(612,480))
	await h.frames(88)
	h.check(duelist.position.x >= 628 and absf(duelist.position.y-480)<2 and not duelist.attack_box.active, "New duelist stops at the pump shelf edge instead of falling during its slash")
	# New locations remain valid checkpoint destinations and gate their own shortcuts.
	Session.flags.erase("flow_seal")
	Session.flags.erase("pressure_seal")
	game.load_room("sluice_shaft","checkpoint")
	await h.frames(3)
	var cross: WorldInteraction = game.room.get_node("Interactions/Crosslink")
	h.check(not cross.locked_message(Session.abilities,Session.flags).is_empty(), "Shaft lower shortcut is locked until flow valve activation")
	Session.set_flag("flow_seal")
	player.revive(cross.position)
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "cistern_archive" and player.position.y < 430, "Activated shaft passage arrives on archive upper shelf")
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "sluice_shaft", "Flow passage works in both directions")
	game.load_room("ember_quay","pump_return")
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "ember_quay", "Pump shortcut cannot bypass its still-locked valve")
	Session.set_flag("pressure_seal")
	await h.press("interact",2)
	h.check(game.room.room_id == "pump_chamber", "Pressure valve opens the quay-to-pump return route")
	# Optional reward remains unique, additive and persisted without requiring it for core.
	Session.flags.erase("cistern_heart")
	Session.abilities.erase("steam_ward")
	var previous_max := Session.maximum_health()
	game.load_room("echo_vault","checkpoint")
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.checkpoint_room == "echo_vault" and Session.commit() == OK, "Optional vault shrine saves a valid new checkpoint")
	player.revive(Vector2(755,320))
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.maximum_health() == previous_max and player.health.current == previous_max and "steam_ward" in Session.abilities, "Vault grants steam ward and full heal without increasing maximum health")
	game._on_interaction(game.room.get_node("Interactions/Heart"))
	h.check(Session.abilities.count("steam_ward") == 1 and Session.restore() and Session.maximum_health() == previous_max, "Optional ward is unique and survives save restore")
	player.health.invulnerability_left = 0
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "echo_vault" and player.health.current == previous_max and "steam_ward" in Session.abilities, "Death after secret reward retains ward at a safe checkpoint")
	Session.set_language("zh_CN")
	for id: String in second:
		Session.visit(id)
	game.ui.show_map("echo_vault")
	get_tree().paused = true
	await h.frames(3)
	h.check(game.ui.world_map.room_label("echo_vault") == "回响秘库" and game.ui.world_map.CHAPTER_TWO.size() == 8, "Chapter map contains seven distinct areas plus its Chapter I connection")
	await h.shot("89_cistern_expanded_map")
	game.resume()
	for item: Array in [["sluice_shaft",Vector2(960,416)],["pump_chamber",Vector2(660,480)],["echo_vault",Vector2(740,320)]]:
		game.load_room(item[0],"entry")
		for enemy: Node in game.room.get_node("Enemies").get_children():
			enemy.set_physics_process(false)
		player.revive(item[1])
		game.ui.reward_notice.remaining = 0
		game.ui.toast_left = 0
		game.ui.set_text(game.ui.toast,"")
		await h.frames(20)
		await h.shot("90_"+item[0])
	Session.set_language("en")
	game.load_room("ember_quay","checkpoint")
	await h.frames(3)
