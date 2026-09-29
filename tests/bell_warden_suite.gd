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
	for _i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func until_state(expected: BellWarden.State, limit := 240) -> bool:
	for _i in range(limit):
		if not is_instance_valid(boss): return false
		if boss.state == expected: return true
		await frames(1)
	return is_instance_valid(boss) and boss.state == expected

func _run() -> void:
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.assign(["east_weight_restored", "west_weight_restored"])
	game.load_room("terminal_platform", "entry")
	await frames(4)
	boss = game.room.get_node("Enemies/BellWarden") as BellWarden
	check(boss.health.maximum == 18, "Boss uses configured health")
	check(boss.state == BellWarden.State.DORMANT, "Boss starts dormant")
	game.player.position.x = 196.0
	await frames(4)
	check(boss.state == BellWarden.State.INTRO, "Arena trigger awakens boss")
	boss.set_physics_process(false)
	game.player.revive(boss.global_position + Vector2(-85.0, 0.0))
	var far_hp: int = game.player.health.current
	boss.contact_box.active = true
	await frames(2)
	check(game.player.health.current == far_hp, "Contact misses outside the body")
	boss.contact_box.end_swing()
	game.player.revive(boss.global_position)
	game.player.health.restore_full()
	var contact_hp: int = game.player.health.current
	boss.contact_box.active = true
	await frames(2)
	check(game.player.health.current < contact_hp, "Contact uses the real damage chain")
	boss.contact_box.end_swing()
	boss.set_physics_process(true)
	game.player.position = Vector2(196.0, 320.0)
	check(await until_state(BellWarden.State.WINDUP), "Single loop selects a normal attack")
	check(boss.timer <= 0.30, "Normal attack windup is fast")
	check(await until_state(BellWarden.State.STRIKE), "Normal attack reaches strike")
	check(boss.attack_box.active, "Weapon hitbox exists during strike")
	check(await until_state(BellWarden.State.RECOVER), "Normal attack has recovery")
	check(boss.timer >= 0.70, "Recovery is punishable")
	boss.set_physics_process(false)
	check(boss.regular_attacks >= 1, "Reference-style loop records ordinary attacks")
	boss.set_physics_process(true)
	boss.health.current = 3
	boss.regular_attacks = 3
	boss.target = game.player
	boss._enter(BellWarden.State.CHASE)
	boss.timer = 0.0
	boss._start_attack()
	check(boss.attack in [BellWarden.Attack.SWEEP, BellWarden.Attack.DASH], "Low health keeps the regular loop until the finisher is designed")
	print("BELL_WARDEN_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
