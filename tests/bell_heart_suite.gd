extends Node

var checks := 0
var failures: Array[String] = []
var game: Node2D
var wall_jumps := 0
var route_peak_y := 9999.0
var route_max_x := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures.append(message)

func frames(count := 1) -> void:
	for _tick: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func at(point_name: String) -> WorldInteraction:
	return game.room.get_node("Interactions/" + point_name) as WorldInteraction

func interact(point: WorldInteraction) -> void:
	game.player.position = point.position
	await frames(2)
	game._interact(point)
	await frames(4)

func release_input() -> void:
	for action: String in ["move_left", "move_right", "jump", "dash", "attack", "interact", "steam_ward"]:
		Input.action_release(action)

func real_wall_route() -> void:
	release_input()
	wall_jumps = 0
	game.player.wall_echo.jumped.connect(func(_surface: StringName) -> void: wall_jumps += 1)
	Input.action_press("move_right")
	var peak_y: float = game.player.position.y
	var max_x: float = game.player.position.x
	var climb_done := false
	for tick: int in range(420):
		if tick == 28:
			Input.action_press("jump")
		if tick == 48:
			Input.action_release("jump")
		if wall_jumps >= 4 and not climb_done:
			climb_done = true
			Input.action_release("move_left")
			Input.action_press("move_right")
		if not climb_done and game.player.wall_echo.last_used_surface == &"quiet_right":
			Input.action_release("move_right")
			Input.action_press("move_left")
		elif not climb_done and game.player.wall_echo.last_used_surface == &"quiet_left":
			Input.action_release("move_left")
			Input.action_press("move_right")
		if tick > 20 and game.player.wall_echo.can_jump() and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
			await frames(2)
			Input.action_release("jump")
		await frames(1)
		peak_y = minf(peak_y, game.player.position.y)
		max_x = maxf(max_x, game.player.position.x)
		if climb_done and game.player.is_on_floor() and game.player.position.x > 520.0:
			break
	if wall_jumps >= 4:
		Input.action_press("dash")
		await frames(2)
		Input.action_release("dash")
		await frames(50)
	release_input()
	await frames(3)
	route_peak_y = peak_y
	route_max_x = max_x

func shot(name_text: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	var old_paused := get_tree().paused
	get_tree().paused = true
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var result := get_viewport().get_texture().get_image().save_png("res://artifacts/" + name_text + ".png")
	get_tree().paused = old_paused
	check(result == OK, "Saved quiet reliquary screenshot " + name_text)

func _run() -> void:
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.clear()
	game.load_room("broken_bell_atrium", "cloister_upper")
	await frames(3)
	var entrance := at("QuietReliquary")
	await interact(entrance)
	check(game.room.room_id == "broken_bell_atrium", "Quiet reliquary stays locked before wall echo")
	Session.unlock("wall_echo")
	await interact(entrance)
	check(game.room.room_id == "quiet_reliquary", "Wall echo opens the optional quiet reliquary")
	await shot("bell_heart_reliquary")
	check(game.room.get_node("Enemies").get_child_count() == 0, "Quiet reliquary has no enemies")
	check(Session.maximum_health() == 6, "Preview starts with six health after the first chapter bloom")
	await real_wall_route()
	check(wall_jumps >= 3, "Real InputMap route alternates the marked walls")
	check(wall_jumps >= 3 and route_peak_y < 150.0, "Wall route reaches the upper ledge height")
	release_input()
	Input.action_press("move_right")
	for tick: int in range(220):
		if tick == 26 or tick == 48:
			Input.action_press("jump")
		if tick == 44 or tick == 66:
			Input.action_release("jump")
		if tick == 68:
			Input.action_press("dash")
		if tick == 71:
			Input.action_release("dash")
		await frames(1)
	release_input()
	check(game.player.position.x > 900.0, "Real movement reaches the reward side")
	var heart := at("Heart")
	game.player.health.take_damage(1, game.player.position)
	var before: int = game.player.health.current
	await interact(heart)
	await shot("bell_heart_claimed")
	check("bell_heart" in game.preview_flags, "Bell heart is claimed once in preview memory")
	check("bell_heart" in Session.flags, "Bell heart uses the stable session flag")
	check(Session.maximum_health() == 7, "Bell heart raises maximum health by one")
	check(game.player.health.current == 7 and before < 7, "Bell heart restores health after increasing the maximum")
	await interact(heart)
	check(Session.maximum_health() == 7 and game.player.health.current == 7, "Bell heart cannot be claimed twice")
	print("BELL_HEART_RESULT: %d checks, %d failures" % [checks, failures.size()])
	remove_child(game)
	game.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(2)
	get_tree().quit(0 if failures.is_empty() else 1)
