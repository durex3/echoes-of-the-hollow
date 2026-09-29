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
	check(absf(boss.body_sprite.position.x - boss.facing * 40.0) < 0.1, "Opaque boss body is centered on its physical capsule despite atlas padding")
	# Exercise the same player attack and enemy contact paths used in the live fight.
	boss.set_physics_process(false)
	game.player.revive(boss.global_position + Vector2(-85.0, 0.0))
	var distant_hp: int = game.player.health.current
	var distant_x: float = game.player.position.x
	boss.contact_box.active = true
	await frames(2)
	check(game.player.health.current == distant_hp and absf(game.player.position.x - distant_x) < 1.0, "Contact cannot damage or push the player across empty space")
	boss.contact_box.end_swing()
	game.player.revive(boss.global_position + Vector2(-38.0, 0.0))
	game.player.facing = 1.0
	var hp_before_sword: int = boss.health.current
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(8)
	check(boss.health.current == hp_before_sword - 1, "Player sword reaches the bell warden Hurtbox and deals damage")
	game.player.revive(boss.global_position)
	game.player.health.restore_full()
	var player_hp_before_contact: int = game.player.health.current
	boss.contact_box.active = true
	await frames(2)
	check(game.player.health.current == player_hp_before_contact - 1, "Bell warden contact box damages the player through the real Hurtbox")
	boss.contact_box.end_swing()
	boss.set_physics_process(true)
	game.player.position.x = 196.0
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
	await until_state(BellWarden.State.WINDUP)
	check(boss.phase == 1 and boss.attack != BellWarden.Attack.ECHO and not is_instance_valid(boss.mark), "First phase teaches melee without an unseen ranged cast")
	boss.health.take_damage(5, game.player.position)
	await until_state(BellWarden.State.TRANSITION)
	check(boss.phase == 2 and not boss.attack_box.active, "Second phase begins at twelve health with a harmless transition")
	await shot("bell_warden_phase_two")
	await until_state(BellWarden.State.ECHO_WARNING)
	check(is_instance_valid(boss.mark) and boss.phase == 2, "Second phase introduces the three-beat resonance cast")
	check(absf(boss.mark.global_position.y - 317.0) < 12.0, "Resonance lanes sit on the arena floor")
	await frames(28)
	game.player.position.x = 280.0
	await frames(26)
	await shot("bell_warden_echo_mark")
	check(boss.phase_marks.size() == 3, "Second phase creates three staggered resonance pins")
	check(absf(boss.phase_marks[0].global_position.x - boss.phase_marks[2].global_position.x) > 30.0, "Staggered pins lock separate player positions")
	game.player.position = Vector2(100, 320)
	game.player.health.restore_full()
	check(await until_state(BellWarden.State.ECHO_ACTIVE), "Second phase releases the mark on the cast action clock")
	await frames(2)
	var resonance_triggered := false
	for pin: EchoMark in boss.phase_marks:
		if is_instance_valid(pin) and pin.triggered:
			resonance_triggered = true
	check(resonance_triggered, "Resonance lanes activate on staggered release timings")
	check(await until_state(BellWarden.State.RECOVER), "Second phase resonance cage ends in a punish window")
	game.player.revive(Vector2(100, 320))
	boss.set_physics_process(false)
	await frames(140)
	var resonance_expired := true
	for pin: EchoMark in boss.phase_marks:
		if is_instance_valid(pin):
			resonance_expired = false
	check(resonance_expired, "Resonance lanes expire after their single pulse")
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
	boss.health.take_damage(11, game.player.position)
	game.player.position.x = boss.position.x - 70.0
	await frames(4)
	var reached_phase_three := false
	for _tick: int in range(720):
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
	check(ghost_started and is_instance_valid(boss.ghost) and boss.phase_ghosts.size() == 1, "Final phase summons one readable inverse ghost")
	await frames(8)
	await shot("bell_warden_phase_three_ghost")
	if is_instance_valid(boss.ghost):
		var ghost_ref: EchoMark = boss.ghost
		check(ghost_ref.global_position.x >= 0.0 and ghost_ref.global_position.x <= 576.0, "Ghost remains inside the fixed arena")
		game.player.revive(Vector2(100, 320))
		check(await until_state(BellWarden.State.GHOST_ACTIVE), "Third phase releases the mirrored hunt after its warning")
		await shot("bell_warden_phase_three_combo")
		check(is_instance_valid(ghost_ref), "Inverse ghost remains visible during the exchange")
		var boss_x_before_exchange := boss.global_position.x
		ghost_ref.global_position.x = boss.global_position.x + 80.0
		boss._enter(BellWarden.State.GHOST_ACTIVE)
		await frames(2)
		await shot("bell_warden_phase_three_exchange")
		check(absf(boss.global_position.x - boss_x_before_exchange) > 20.0, "Boss exchanges position with the inverse ghost")
		check(is_instance_valid(ghost_ref), "Inverse ghost remains as a deliberate scythe target")
		boss.set_physics_process(false)
		ghost_ref.global_position = boss.global_position + Vector2(boss.facing * 55.0, -24.0)
		boss._enter(BellWarden.State.WINDUP)
		boss._enter(BellWarden.State.STRIKE)
		check(boss.state == BellWarden.State.STAGGER and boss.staggered_by_ghost, "Scythe striking the ghost dispels it and stuns the boss")
		check(not boss.contact_box.active and not boss.attack_box.active, "Ghost backlash clears body and weapon damage during the punish window")
		boss.set_physics_process(true)
		await until_state(BellWarden.State.CHASE)
		check(boss.timer > 0.0, "Ghost backlash grants a timed recovery before the next attack")
		check(await until_state(BellWarden.State.DROP_WARNING, 720), "Final phase uses the locked falling bell shadow")
		var has_drop := false
		for pin: EchoMark in boss.phase_marks:
			if is_instance_valid(pin) and pin.pattern == "drop":
				has_drop = true
		check(has_drop, "Falling bell shadow locks an actual ground position")
		await frames(3)
		await shot("bell_warden_drop_warning")
		check(await until_state(BellWarden.State.DROP_ACTIVE), "Falling bell shadow resolves after its warning")
	game.load_room("terminal_platform", "entry")
	await frames(4)
	var crossing := EchoMark.new()
	crossing.player = game.player
	crossing.delay_seconds = 0.1
	crossing.active_seconds = 0.8
	crossing.travel_seconds = 0.8
	crossing.travel_radius = 12.0
	crossing.global_position = game.player.global_position + Vector2(-90, -21)
	crossing.travel_target = game.player.global_position + Vector2(90, -21)
	game.room.add_child(crossing)
	var crossing_hp: int = game.player.health.current
	await frames(40)
	check(game.player.health.current == crossing_hp, "Legacy moving ghost no longer applies an invisible travel hit")
	await frames(25)
	check(not is_instance_valid(crossing), "Legacy ghost releases its visual and collision after travel")
	print("BELL_WARDEN_RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
