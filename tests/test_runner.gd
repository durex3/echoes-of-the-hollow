extends Node
## Integration tests run the real game scene with real physics and isolated saves.

const Repository := preload("res://core/save_repository.gd")
var failures: Array[String] = []
var checks := 0
var game: Node2D
var visual := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visual = "--visual" in OS.get_cmdline_user_args()
	Session.save_path = "user://test_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_ui_settings_%s.cfg" % OS.get_process_id()
	Session.set_language("en")
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		push_error("Integration test timeout")
		get_tree().quit(1))
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		print("FAIL: ", description)

func frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func press(action: String, count := 1) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames(1)

func shot(filename: String) -> void:
	if not visual:
		return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
	check(result == OK, "Screenshot: " + filename)

func _run() -> void:
	game = preload("res://app/main.tscn").instantiate()
	add_child(game)
	await frames(4)
	check(game.ui.modal.visible, "Title menu opens")
	await shot("01_title")
	game.start_game(false)
	await frames(20)
	var player: Player = game.player
	check(player.is_on_floor(), "Player lands on actual TileMap collision")
	check(absf(player.position.y - 480) < 2, "Spawn feet align with floor")
	check(player.health.current == 5, "Player begins with full health")
	check(game.room.get_node("Terrain").get_used_cells().size() > 100, "Room contains authored TileMap cells")
	await shot("02_forest")
	var start := player.position
	await press("move_right", 12)
	check(player.position.x > start.x + 20, "Mapped input moves player")
	player.revive(Vector2(175,480))
	await frames(4)
	var floor_y := player.position.y
	Input.action_press("jump")
	var highest := floor_y
	for index: int in range(30):
		await frames(1)
		highest = minf(highest,player.position.y)
	Input.action_release("jump")
	check(floor_y - highest > 90 and floor_y - highest < 110, "Full jump height follows configured metrics")
	await frames(35)
	check(player.is_on_floor(), "Jump lands again")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	var short_highest := player.position.y
	for index: int in range(30):
		await frames(1)
		short_highest = minf(short_highest,player.position.y)
	check(floor_y - short_highest < floor_y - highest - 20, "Tap produces a shorter jump")
	await frames(20)
	player.revive(Vector2(190,480))
	await frames(3)
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(not player.air_jump_used, "Double jump unavailable before unlock")
	await frames(40)
	# Pause with an actual input event, not a direct call to the UI.
	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await frames(2)
	var paused_pos := player.position
	Input.action_press("move_right")
	await frames(10)
	Input.action_release("move_right")
	check(get_tree().paused and player.position == paused_pos, "Pause freezes gameplay physics")
	game.resume()
	await frames(2)
	check(not get_tree().paused, "Resume restores gameplay")
	# Real traversal: ascend the lower ledge, prove high ledge gate, then unlock and climb.
	player.revive(Vector2(205,480))
	await frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(25)
	check(player.is_on_floor() and absf(player.position.y-384)<2, "Lower forest platform reachable with normal jump")
	Input.action_press("jump")
	var gate_apex := player.position.y
	for index: int in range(40):
		await frames(1)
		gate_apex = minf(gate_apex,player.position.y)
	Input.action_release("jump")
	check(gate_apex > 260, "Normal jump cannot reach the 160px high ability gate")
	await frames(20)
	Session.unlock("double_jump")
	player.revive(Vector2(305,384))
	await frames(4)
	Input.action_press("jump")
	await frames(18)
	Input.action_release("jump")
	await frames(1)
	Input.action_press("jump")
	Input.action_press("move_right")
	await frames(23)
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(30)
	check(player.is_on_floor() and absf(player.position.y-224)<2, "Double jump physically reaches high shrine platform")
	Session.abilities.clear()
	Session.progress_changed.emit()
	# Real collision query proves attack hits once per swing and can hit again later.
	var enemy: Slime = game.room.get_node("Enemies/Slime0")
	enemy.speed = 0
	enemy.position = Vector2(570,480)
	player.revive(Vector2(520,480))
	player.facing = 1
	await frames(5)
	await press("attack", 15)
	check(enemy.health.current == 1, "First swing damages once despite overlapping frames")
	await shot("03_combat")
	await frames(20)
	enemy.position = Vector2(570,480)
	enemy.velocity = Vector2.ZERO
	player.revive(Vector2(520,480))
	await frames(3)
	await press("attack", 22)
	check(enemy.health.current == 0, "Second distinct swing defeats enemy")
	await frames(40)
	check(not is_instance_valid(enemy), "Defeated enemy scene is released")
	# Reach the door and use the same interaction path as the player.
	player.revive(Vector2(1180,480))
	await frames(4)
	await press("interact",2)
	check(game.room.room_id == "ruins", "Door changes forest to ruins")
	await frames(5)
	check(player.health.current == 5, "Room change preserves player state")
	await shot("04_ruins")
	player.revive(Vector2(620,480))
	# Traversal test isolates geometry from the separately tested enemy contact damage.
	player.health.invulnerability_left = 10.0
	await frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(24)
	check(player.is_on_floor() and absf(player.position.y-416)<2, "First archive platform reachable without ability")
	player.revive(Vector2(800,416))
	await frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(38)
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(20)
	check(player.is_on_floor() and absf(player.position.y-352)<2, "Ability platform reachable before unlocking double jump")
	await frames(4)
	await press("interact",2)
	check(Session.abilities.has("double_jump"), "Ability pickup unlocks double jump")
	check(not game.room.get_node("Interactions/Echo").visible, "Collected ability is hidden")
	check(FileAccess.file_exists(Session.save_path), "Ability unlock commits isolated save")
	await frames(4)
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(1)
	check(player.air_jump_used and player.velocity.y < -400, "Second airborne jump works after unlock")
	Input.action_release("jump")
	player.revive(Vector2(160,480))
	await frames(4)
	await press("interact",2)
	check(Session.checkpoint_room == "ruins", "Checkpoint records stable room ID")
	player.health.take_damage(1,Vector2(0,0))
	check(player.health.current == 4, "Damage decreases health")
	player.health.take_damage(1,Vector2(0,0))
	check(player.health.current == 4, "Invulnerability rejects repeated contact")
	player.health.invulnerability_left = 0
	player.health.take_damage(10,Vector2(0,0))
	await frames(70)
	check(player.state != Player.State.DEAD and player.health.current == 5, "Death restores player at checkpoint")
	check(game.room.room_id == "ruins", "Death restores checkpoint room")
	# Return route and completion condition.
	player.revive(Vector2(50,480))
	await frames(4)
	await press("interact",2)
	check(game.room.room_id == "forest", "Return door restores forest")
	player.revive(Vector2(400,224))
	await frames(4)
	await press("interact",2)
	check(Session.completed, "High shrine completes the exploration loop")
	await shot("05_complete")
	game.resume()
	# Save repository round trip, recovery, version guard, and write failure reporting.
	var suite := preload("res://tests/combat_suite.gd").new()
	add_child(suite)
	await suite.run(self,game)
	suite.queue_free()
	var scribe_suite := preload("res://tests/scribe_suite.gd").new()
	add_child(scribe_suite)
	await scribe_suite.run(self,game)
	scribe_suite.queue_free()
	var exploration := preload("res://tests/exploration_suite.gd").new()
	add_child(exploration)
	await exploration.run(self,game)
	exploration.queue_free()
	var dash_suite := preload("res://tests/dash_suite.gd").new()
	add_child(dash_suite)
	await dash_suite.run(self,game)
	dash_suite.queue_free()
	var ui_suite := preload("res://tests/reward_language_suite.gd").new()
	add_child(ui_suite)
	await ui_suite.run(self,game)
	ui_suite.queue_free()
	check(Repository.validate(Session.snapshot()), "Save schema validates")
	check(Session.commit() == OK, "Second save safely replaces first")
	var saved_room := Session.checkpoint_room
	Session.reset()
	check(Session.restore() and Session.checkpoint_room == saved_room and Session.abilities.has("double_jump"), "Save restores progress after reset")
	var broken := FileAccess.open(Session.save_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	check(not Repository.read(Session.save_path).is_empty(), "Corrupt primary recovers valid backup")
	check(Session.commit() == OK, "Save repairs corrupt primary without destroying valid backup")
	var future := Session.snapshot()
	future.version = 999
	check(not Repository.validate(future), "Unknown future save version rejected")
	var invalid := Session.snapshot()
	invalid.checkpoint_room = "missing"
	check(not Repository.validate(invalid), "Unknown room ID rejected")
	check(Repository.write("user://missing_test_directory/save.json",Session.snapshot()) != OK, "Unwritable target reports failure")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(Session.save_path + suffix):
			DirAccess.remove_absolute(Session.save_path + suffix)
	game.queue_free()
	if FileAccess.file_exists(Session.settings_path):
		DirAccess.remove_absolute(Session.settings_path)
	Audio.stop_all()
	await frames(4)
	if visual:
		await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
