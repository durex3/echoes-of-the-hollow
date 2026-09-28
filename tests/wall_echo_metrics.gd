extends Node
## Isolated real-physics measurements. Never loads/writes the player's campaign.

var player: Player
var arena: Node2D
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}
var wall_jumps := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.save_path = "user://test_wall_echo_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_wall_echo_%s.cfg" % OS.get_process_id()
	Session.bindings.apply({})
	Session.reset()
	_run.call_deferred()

func frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func shot(name_text: String) -> void:
	if "--visual" in OS.get_cmdline_user_args():
		var was_paused := get_tree().paused
		get_tree().paused = true
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://artifacts/" + name_text + ".png")
		get_tree().paused = was_paused
		check(error == OK, "Saved blockout screenshot " + name_text)

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures.append(message)

func release() -> void:
	for action: String in ["move_left", "move_right", "jump", "dash", "attack", "steam_ward"]:
		Input.action_release(action)

func box(at: Vector2, size: Vector2, id: StringName = &"") -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new() if id.is_empty() else WallEchoSurface.new()
	if body is WallEchoSurface:
		(body as WallEchoSurface).surface_id = id
	body.position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	arena.add_child(body)
	return body

func fixture(abilities: Array[String], at := Vector2(200, 704)) -> void:
	release()
	if is_instance_valid(arena):
		arena.queue_free()
		await frames(2)
	Session.reset()
	Session.abilities.assign(abilities)
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	box(Vector2(1500, 720), Vector2(4000, 32))
	player = preload("res://features/player/player.tscn").instantiate()
	player.position = at
	arena.add_child(player)
	wall_jumps = 0
	player.wall_echo.jumped.connect(func(_id: StringName) -> void: wall_jumps += 1)
	await frames(4)

func baseline(second_frame: int, dash_frame: int = -1, tap_frame: int = -1) -> Vector2:
	await fixture(["double_jump", "dash"])
	var start := player.position
	var top := start.y
	Input.action_press("move_right")
	Input.action_press("jump")
	for tick: int in range(140):
		if tick == second_frame - 1 or tick == tap_frame:
			Input.action_release("jump")
		if tick == second_frame:
			Input.action_press("jump")
		if tick == dash_frame:
			Input.action_press("dash")
		if tick == dash_frame + 1:
			Input.action_release("dash")
		await frames(1)
		top = minf(top, player.position.y)
		if tick > 4 and player.is_on_floor():
			break
	release()
	return Vector2(start.y - top, player.position.x - start.x)

func touch_wall(side: float, marked := true) -> void:
	await fixture(["double_jump", "dash", "wall_echo"], Vector2(400 - side * 30, 360))
	box(Vector2(400 + side * 16, 352), Vector2(32, 704), &"test_wall" if marked else &"")
	# These are fixture starting entitlements, not route-time assistance.
	player.air_jump_used = true
	player.air_dash_used = true
	Input.action_press("move_right" if side > 0 else "move_left")
	await frames(10)
	check(player.is_on_wall(), "Fixture reaches real wall contact on side %s" % side)

func _run() -> void:
	var full := await baseline(-1)
	var tap := await baseline(-1, -1, 3)
	var best := Vector2.ZERO
	var best_frame := 0
	for second_frame: int in range(8, 39, 2):
		var sample := await baseline(second_frame)
		if sample.x > best.x:
			best = sample
			best_frame = second_frame
	var with_dash := await baseline(best_frame, best_frame + 22)
	metrics["single_jump"] = {"height":full.x, "run_distance":full.y}
	metrics["tap_jump"] = {"height":tap.x, "run_distance":tap.y}
	metrics["double_jump_sample_max"] = {"height":best.x, "run_distance":best.y, "second_press_frame":best_frame}
	metrics["double_jump_dash"] = {"height":with_dash.x, "run_distance":with_dash.y}
	check(full.x > 90 and full.x < 110 and tap.x < full.x - 20, "Existing full/tap jump metrics remain intact")
	check(best.x < 210 and with_dash.x < 210, "Sampled old double jump/dash cannot reach a 320px gate")
	for side: float in [-1.0, 1.0]:
		await touch_wall(side)
		check(player.sprite.animation==&"wall_slide" and player.visual.scale.x==side,"Wall contact uses a wall-facing braced pose %s" % side)
		await shot("wall_slide_%d" % int(side))
		var origin := player.position
		Input.action_press("jump")
		await frames(1)
		check(wall_jumps == 1 and player.velocity.y < -500 and signf(player.velocity.x) == -side, "Fresh press launches away from marked wall %s" % side)
		check(player.air_jump_used and player.air_dash_used, "Wall jump preserves spent air jump and dash %s" % side)
		check(player.sprite.animation==&"wall_push" and player.visual.scale.x==-side,"Wall jump shows a distinct outward push-off clip %s" % side)
		await shot("wall_push_%d" % int(side))
		var peak := player.position.y
		for tick: int in range(24):
			await frames(1)
			peak = minf(peak, player.position.y)
		check(wall_jumps == 1, "Held jump never chains automatically on one wall %s" % side)
		check(player.wall_echo.pose_left==0 and player.sprite.animation!=&"wall_push","Push-off returns to normal air motion %s" % side)
		Input.action_release("jump")
		await frames(1)
		Input.action_press("jump")
		await frames(2)
		check(wall_jumps == 1, "A fresh second press cannot climb the same wall twice %s" % side)
		metrics["wall_jump_" + str(side)] = {"height":origin.y - peak, "outward_lock_seconds":player.wall_echo.config.steering_lock_seconds}
	await touch_wall(1.0, false)
	Input.action_press("jump")
	await frames(2)
	check(wall_jumps == 0 and player.velocity.y > 0, "Ordinary old walls cannot grant a wall jump")
	await touch_wall(1.0)
	Session.abilities.erase("wall_echo")
	await frames(1)
	Input.action_press("jump")
	await frames(2)
	check(wall_jumps == 0, "Marked wall cannot be used before ability unlock")
	await touch_wall(1.0)
	await frames(16)
	check(player.wall_echo.sliding and player.velocity.y <= 80.01, "Leaning against marked wall caps real fall speed at 80px/s")
	Input.action_release("move_right")
	await frames(3)
	check(player.velocity.y > 80, "Releasing wall input restores normal gravity")
	await touch_wall(1.0)
	Input.action_press("jump")
	await frames(1)
	var spent := player.wall_echo.last_used_surface
	player.reset_input()
	await frames(2)
	check(wall_jumps == 1 and player.wall_echo.last_used_surface == spent, "Menu input reset does not restore the used wall")
	player.health.take_damage(1, player.position + Vector2(20, 0))
	check(player.state == Player.State.HURT and player.wall_echo.steering_left == 0 and player.wall_echo.last_used_surface == spent, "Damage clears wall control without granting another jump")
	check(player.wall_echo.pose_left==0,"Hurt/reset cancels the wall presentation timer")
	await fixture(["wall_echo"], Vector2(370, 400))
	box(Vector2(416, 352), Vector2(32, 704), &"attack_wall")
	Input.action_press("move_right")
	await frames(10)
	Input.action_press("attack")
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	check(player.state == Player.State.ATTACK and wall_jumps == 0, "Wall jump does not cancel sword commitment")
	await touch_wall(1.0)
	Input.action_press("jump")
	await frames(1)
	var position_before := player.position
	var lock_before := player.wall_echo.steering_left
	get_tree().paused = true
	await frames(10)
	check(player.position == position_before and player.wall_echo.steering_left == lock_before, "Pause freezes wall impulse and control timer")
	get_tree().paused = false
	release()
	await frames(100)
	check(player.is_on_floor() and player.wall_echo.last_used_surface.is_empty(), "Landing restores wall eligibility")
	await _alternating_walls()
	await _forgiving_controls()
	await _lab_route()
	var report := FileAccess.open("res://artifacts/wall_echo_metrics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "\t"))
	report.close()
	release()
	arena.queue_free()
	Audio.stop_all()
	await frames(3)
	print("WALL_ECHO_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _forgiving_controls() -> void:
	await touch_wall(1.0)
	release()
	Input.action_press("move_left")
	await frames(3)
	check(not player.is_on_wall() and player.wall_echo.can_jump(),"A brief real departure keeps the wall jump grace window")
	Input.action_press("jump")
	await frames(1)
	check(wall_jumps==1 and player.velocity.y < -500,"Slightly late wall press still launches")
	await fixture(["wall_echo","double_jump"],Vector2(350,400))
	box(Vector2(416,352),Vector2(32,704),&"buffer_wall")
	Input.action_press("move_right")
	await frames(6)
	check(not player.is_on_wall() and player.wall_echo.approaching_surface(player),"Early-press fixture is moving toward a marked wall, not already attached")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(10)
	check(wall_jumps==1 and not player.air_jump_used,"Buffered wall press triggers on contact without spending double jump")
	# Fixed rhythmic taps and one held direction: no wall-state driven turn inputs.
	for side: float in [-1.0,1.0]:
		await fixture(["wall_echo"],Vector2(304,704))
		box(Vector2(224,384),Vector2(32,640),&"left")
		box(Vector2(384,384),Vector2(32,640),&"right")
		Input.action_press("move_right" if side>0 else "move_left")
		var peak := player.position.y
		for tick: int in range(220):
			if tick%20==0:
				Input.action_press("jump")
			elif tick%20==3:
				Input.action_release("jump")
			await frames(1)
			peak = minf(peak,player.position.y)
			if peak<256:
				break
		check(peak<256 and wall_jumps>=4,"One held direction and rhythmic taps climb 448px without rapid reversing %s" % side)
		metrics["assisted_taps_"+str(side)] = {"height":704-peak,"jumps":wall_jumps}
		release()

func _alternating_walls() -> void:
	await fixture(["wall_echo"], Vector2(260, 704))
	box(Vector2(224, 384), Vector2(32, 640), &"left")
	box(Vector2(384, 384), Vector2(32, 640), &"right")
	var min_y := player.position.y
	var held_ticks := 0
	var direction := -1.0
	Input.action_press("move_left")
	Input.action_press("jump")
	for tick: int in range(440):
		await frames(1)
		min_y = minf(min_y, player.position.y)
		held_ticks += 1
		if held_ticks >= 16:
			Input.action_release("jump")
		if player.wall_echo.can_jump() and not player.jump_held and not Input.is_action_pressed("jump"):
			direction = player.wall_echo.normal_x
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if direction > 0 else "move_left")
			Input.action_press("jump")
			held_ticks = 0
		if min_y < 260:
			break
	metrics["alternating_walls"] = {"clear_width":128, "height_gained":704-min_y, "wall_jumps":wall_jumps}
	check(wall_jumps >= 3 and min_y < 384, "Alternating distinct walls climbs over 320px with wall echo only")
	check(not player.air_jump_used and not player.air_dash_used, "Alternating wall test requires neither double jump nor dash")

func walk_to(x: float, max_ticks := 300) -> bool:
	for tick: int in range(max_ticks):
		var offset := x - player.position.x
		if absf(offset) < 5:
			release()
			await frames(8)
			return true
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if offset > 0 else "move_left")
		await frames(1)
	release()
	return false

func _lab_route() -> void:
	release()
	arena.queue_free()
	await frames(3)
	var lab := preload("res://features/world/prototypes/echo_cloister_blockout.tscn").instantiate() as Node2D
	arena = lab
	add_child(lab)
	player = lab.get_node("Player") as Player
	wall_jumps = 0
	player.wall_echo.jumped.connect(func(_id: StringName) -> void: wall_jumps += 1)
	await frames(15)
	check(player.is_on_floor() and absf(player.position.y - 704) < 1, "Native TileMap blockout has a real safe floor")
	check(player.health.maximum == 6 and "steam_ward" in Session.abilities and "wall_echo" not in Session.abilities, "Preview inherits six HP, double jump, dash and ward before new pickup")
	await shot("chapter_three_blockout_entry")
	check(await walk_to(480), "Player can walk beneath the marked wall into the teaching shaft")
	var best_y := player.position.y
	Input.action_press("jump")
	for tick: int in range(100):
		if tick == 21:
			Input.action_release("jump")
		if tick == 22:
			Input.action_press("jump")
		if tick == 44:
			Input.action_press("dash")
		if tick == 45:
			Input.action_release("dash")
		await frames(1)
		best_y = minf(best_y, player.position.y)
	release()
	await frames(60)
	check(best_y > 450 and not lab.shortcut_open, "Old double-jump/dash route cannot bypass the authored upper gate")
	check(await walk_to(128), "Before unlock the player can safely retreat to the ability pickup")
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check("wall_echo" in Session.abilities and not lab.ability.visible, "Mapped interaction grants the ability once in the isolated preview")
	check(await walk_to(480), "Player returns to the same visible shaft after ability acquisition")
	Input.action_press("steam_ward")
	await frames(2)
	Input.action_release("steam_ward")
	Input.action_press("move_right")
	Input.action_press("jump")
	var held_ticks := 0
	var arrived := false
	var photographed := false
	var ward_verified := false
	for tick: int in range(620):
		await frames(1)
		held_ticks += 1
		if player.is_on_floor() and absf(player.position.y - 256) < 2 and player.position.x < 416:
			release()
			arrived = true
			break
		if wall_jumps > 0 and not ward_verified:
			check(player.steam_ward.active_left > 0 and player.health.current == 6, "Actual shield remains active through a wall jump")
			ward_verified = true
		if player.position.y < 430 and not photographed:
			await shot("chapter_three_blockout_wall")
			photographed = true
		if player.position.y < 236:
			Input.action_release("move_right")
			Input.action_press("move_left")
			if player.position.x < 380:
				release()
				await frames(45)
				arrived = player.is_on_floor() and absf(player.position.y - 256) < 2
				break
		elif held_ticks >= 16:
			Input.action_release("jump")
			if player.wall_echo.can_jump() and not player.jump_held:
				var direction := player.wall_echo.normal_x
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_press("move_right" if direction > 0 else "move_left")
				Input.action_press("jump")
				held_ticks = 0
	check(arrived, "Real input reaches the upper landing of the 448px teaching loop")
	if not arrived:
		print("BLOCKOUT_ROUTE_DEBUG: ", player.position, " wall_jumps=", wall_jumps)
	else:
		check(await walk_to(320), "Upper landing provides a wide approach to the return latch")
		Input.action_press("interact")
		await frames(2)
		Input.action_release("interact")
		await frames(2)
		check(lab.shortcut_open and lab.gate_shape.disabled, "Opening the latch removes a real upper return barrier")
		check(await walk_to(160), "Opened shortcut gives a new walking route toward the lower courtyard")
		await frames(90)
		check(lab.loop_completed and player.is_on_floor() and player.health.current == 6, "Complete reward-wall-upper-return loop ends safely without extra healing")
		await shot("chapter_three_blockout_return")
	metrics["native_cloister_route"] = {"completed":lab.loop_completed, "wall_jumps":wall_jumps, "upper_height":448, "old_abilities_peak_y":best_y}
	check(not FileAccess.file_exists(Session.save_path), "Preview never creates a campaign or test progress file")
