extends "res://tests/chapter_route.gd"
## Starts from a valid Chapter I completion fixture; all Chapter II actions use input.
const FIRST_ROOMS := ["forest","ruins","training","scriptorium","sanctuary","wind_hall","belfry","atrium","heart_chamber"]
const FIRST_FLAGS := ["training_cleared","scriptorium_cleared","wind_passage_open","belfry_cleared","warden_defeated","journey_restored"]

func cross_steam(x: float, y := 480.0) -> bool:
	if not await walk_to(Vector2(x-82,y)):
		return false
	var vent: SteamVent
	for candidate: SteamVent in game.room.get_node("Hazards").get_children():
		if absf(candidate.position.x-x)<2:
			vent = candidate
	if vent == null:
		return fail("Missing authored steam vent")
	release()
	for i: int in range(360):
		if vent.phase == SteamVent.Phase.REST and vent.elapsed < 1.2:
			return await walk_to(Vector2(x+82,y))
		await frame()
	return fail("Steam never reached its safe crossing window")

func flow_branch() -> bool:
	if not await use("FlowDoor") or not await use("Shrine"):
		return false
	if not await cross_steam(320) or not await walk_to(Vector2(460,416)) or not await walk_to(Vector2(650,352)):
		return false
	if not await cross_steam(800,352) or not await clear_room() or not await use("Seal"):
		return false
	return "flow_seal" in Session.flags and await use("Shortcut")

func pressure_branch() -> bool:
	if not await use("PressureDoor") or not await use("Shrine") or not await cross_steam(400):
		return false
	if not await clear_room() or not await use("Seal"):
		return false
	return "pressure_seal" in Session.flags and await use("Shortcut")

func run() -> void:
	for order: String in ["flow_first", "pressure_first"]:
		run_name = order
		ticks = 0
		deaths = 0
		hurt_events = 0
		var fixture := {"version":2,"checkpoint_room":"heart_chamber","checkpoint_spawn":"checkpoint","abilities":["double_jump","dash"],"visited":FIRST_ROOMS,"completed":false,"flags":FIRST_FLAGS}
		if SaveRepository.write(Session.save_path,fixture) != OK:
			fail("Could not write isolated Chapter I completion fixture")
			break
		game = preload("res://app/main.tscn").instantiate()
		add_child(game)
		game.start_game(true)
		game.player.died.connect(func() -> void: deaths += 1)
		game.player.health.damaged.connect(func(_amount: int, _origin: Vector2) -> void: hurt_events += 1)
		await wait_frames(5)
		# The new door deliberately has a narrower radius than older doors.
		if not await walk_to(Vector2(600,480)) or not await use("ChapterDoor") or not await use("Shrine") or not await cross_steam(440):
			break
		if order == "flow_first":
			if not await flow_branch() or not await pressure_branch():
				break
		else:
			if not await pressure_branch() or not await flow_branch():
				break
		if not await use("CoreDoor"):
			break
		if not await cross_steam(384) or not await cross_steam(832) or not await clear_room() or not await use("CoreEcho"):
			break
		if "cistern_restored" not in Session.flags or not Session.restore():
			fail("Second chapter ending did not persist")
			break
		print("CHAPTER_TWO_PASS: %s %.2fs deaths=%d hits=%d" % [order,ticks/60.0,deaths,hurt_events])
		game.resume()
		if not await use("Return"):
			break
		if not await use("Shrine") or not await use("Return") or game.room.room_id != "heart_chamber":
			fail("Completed chapter cannot return to Chapter I")
			break
		remove_child(game)
		game.queue_free()
		await wait_frames(3)
	release()
	var file := FileAccess.open("res://artifacts/chapter_two_routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	file.close()
	for path: String in [Session.save_path,Session.settings_path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path+suffix):
				DirAccess.remove_absolute(path+suffix)
	Audio.stop_all()
	get_tree().quit(1 if failed else 0)
