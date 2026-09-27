extends Node
## Continuous input-only routes: never move actors, grant immunity, or set progress flags.
var game: Node
var ticks := 0
var deaths := 0
var run_name := ""
var failed := false
var samples: Array[Dictionary] = []
var hurt_events := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.save_path = "user://test_route_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_route_%s.cfg" % OS.get_process_id()
	Session.bindings.apply({})
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("FAIL: Continuous route runner timed out")
		get_tree().quit(1))
	run.call_deferred()

func frame() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	ticks += 1

func hold(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func release() -> void:
	for action: String in InputBindings.ACTIONS:
		Input.action_release(action)

func wait_frames(count: int) -> void:
	for i: int in range(count):
		await frame()

func use(point_name: String) -> bool:
	var point := game.room.get_node("Interactions/" + point_name) as WorldInteraction
	if not await walk_to(point.position, false):
		return false
	Input.action_press("interact")
	await wait_frames(2)
	Input.action_release("interact")
	await wait_frames(3)
	samples.append({"route": run_name, "event": point_name, "room": game.room.room_id, "seconds": snappedf(ticks/60.0, 0.01), "hp": game.player.health.current})
	return true

func walk_to(at: Vector2, combat := true, limit := 1800) -> bool:
	var p: Player = game.player
	for i: int in range(limit):
		if p.state == Player.State.DEAD:
			release()
			return fail("Died while walking toward %s in %s" % [at, game.room.room_id])
		var difference := at - p.position
		if (not combat and difference.length() < 48) or (absf(difference.x) < 9 and absf(difference.y) < 12 and p.is_on_floor()):
			release()
			await wait_frames(3)
			return true
		var direction := signf(difference.x) if absf(difference.x) >= 7 else 0.0
		var target: Node2D
		if combat:
			for enemy: Node2D in game.room.get_node("Enemies").get_children():
				if enemy.health.current > 0 and absf(enemy.position.y - p.position.y) < 45 and absf(enemy.position.x - p.position.x) < 100:
					target = enemy
					break
		if target:
			if not target is Slime:
				if not await fight_enemy(target):
					return false
				continue
			# Keep traversal's jump steering on tiered slime platforms, but stop
			# pushing into contact while swinging at a target already in reach.
			var dx := target.position.x-p.position.x
			var in_reach := absf(dx) <= 60 and absf(target.position.y-p.position.y) < 30
			direction = signf(dx) if absf(dx) > 52 else -signf(dx) if absf(dx) < 38 else 0.0
			var turn_first := in_reach and p.facing != signf(dx) and p.state == Player.State.MOVE
			if turn_first:
				direction = signf(dx)
			hold("attack",in_reach and not turn_first and p.state == Player.State.MOVE)
		else:
			Input.action_release("attack")
		hold("move_right", direction > 0)
		hold("move_left", direction < 0)
		if p.is_on_floor() and (p.is_on_wall() or (difference.y < -20 and absf(difference.x) < 140)):
			Input.action_press("jump")
		elif p.velocity.y >= 0:
			Input.action_release("jump")
		if p.is_on_floor() and incoming_bolt(p):
			Input.action_press("jump")
		# A second press extends an ascent to the authored high-root ledge.
		if difference.y < -105 and "double_jump" in Session.abilities and not p.is_on_floor() and not p.air_jump_used and p.velocity.y > -80:
			Input.action_release("jump")
			await frame()
			Input.action_press("jump")
		if game.room.room_id == "wind_hall" and p.is_on_wall() and "dash" in Session.abilities:
			hold("dash", i % 30 < 12)
		await frame()
	release()
	return fail("Traversal timeout %s at %s toward %s" % [game.room.room_id, p.position, at])

func incoming_bolt(p: Player) -> bool:
	for bolt: InkBolt in game.room.projectiles.get_children():
		var delta_x := bolt.position.x - p.position.x
		if not bolt.spent and delta_x * bolt.direction.x < 0 and absf(delta_x) < 125 and absf(bolt.position.y - (p.position.y - 22)) < 42:
			return true
	return false

func fight_enemy(enemy: Node2D) -> bool:
	var p: Player = game.player
	var drop_direction := 0.0
	release()
	for tick: int in range(1500):
		if p.state == Player.State.DEAD:
			release()
			return fail("Died in combat: " + game.room.room_id)
		if not is_instance_valid(enemy) or enemy.health.current <= 0:
			release()
			return true
		var dx := enemy.position.x - p.position.x
		var distance := absf(dx)
		var direction := signf(dx) if distance > 52 else -signf(dx) if distance < 38 else 0.0
		var ready_to_hit := absf(enemy.position.y - p.position.y) < 30 and distance <= 62
		var target_below := enemy.position.y - p.position.y > 55
		if target_below:
			# A knockback or wall jump can put the player on a shelf above a slime.
			# Keep walking off that shelf instead of oscillating over its x position.
			if drop_direction == 0:
				drop_direction = signf(dx) if distance > 1 else p.facing
			direction = drop_direction
		else:
			drop_direction = 0.0
		if enemy is LivingArmor and enemy.state in [LivingArmor.State.WINDUP, LivingArmor.State.STRIKE]:
			direction = -signf(dx) if distance < 105 else 0.0
			ready_to_hit = false
		var jump := (incoming_bolt(p) or p.is_on_wall() and distance > 60) if p.is_on_floor() else Input.is_action_pressed("jump") and p.velocity.y < 0
		if target_below:
			jump = false
		if jump:
			ready_to_hit = false
		if ready_to_hit and p.state == Player.State.MOVE and p.facing != signf(dx):
			# Turn using one frame of input, then plant feet for the actual stroke.
			direction = signf(dx)
			ready_to_hit = false
		hold("move_left",direction < 0)
		hold("move_right",direction > 0)
		hold("jump",jump)
		hold("attack",ready_to_hit and p.state == Player.State.MOVE)
		await frame()
	release()
	return fail("Combat timeout: %s hp=%s state=%s enemy=%s player=%s facing=%s player_state=%s" % [enemy.name,enemy.health.current,enemy.state,enemy.position,p.position,p.facing,p.state])

func clear_room() -> bool:
	for enemy: Node2D in game.room.get_node("Enemies").get_children():
		if not is_instance_valid(enemy) or enemy.health.current <= 0:
			continue
		if enemy is DoomScribe or enemy is LivingArmor or enemy is Slime or enemy is RoseSentinel or enemy is WingedChest:
			var side := -1.0 if game.player.position.x < enemy.position.x else 1.0
			if not await walk_to(enemy.position + Vector2(side * 60,0)) or not await fight_enemy(enemy):
				return false
			if game.room.room_id == "scriptorium" and enemy.name == &"ScribeSolo":
				if not await use("Rest"):
					return false
			continue
		for attempt: int in range(10):
			if not is_instance_valid(enemy) or enemy.health.current <= 0:
				break
			var target_x := enemy.position.x - 38 if game.player.position.x < enemy.position.x else enemy.position.x + 38
			if not await walk_to(Vector2(target_x, enemy.position.y), true, 600):
				return false
			for i: int in range(28):
				if not is_instance_valid(enemy) or enemy.health.current <= 0:
					break
				hold("move_right", enemy.position.x > game.player.position.x)
				hold("move_left", enemy.position.x < game.player.position.x)
				hold("attack", i < 15)
				await frame()
			release()
			if game.player.state == Player.State.DEAD:
				return fail("Died in combat: " + game.room.room_id)
	release()
	await wait_frames(45)
	return game.room.is_cleared() or fail("Enemies remain in " + game.room.room_id)

func combat_branch() -> bool:
	if game.room.room_id == "forest" and not await use("EastDoor"):
		return false
	if not await walk_to(Vector2(1210,480)) or not await use("TrainingDoor") or not await use("Shrine"):
		return false
	if not await clear_room() or not await use("Seal") or not await use("ScribeDoor") or not await use("Shrine"):
		return false
	if not await clear_room() or not await use("Seal") or not await use("EastDoor"):
		return false
	return await walk_to(Vector2(48,480)) and await use("WestDoor")

func wind_branch() -> bool:
	if not await walk_to(Vector2(305,384)):
		return false
	Input.action_press("jump")
	await wait_frames(18)
	Input.action_release("jump")
	await frame()
	Input.action_press("jump")
	Input.action_press("move_right")
	await wait_frames(23)
	release()
	await wait_frames(30)
	if not await use("SanctuaryDoor"):
		return false
	if not await use("Shrine") or not await walk_to(Vector2(890,480)) or not await use("WindDoor") or not await use("WindEcho"):
		return false
	if not await walk_to(Vector2(880,480)) or not await use("EastDoor") or not await use("Shrine"):
		return false
	if not await clear_room() or not await use("Beacon"):
		return false
	return await use("Shortcut")

func boss_fight() -> bool:
	var boss: HollowWarden = game.room.get_node("Enemies/Warden")
	var p: Player = game.player
	var saw_verdict := false
	for i: int in range(18000):
		if "warden_defeated" in Session.flags:
			release()
			await wait_frames(40)
			return saw_verdict or fail("Boss route skipped the new sword court")
		if p.state == Player.State.DEAD:
			release()
			return fail("Died during input-only boss battle")
		var dx := boss.position.x - p.position.x
		var direction := 0.0
		var jump := false
		var attack := false
		match boss.state:
			HollowWarden.State.DORMANT, HollowWarden.State.INTRO, HollowWarden.State.CHASE:
				direction = signf(dx) if absf(dx) > 65 else 0.0
			HollowWarden.State.WINDUP:
				if boss.rush_attack:
					jump = boss.timer < 0.20
				else:
					direction = -signf(dx) if absf(dx) < 112 else 0.0
			HollowWarden.State.STRIKE:
				jump = boss.rush_attack
			HollowWarden.State.RECOVER, HollowWarden.State.TRANSITION:
				direction = signf(dx) if absf(dx) > 55 else 0.0
				if absf(dx) < 66 and p.state == Player.State.MOVE:
					if p.facing != signf(dx):
						direction = signf(dx)
					else:
						attack = absf(p.position.y - boss.position.y) < 35
			HollowWarden.State.SWORD_COURT:
				var court_goal := 180.0 if p.position.x < boss.position.x else 480.0
				direction = signf(court_goal-p.position.x) if absf(court_goal-p.position.x) > 5 else 0.0
		if is_instance_valid(boss.sword_court):
			saw_verdict = saw_verdict or boss.sword_court.round_index == 3
			for sword: RoyalSword in boss.sword_court.swords:
				if is_instance_valid(sword) and sword.dangerous() and sword.global_position.distance_to(p.position) < 220:
					jump = jump or p.is_on_floor()
			if not p.is_on_floor() and Input.is_action_pressed("jump") and p.velocity.y < 0:
				jump = true
		hold("move_left", direction < 0)
		hold("move_right", direction > 0)
		hold("jump", jump)
		hold("attack", attack)
		await frame()
	return fail("Boss input route timed out")

func run() -> void:
	for order: String in ["combat_first", "wind_first"]:
		run_name = order
		ticks = 0
		deaths = 0
		hurt_events = 0
		game = preload("res://app/main.tscn").instantiate()
		add_child(game)
		game.start_game(false)
		game.player.died.connect(func() -> void: deaths += 1)
		game.player.health.damaged.connect(func(_amount: int, origin: Vector2) -> void:
			hurt_events += 1
			var nearby: Array[Dictionary] = []
			for enemy: Node2D in game.room.get_node("Enemies").get_children():
				if enemy.position.distance_to(game.player.position) < 320:
					nearby.append({"enemy": str(enemy.name), "position": str(enemy.position), "state": enemy.state, "hp": enemy.health.current})
			samples.append({"route": run_name, "event": "damage", "room": game.room.room_id, "seconds": snappedf(ticks/60.0, 0.01), "hp": game.player.health.current, "position": str(game.player.position), "origin": str(origin), "nearby": nearby}))
		await wait_frames(5)
		if not await use("Shrine") or not await walk_to(Vector2(1200,480)) or not await use("EastDoor") or not await use("Shrine"):
			break
		if not await walk_to(Vector2(620,480)) or not await walk_to(Vector2(800,416)) or not await walk_to(Vector2(960,352)) or not await use("Echo"):
			break
		if order == "combat_first":
			if not await combat_branch() or not await wind_branch():
				break
		else:
			if not await walk_to(Vector2(48,480)) or not await use("WestDoor") or not await wind_branch() or not await combat_branch():
				break
		if not await walk_to(Vector2(1000,480)) or not await use("ConvergenceDoor") or not await use("Shrine"):
			break
		var retry_start := ticks
		if not await walk_to(Vector2(460,416)) or not await walk_to(Vector2(625,352)) or not await use("InnerDoor"):
			break
		print("ROUTE_RETRY_SECONDS: ", (ticks - retry_start) / 60.0)
		if not await boss_fight() or not await use("FinalEcho"):
			break
		if "journey_restored" not in Session.flags or not Session.restore():
			fail("Ending did not persist")
			break
		print("ROUTE_PASS: %s %.2fs deaths=%d hits=%d" % [order, ticks/60.0, deaths, hurt_events])
		get_tree().paused = false
		remove_child(game)
		game.queue_free()
		await wait_frames(3)
	release()
	var file := FileAccess.open("res://artifacts/chapter_routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t"))
	file.close()
	for path: String in [Session.save_path, Session.settings_path]:
		for suffix: String in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	Audio.stop_all()
	get_tree().quit(1 if failed else 0)

func fail(message: String) -> bool:
	failed = true
	print("FAIL: ", run_name, " / ", message)
	return false
