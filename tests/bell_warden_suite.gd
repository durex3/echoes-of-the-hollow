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
	_check_state_contracts()
	_check_boss_decisions()
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.preview_flags.assign(["east_weight_restored", "west_weight_restored"])
	game.load_room("terminal_platform", "entry")
	await frames(4)
	boss = game.room.get_node("Enemies/BellWarden") as BellWarden
	check(boss.health.maximum == 18, "Boss uses configured health")
	check(boss.state == BellWarden.State.DORMANT, "Boss starts dormant")
	boss.velocity.x = boss.config.move_speed
	boss.state = BellWarden.State.CHASE
	boss._update_visual()
	check(boss.body_sprite.region_rect.position.y == 93.0, "Moving boss uses the source sheet walk row")
	boss.state = BellWarden.State.RECOVER
	boss.velocity.x = -boss.facing * boss.config.recovery_retreat_speed
	boss.walk_clock = 0.0
	boss._update_visual()
	var retreat_frame := boss.body_sprite.region_rect.position.x
	boss.walk_clock = 0.1
	boss._update_visual()
	check(boss.body_sprite.region_rect.position.y == 93.0 and boss.body_sprite.region_rect.position.x != retreat_frame, "Retreat animates backward while facing the player")
	boss.state = BellWarden.State.DORMANT
	boss.velocity.x = 0.0
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
	await frames(4)
	var retreat_at := boss.position
	var retreat_region := boss.body_sprite.region_rect
	var retreat_facing := boss.facing
	await shot("bell_warden_retreat_start")
	await frames(8)
	check(boss.state == BellWarden.State.RECOVER and (boss.position.x - retreat_at.x) * retreat_facing < 0.0 and boss.facing == retreat_facing, "Natural recovery retreats while keeping its committed facing")
	check(boss.body_sprite.region_rect.position.y == 93.0 and boss.body_sprite.region_rect != retreat_region, "Natural retreat advances the actual source walk frames")
	await shot("bell_warden_retreat_step")
	var paused_region := boss.body_sprite.region_rect
	var paused_at := boss.position
	get_tree().paused = true
	await frames(8)
	check(boss.body_sprite.region_rect == paused_region and boss.position == paused_at, "Pause freezes retreat animation together with movement")
	get_tree().paused = false
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
	check(boss.attack_states.size() == 2, "Only designed Chapter III normal attacks are registered")
	print("BELL_WARDEN_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_boss_decisions() -> void:
	var furnace := FurnaceKeeperDecision.new()
	var available := {0: true, 1: true, 2: true, 3: true, 4: true}
	check(furnace.choose_attack(200.0, false, 5, 4, 3, available, 300.0) == FurnaceKeeper.Attack.DASH, "Keeper chooses its reference-style dash after four ordinary attacks at mid-range")
	check(furnace.choose_attack(90.0, false, 5, 4, 3, available, 300.0) != FurnaceKeeper.Attack.DASH, "Keeper refuses a point-blank dash")
	check(furnace.choose_attack(30.0, false, 5, 1, 3, available, 300.0) == FurnaceKeeper.Attack.MELEE, "Keeper does not launch a slam through a point-blank player")
	available[0] = false
	check(furnace.choose_attack(200.0, false, 5, 4, 3, available, 300.0) != FurnaceKeeper.Attack.DASH, "Keeper respects dash cooldown")
	var hollow := HollowWardenDecision.new()
	check(hollow.choose_attack(50.0, false, 0, 0, false, true, true) == HollowWarden.Attack.SWEEP, "King chooses sweep at close range")
	check(hollow.choose_attack(190.0, false, 0, 0, false, true, true) == HollowWarden.Attack.RUSH, "King chooses rush at long range")
	check(hollow.choose_attack(50.0, false, 0, 0, false, false, true) == HollowWarden.Attack.RUSH, "King excludes a cooling sweep")
	var bell := BellWardenDecision.new()
	check(bell.choose_attack(180.0, false, 3, true, true) == BellWarden.Attack.DASH, "Bell warden dashes after three sweeps at mid-range")
	check(bell.choose_attack(80.0, false, 3, true, true) == BellWarden.Attack.SWEEP, "Bell warden does not dash at point-blank range")
	check(bell.choose_attack(180.0, false, 3, false, true) == BellWarden.Attack.SWEEP, "Bell warden respects dash cooldown")

func shot(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://artifacts/" + label + ".png")
	check(error == OK, "Saved native screenshot " + label)

func _check_state_contracts() -> void:
	for scene: PackedScene in [preload("res://features/enemies/hollow_warden.tscn"), preload("res://features/enemies/furnace_keeper.tscn"), preload("res://features/enemies/bell_warden.tscn")]:
		var enemy := scene.instantiate()
		add_child(enemy)
		enemy.set_physics_process(false)
		var machine: BossStateMachine = enemy.state_machine
		check(machine.get_parent() == enemy and machine.attacks.all(func(item: BossAttackState) -> bool: return item.get_parent() == machine and item.host == enemy), "Boss states are owned scene-tree nodes: " + enemy.name)
		var first := machine.attacks[0]
		var other := machine.attacks[1]
		if enemy is HollowWarden:
			(enemy as HollowWarden).active_profile = (enemy as HollowWarden).config.sweep
		machine.change(first)
		first.arm()
		machine.tick(first.cooldown + 0.1)
		check(not machine.can_decide() and not first.ready(), "Cooldown expiry cannot interrupt an executing attack: " + enemy.name)
		other.arm()
		machine.finish()
		var elapsed_before := first.elapsed
		machine.tick(other.cooldown + 0.1)
		check(machine.can_decide() and not first.running and first.elapsed == elapsed_before and other.ready(), "Finished states stop executing while inactive cooldowns keep advancing: " + enemy.name)
		enemy.free()
