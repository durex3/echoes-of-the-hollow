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

func point(id: String) -> WorldInteraction:
	return game.room.get_node("Interactions/" + id) as WorldInteraction

func use(id: String) -> void:
	var target := point(id)
	game.player.position = target.position
	await frames(2)
	game._interact(target)
	await frames(4)

func clear_enemies() -> void:
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.queue_free()
	await frames(2)

func shot(name_text: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	var error := get_viewport().get_texture().get_image().save_png("res://artifacts/" + name_text + ".png")
	check(error == OK, "Saved confluence screenshot " + name_text)

func _run() -> void:
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.clear()
	game.load_room("broken_bell_atrium", "confluence_return")
	await frames(3)
	await use("Confluence")
	check(game.room.room_id == "broken_bell_atrium", "Central confluence bridge stays locked before both weights")
	game.preview_flags.assign(["east_weight_restored", "west_weight_restored"])
	await use("Confluence")
	check(game.room.room_id == "confluence_bridge", "Both restored weights open the confluence bridge hall")
	check(game.room.get_node("Enemies").get_child_count() == 2, "Confluence opens with one invoker and one skimmer")
	check(game.room.get_node("Enemies/Invoker") != null and game.room.get_node("Enemies/Skimmer") != null, "Combined encounter uses distinct enemy identities")
	await use("Terminal")
	check(game.room.room_id == "confluence_bridge", "Terminal platform stays locked while the combined enemies live")
	await shot("confluence_bridge_combat")
	await clear_enemies()
	await use("Altar")
	check(game.checkpoint_room == "confluence_bridge" and game.checkpoint_spawn == "altar", "Safe altar records a retry point after the combined encounter")
	await use("Terminal")
	check(game.room.room_id == "terminal_platform" and game.player.position.x < 200.0, "Clear combat opens the eastern terminal platform entrance")
	game.load_room("confluence_bridge", "altar")
	await frames(4)
	await use("Return")
	check(game.room.room_id == "broken_bell_atrium" and game.player.position.y < 300.0, "Confluence return lands at the central upper bridge")
	print("CONFLUENCE_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
