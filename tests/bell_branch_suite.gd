extends Node

var checks := 0
var failures: Array[String] = []
var game: Node2D

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

func shot(name_text: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	var old_paused := get_tree().paused
	get_tree().paused = true
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var result := get_viewport().get_texture().get_image().save_png("res://artifacts/" + name_text + ".png")
	get_tree().paused = old_paused
	check(result == OK, "Saved branch screenshot " + name_text)

func clear_enemies() -> void:
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await frames(2)

func walk_bridge(direction: String, target_x: float) -> bool:
	Input.action_press(direction)
	for tick: int in range(480):
		await frames()
		if absf(game.player.position.x - target_x) < 20.0:
			Input.action_release(direction)
			return absf(game.player.position.y - 256.0) < 8.0 and game.player.is_on_floor()
	Input.action_release(direction)
	return false

func use(id: String) -> void:
	var point := game.room.get_node("Interactions/" + id) as WorldInteraction
	game.player.position = point.position
	await frames(2)
	game._interact(point)
	await frames(3)

func start() -> void:
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.clear()
	game.load_room("broken_bell_atrium", "machine")
	await frames(3)

func east_first() -> void:
	await start()
	await use("EastWeight")
	check(game.room.room_id == "bell_weight_chamber", "East branch enters the authored bell weight chamber")
	check(game.room.get_node("BridgeCollision/Collision").disabled, "East bridge stays non-solid before the weight is restored")
	await shot("bell_branch_machine")
	await clear_enemies()
	await use("EastWeight")
	check("east_weight_restored" in game.preview_flags, "East weight persists as an in-memory branch flag")
	check(game.room.get_node("BridgeCollision/Collision").disabled == false, "East bridge collision opens after the weight is restored")
	check(game.player.position.x < 1000.0 and game.player.is_on_floor(), "Enabling the east bridge clears the reward-side collision overlap")
	game.cleared_rooms.append("bell_weight_chamber")
	game.load_room("bell_weight_chamber", "bridge")
	await frames(5)
	check(await walk_bridge("move_right", 960.0), "East bridge supports real player movement across the upper route")
	await use("BridgeReturn")
	check(game.room.room_id == "broken_bell_atrium" and game.player.position.y < 300, "East return bridge lands at the upper atrium spawn")
	await shot("bell_branch_east_return")
	game.queue_free()

func west_first() -> void:
	await start()
	game.load_room("hanging_gallery", "entry")
	await frames(3)
	check(game.room.get_node("BridgeCollision/Collision").disabled, "West bridge stays non-solid before the weight is restored")
	await use("WestWeight")
	check(game.preview_flags.has("west_weight_restored") == false, "West weight is not reachable before the gallery is cleared")
	await clear_enemies()
	await use("WestWeight")
	check("west_weight_restored" in game.preview_flags, "West weight persists as an in-memory branch flag")
	check(game.room.get_node("BridgeCollision/Collision").disabled == false, "West bridge collision opens after the weight is restored")
	game.cleared_rooms.append("hanging_gallery")
	game.load_room("hanging_gallery", "bridge")
	await frames(5)
	check(await walk_bridge("move_left", 160.0), "West bridge supports real player movement across the upper route")
	await shot("bell_branch_gallery_bridge")
	await use("BridgeReturn")
	check(game.room.room_id == "broken_bell_atrium" and game.player.position.y < 300, "West return bridge lands at the upper atrium spawn")
	game.queue_free()

func _run() -> void:
	await east_first()
	await west_first()
	print("BELL_BRANCH_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
