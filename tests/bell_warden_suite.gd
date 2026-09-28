extends Node

var checks := 0
var failures: Array[String] = []
var game: Node2D
var boss: BellWarden

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

func until_state(expected: BellWarden.State, limit := 240) -> bool:
	for _tick: int in range(limit):
		if boss.state == expected:
			return true
		await frames(1)
	return boss.state == expected

func shot(name_text: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	var error := get_viewport().get_texture().get_image().save_png("res://artifacts/" + name_text + ".png")
	check(error == OK, "Saved bell warden screenshot " + name_text)

func _run() -> void:
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.assign(["east_weight_restored", "west_weight_restored"])
	game.load_room("terminal_platform", "entry")
	await frames(4)
	boss = game.room.get_node("Enemies/BellWarden") as BellWarden
	check(boss.health.maximum == 18, "Bell warden enters with the tuned 18 health")
	check(boss.state == BellWarden.State.DORMANT, "Boss remains dormant before the arena trigger")
	game.player.position.x = 196.0
	await frames(4)
	check(boss.state == BellWarden.State.INTRO, "Crossing the arena trigger awakens the bell warden")
	await until_state(BellWarden.State.WINDUP)
	check(boss.attack == BellWarden.Attack.SWEEP, "First attack teaches the readable scythe sweep")
	await shot("bell_warden_sweep_warning")
	await until_state(BellWarden.State.STRIKE)
	check(boss.attack_box.active, "Sweep damage is active only during its strike phase")
	await until_state(BellWarden.State.RECOVER)
	check(boss.timer > 0.7, "Sweep leaves a substantial recovery counter window")
	game.player.position = Vector2(380, 320)
	await until_state(BellWarden.State.WINDUP)
	check(boss.attack == BellWarden.Attack.DASH, "Second attack is a distinct locked direction dash")
	await until_state(BellWarden.State.RECOVER)
	await until_state(BellWarden.State.ECHO_WARNING)
	check(is_instance_valid(boss.mark), "Echo attack creates a delayed mark at the committed position")
	await shot("bell_warden_echo_mark")
	var first_mark: EchoMark = boss.mark
	var marked := first_mark.global_position
	game.player.position = marked + Vector2(180, 0)
	game.player.health.restore_full()
	await frames(140)
	check(not is_instance_valid(first_mark), "Echo mark expires after one active pulse")
	check(game.player.health.current == game.player.health.maximum, "Leaving the mark avoids the single ghost pulse")
	game.load_room("terminal_platform", "entry")
	await frames(4)
	boss = game.room.get_node("Enemies/BellWarden") as BellWarden
	boss.set_physics_process(false)
	var guarded_mark := EchoMark.new()
	guarded_mark.player = game.player
	guarded_mark.delay_seconds = 0.1
	guarded_mark.active_seconds = 0.2
	guarded_mark.global_position = game.player.global_position
	game.room.add_child(guarded_mark)
	var guarded_hp: int = game.player.health.current
	check(game.player.steam_ward.activate(), "Inherited shield can activate before the ghost pulse")
	await frames(12)
	check(game.player.health.current == guarded_hp and game.player.steam_ward.active_left <= 0.0, "Ghost pulse consumes the shield through the real hurtbox without health loss")
	game.load_room("terminal_platform", "entry")
	await frames(4)
	boss = game.room.get_node("Enemies/BellWarden") as BellWarden
	boss.health.take_damage(14, game.player.position)
	game.player.position.x = 196.0
	await frames(4)
	var reached_phase_three := false
	for _tick: int in range(360):
		if boss.phase == 3:
			reached_phase_three = true
			break
		await frames(1)
	check(reached_phase_three, "Low health transitions the boss into the third phase after an attack")
	var ghost_started := false
	for _tick: int in range(720):
		if boss.state == BellWarden.State.GHOST_WARNING:
			ghost_started = true
			break
		await frames(1)
	check(ghost_started and is_instance_valid(boss.ghost), "Final phase summons a delayed fixed-position ghost")
	if is_instance_valid(boss.ghost):
		var ghost_ref: EchoMark = boss.ghost
		check(ghost_ref.global_position.x >= 0.0 and ghost_ref.global_position.x <= 576.0, "Ghost remains inside the fixed arena")
		ghost_ref.global_position = boss.global_position + Vector2(boss.facing * 48.0, 0.0)
		var dispelled := false
		var age_before_free := 0.0
		var delay_before_free := ghost_ref.delay_seconds
		for _tick: int in range(360):
			if not is_instance_valid(ghost_ref):
				dispelled = true
				break
			age_before_free = ghost_ref.age
			await frames(1)
		check(dispelled and age_before_free < delay_before_free, "Final phase scythe dispels a ghost before its scheduled pulse")
	print("BELL_WARDEN_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
