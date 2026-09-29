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
	if not await cross_steam(800,352) or not await clear_room() or not await use("ShaftDoor") or not await use("Shrine"):
		return false
	for at: Vector2 in [Vector2(360,608),Vector2(560,544),Vector2(750,480),Vector2(930,416),Vector2(980,416)]:
		if not await walk_to(at):
			return false
	if not await clear_room() or not await use("Seal"):
		return false
	if not await walk_to(Vector2(850,672)) or not await use("Crosslink"):
		return false
	return "flow_seal" in Session.flags and await use("Return")

func pressure_branch() -> bool:
	if not await use("PressureDoor") or not await use("Shrine") or not await cross_steam(400):
		return false
	if not await clear_room() or not await use("PumpDoor") or not await use("Shrine"):
		return false
	for at: Vector2 in [Vector2(420,544),Vector2(650,480),Vector2(705,480)]:
		if not await walk_to(at):
			return false
	# Finish the upper duelist before dropping into the lower chest encounter.
	if not await walk_to(Vector2(850,608)) or not await cross_steam(960,608) or not await clear_room() or not await use("Seal"):
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
		game.player.health.damaged.connect(func(_amount: int, origin: Vector2) -> void:
			hurt_events += 1
			if game.room.room_id == "furnace_core":
				var keeper := game.room.get_node("Enemies/FurnaceKeeper") as FurnaceKeeper
				samples.append({"route": run_name, "event": "keeper_damage", "seconds": snappedf(ticks/60.0,0.01), "hp": game.player.health.current, "player": str(game.player.position), "origin": str(origin), "boss": str(keeper.position), "state": keeper.state, "attack": keeper.attack})
		)
		await wait_frames(5)
		# The new door deliberately has a narrower radius than older doors.
		if not await walk_to(Vector2(320,480)) or not await use("ChapterDoor") or not await use("Shrine") or not await cross_steam(440):
			break
		if order == "flow_first":
			if not await flow_branch() or not await pressure_branch():
				break
		else:
			if not await pressure_branch() or not await flow_branch():
				break
		if not await use("CoreDoor"):
			break
		if not await keeper_fight() or not await use("CoreEcho"):
			break
		if "cistern_restored" not in Session.flags or not Session.restore():
			fail("Second chapter ending did not persist")
			break
		print("CHAPTER_TWO_PASS: %s %.2fs deaths=%d hits=%d" % [order,ticks/60.0,deaths,hurt_events])
		game.resume()
		if game.room.room_id != "ember_quay":
			fail("Chapter ending did not return to Ember Quay")
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

func keeper_fight() -> bool:
	var boss := game.room.get_node("Enemies/FurnaceKeeper") as FurnaceKeeper
	var p: Player = game.player
	var saw_combo := false
	var saw_eruption := false
	var ledge_jump_tick := -1
	for tick: int in range(12000):
		if "furnace_keeper_defeated" in Session.flags:
			release()
			await wait_frames(65)
			return (saw_combo and saw_eruption and "steam_ward" not in Session.abilities) or fail("Keeper route skipped required patterns or depended on optional shield")
		if p.state == Player.State.DEAD:
			return fail("Died during keeper battle without optional ward at tick %d, boss attack %d, state %d, player x %.1f, boss x %.1f" % [tick, boss.attack, boss.state, p.position.x, boss.position.x])
		var desired := boss.position.x-48
		saw_combo = saw_combo or boss.attack == FurnaceKeeper.Attack.COMBO and boss.state == FurnaceKeeper.State.CAST
		saw_eruption = saw_eruption or (boss.state == FurnaceKeeper.State.LANDING)
		var jump := false
		var attack := false
		if boss.state == FurnaceKeeper.State.WARNING:
			if boss.attack == FurnaceKeeper.Attack.DASH:
				desired = boss.position.x+boss.facing*78
				jump = boss.timer < 0.18
			else:
				desired = boss.position.x + 100 if p.position.x < boss.position.x else boss.position.x-100
		elif boss.state == FurnaceKeeper.State.CAST:
			if boss.attack == FurnaceKeeper.Attack.DASH:
				desired = boss.position.x+boss.facing*78
				jump = true
			else:
				desired = boss.position.x + 100 if p.position.x < boss.position.x else boss.position.x-100
		elif boss.state == FurnaceKeeper.State.RECOVER:
			desired = boss.position.x + (-36 if p.position.x < boss.position.x else 36)
			attack = absf(p.position.x-boss.position.x)<62 and tick%25<14
			if p.position.y < 400:
				desired = 860.0
		if boss.attack in [FurnaceKeeper.Attack.MELEE,FurnaceKeeper.Attack.COMBO] and boss.state != FurnaceKeeper.State.RECOVER:
			desired = 540.0 if p.position.x < boss.position.x else 1160.0
			jump = boss.state == FurnaceKeeper.State.WARNING and boss.timer < 0.18 or boss.state == FurnaceKeeper.State.CAST
		# Reach a real ledge during ascent/charge, then jump over the arriving wall.
		if boss.attack == FurnaceKeeper.Attack.SLAM and (boss.state in [FurnaceKeeper.State.TAKEOFF,FurnaceKeeper.State.WARNING,FurnaceKeeper.State.LANDING,FurnaceKeeper.State.IMPACT] or boss.flames.get_child_count() > 0):
			desired = 638.0 if p.position.x < boss.position.x else 1080.0
			attack = false
			jump = false
			if ledge_jump_tick >= 0:
				jump = ledge_jump_tick < 20 or ledge_jump_tick >= 22 and ledge_jump_tick < 42
				ledge_jump_tick += 1
				if ledge_jump_tick > 70:
					ledge_jump_tick = -1
			elif p.position.y > 325 and p.is_on_floor() and absf(p.position.x-desired)<30:
				ledge_jump_tick = 0
				jump = true
			elif p.is_on_floor():
				for flame: Node2D in boss.flames.get_children():
					if absf(flame.position.x-p.position.x)<145:
						ledge_jump_tick = 0
						jump = true
		desired = clampf(desired,520.0,1160.0)
		var dx := desired-p.position.x
		hold("move_left",dx < -6)
		hold("move_right",dx > 6)
		hold("jump",jump)
		hold("attack",attack)
		await frame()
	return fail("Keeper battle timed out")
