extends "res://tests/chapter_route.gd"
## Read-state/input-only optional route, no teleports or invulnerability.

func run() -> void:
	run_name = "cistern_optional"
	var fixture := {"version":2,"checkpoint_room":"sluice_shaft","checkpoint_spawn":"checkpoint","abilities":["double_jump","dash"],"visited":["heart_chamber","ember_quay","valve_gallery","sluice_shaft"],"completed":false,"flags":["warden_defeated","journey_restored"]}
	if SaveRepository.write(Session.save_path,fixture) != OK:
		fail("Could not create isolated exploration fixture")
		get_tree().quit(1)
		return
	game = preload("res://app/main.tscn").instantiate()
	add_child(game)
	game.start_game(true)
	game.player.died.connect(func() -> void: deaths += 1)
	game.player.health.damaged.connect(func(_amount: int, _at: Vector2) -> void: hurt_events += 1)
	await wait_frames(5)
	var success := await explore()
	release()
	if success:
		print("CISTERN_EXPLORATION_PASS: %.2fs deaths=%d hits=%d max_hp=%d" % [ticks/60.0,deaths,hurt_events,Session.maximum_health()])
	for path: String in [Session.save_path,Session.settings_path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path+suffix):
				DirAccess.remove_absolute(path+suffix)
	Audio.stop_all()
	get_tree().quit(0 if success and not failed else 1)

func explore() -> bool:
	for at: Vector2 in [Vector2(360,608),Vector2(560,544),Vector2(750,480),Vector2(930,416)]:
		if not await walk_to(at):
			return false
	if not await clear_room() or not await use("Seal"):
		return false
	if not await walk_to(Vector2(1120,352)) or not await use("VaultDoor") or not await use("Shrine"):
		return false
	if not await walk_to(Vector2(300,544)) or not await walk_to(Vector2(360,544)):
		return false
	# 160px optional rise uses the same two real jump presses as the first chapter.
	Input.action_press("jump")
	await wait_frames(18)
	Input.action_release("jump")
	await frame()
	Input.action_press("jump")
	Input.action_press("move_right")
	await wait_frames(32)
	release()
	await wait_frames(26)
	if not game.player.is_on_floor() or absf(game.player.position.y-384)>2:
		return fail("Real double jump missed the vault's optional high shelf: %s" % game.player.position)
	if not await walk_to(Vector2(705,320)) or not await use("Heart"):
		return false
	if "cistern_heart" not in Session.flags or Session.maximum_health() != 6:
		return fail("Optional heart was not obtained through actual movement")
	if not await use("Return"):
		return false
	if not await walk_to(Vector2(850,672)) or not await use("Crosslink"):
		return false
	if game.room.room_id != "cistern_archive" or not await use("Return"):
		return false
	return game.room.room_id == "ember_quay" and Session.restore() and "cistern_heart" in Session.flags
