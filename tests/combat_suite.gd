extends Node
## Extended regressions reuse the real app and harness; no production test flags.
const Repository := preload("res://core/save_repository.gd")

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	var original_abilities := Session.abilities.duplicate()
	var settings_path := Session.settings_path
	var original_shake := Session.reduce_shake
	var original_flashes := Session.reduce_flashes
	Session.settings_path = "user://test_settings_%s.cfg" % OS.get_process_id()
	Session.reduce_shake = false
	Session.reduce_flashes = false
	game.load_room("forest","entry")
	Session.abilities.clear()
	player.revive(Vector2(175,480))
	await h.frames(4)
	# No target: preparation and recovery never enable damage or emit impact.
	var effects: Node = game.get_node("Feedback")
	var before: int = effects.impacts
	Input.action_press("attack")
	await h.frames(2)
	h.check(player.attack_phase == AttackProfile.Phase.WINDUP and not player.attack_box.active, "Sword preparation cannot deal damage")
	await h.frames(5)
	h.check(player.attack_phase == AttackProfile.Phase.ACTIVE and player.attack_box.active, "Sword active phase enables damage")
	h.check(player.sprite.frame >= 1 and player.sprite.frame <= 3, "Active sword pose follows damage phase")
	await h.shot("06_sword_active")
	await h.frames(8)
	h.check(player.attack_phase == AttackProfile.Phase.RECOVERY and not player.attack_box.active, "Sword recovery cannot deal damage")
	Input.action_release("attack")
	await h.frames(15)
	h.check(effects.impacts == before, "Whiff does not emit hit feedback")
	Input.action_press("attack")
	await h.frames(7)
	player.health.take_damage(1,Vector2(100,480))
	h.check(not player.attack_box.active and player.state == Player.State.HURT, "Hurt immediately cancels active swing")
	Input.action_release("attack")
	await h.frames(30)
	player.revive(Vector2(175,480))
	await h.frames(3)
	# Pause consumes queued actions; held jump/attack cannot leak on resume.
	game.get_tree().paused = true
	player.reset_input()
	Input.action_press("jump")
	Input.action_press("attack")
	await h.frames(3)
	game.resume()
	await h.frames(3)
	h.check(player.is_on_floor() and player.state == Player.State.MOVE, "Held menu input does not jump or attack on resume")
	Input.action_release("jump")
	Input.action_release("attack")
	await h.frames(2)
	# Coyote test walks beyond a real ledge, then presses jump while airborne.
	player.revive(Vector2(467,384))
	await h.frames(3)
	Input.action_press("move_right")
	for i: int in range(20):
		await h.frames(1)
		if not player.is_on_floor():
			break
	Input.action_release("move_right")
	await h.frames(2)
	Input.action_press("jump")
	await h.frames(1)
	h.check(player.velocity.y < -400, "Coyote jump works after leaving actual platform")
	Input.action_release("jump")
	await h.frames(40)
	# Buffered input just before impact fires on the first grounded tick.
	player.revive(Vector2(175,468))
	player.velocity.y = 180
	await h.frames(1)
	Input.action_press("jump")
	await h.frames(7)
	h.check(player.velocity.y < -350, "Early jump buffer fires after landing")
	Input.action_release("jump")
	await h.frames(45)
	# Enter via the actual new door.
	Session.abilities.assign(original_abilities)
	Session.progress_changed.emit()
	game.load_room("ruins","training_return")
	player.revive(Vector2(1215,480))
	await h.frames(4)
	await h.press("interact",2)
	h.check(game.room.room_id == "training", "Archive door opens training branch")
	await h.frames(4)
	h.check(game.room.get_node("Enemies").get_child_count() == 3, "Training room contains solo and mixed encounters")
	await h.shot("07_training_entry")
	player.revive(Vector2(220,416))
	await h.frames(5)
	h.check(player.is_on_floor() and not (game.room.get_node("Enemies/ArmorSolo") as LivingArmor).can_see_target(), "Observation ledge provides a safe teaching position")
	h.check(game.ui.prompt.text.contains("amber warning"), "Observation sign displays combat instruction")
	await h.shot("12_observation")
	player.revive(Vector2(1215,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "training", "Shortcut stays locked before reward")
	player.revive(Vector2(1125,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check("training_cleared" not in Session.flags, "Living guardians prevent claiming seal")
	var armor: LivingArmor = game.room.get_node("Enemies/ArmorSolo")
	# Deterministic positioning isolates telegraph and direction lock.
	armor.position = Vector2(500,480)
	player.revive(Vector2(450,480))
	await h.frames(4)
	h.check(armor.state == LivingArmor.State.WINDUP and not armor.attack_box.active, "Armor telegraphs before attack")
	h.check(player.health.current == 5, "Standing in windup range remains harmless")
	var locked_facing := armor.facing
	game.camera.position = player.position + Vector2(45,-65)
	game.camera.reset_smoothing()
	await h.shot("08_armor_warning")
	player.position.x = 545
	await h.frames(34)
	h.check(armor.facing == locked_facing, "Armor does not turn during committed attack")
	h.check(player.health.current == 5, "Moving behind telegraph safely avoids attack")
	for i: int in range(25):
		await h.frames(1)
		if armor.state == LivingArmor.State.RECOVER:
			break
	h.check(armor.state == LivingArmor.State.RECOVER and not armor.attack_box.active, "Armor exposes a harmless recovery window")
	player.position = Vector2(545,480)
	player.facing = -1
	Input.action_press("attack")
	await h.frames(7)
	Input.action_release("attack")
	h.check(armor.health.current == 2 and armor.state == LivingArmor.State.HURT, "Player counterattack interrupts armor recovery")
	await h.shot("09_counterattack")
	await h.frames(30)
	h.check(effects.get_child_count() == 0 and game.camera.offset.length() < 0.01, "Hit particles expire and camera settles")
	# Real wall blocks perception and attacks.
	armor.position = Vector2(500,480)
	player.revive(Vector2(450,480))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,120)
	shape.shape = rectangle
	wall.add_child(shape)
	game.room.add_child(wall)
	wall.position = Vector2(475,425)
	await h.frames(3)
	h.check(not armor.can_see_target(), "Solid wall blocks armor sight")
	var hp := armor.health.current
	player.facing = 1
	await h.press("attack",15)
	h.check(armor.health.current == hp, "Sword cannot damage through wall")
	wall.queue_free()
	await h.frames(3)
	# Kill in the middle of a swing: no lingering collision damage.
	armor.position = Vector2(500,480)
	player.revive(Vector2(450,480))
	for i: int in range(130):
		await h.frames(1)
		if armor.state == LivingArmor.State.STRIKE:
			break
	h.check(armor.state == LivingArmor.State.STRIKE, "Armor reaches active strike through its state machine")
	await h.frames(3)
	h.check(player.health.current == 4, "Armor active frames damage a target in front exactly once")
	await h.shot("13_armor_strike")
	armor.health.invulnerability_left = 0
	armor.health.take_damage(99,player.position)
	h.check(armor.state == LivingArmor.State.DEAD and not armor.attack_box.active, "Armor death cancels its attack immediately")
	var remaining_hp := player.health.current
	await h.frames(40)
	h.check(not is_instance_valid(armor) and player.health.current == remaining_hp, "Dead armor releases safely without ghost damage")
	# Isolate patrol geometry from target perception using a real elevated ledge.
	var ledge := StaticBody2D.new()
	var ledge_shape := CollisionShape2D.new()
	var ledge_rect := RectangleShape2D.new()
	ledge_rect.size = Vector2(120,16)
	ledge_shape.shape = ledge_rect
	ledge.add_child(ledge_shape)
	game.room.add_child(ledge)
	ledge.position = Vector2(650,348)
	var probe := preload("res://features/enemies/living_armor.tscn").instantiate() as LivingArmor
	probe.position = Vector2(692,340)
	game.room.add_child(probe)
	probe.facing = 1
	await h.frames(30)
	h.check(probe.is_on_floor() and probe.position.y < 342 and probe.facing < 0, "Armor patrol turns before walking off a platform")
	probe.queue_free()
	ledge.queue_free()
	await h.frames(2)
	# Finish the remaining mixed encounter with player attacks, allowing safe health for harness.
	for enemy: Node in game.room.get_node("Enemies").get_children():
		var target_health := enemy.get_node("Health") as HealthComponent
		for attempt: int in range(8):
			if not is_instance_valid(enemy) or target_health.current <= 0:
				break
			player.revive(enemy.position - Vector2(44,0))
			player.health.invulnerability_left = 5
			player.facing = 1
			await h.frames(3)
			await h.press("attack",24)
	await h.frames(45)
	h.check(game.room.is_cleared(), "Real sword hits clear the mixed encounter")
	player.revive(Vector2(710,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.checkpoint_room == "training" and Session.checkpoint_spawn == "rest", "Training checkpoint saves room and exact spawn ID")
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "training" and player.health.current == 5, "Death returns safely to training checkpoint")
	h.check(absf(player.position.x - 710) < 2, "Death restores the selected middle checkpoint position")
	# Death resets encounters by design; clear for persistence/reward checks.
	for enemy: Node in game.room.get_node("Enemies").get_children():
		(enemy.get_node("Health") as HealthComponent).take_damage(99,player.position)
	await h.frames(40)
	player.revive(Vector2(1125,480))
	await h.frames(4)
	await h.press("interact",2)
	h.check("training_cleared" in Session.flags, "Clear reward persists shortcut flag")
	await h.shot("10_hall_cleared")
	player.revive(Vector2(1215,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "forest", "Unlocked shortcut returns to forest")
	h.check(Session.restore() and "training_cleared" in Session.flags, "Shortcut survives save restore")
	var legacy := {"version":1,"checkpoint_room":"ruins","checkpoint_spawn":"checkpoint","abilities":["double_jump"],"visited":["forest","ruins"],"completed":true}
	var migrated: Variant = Repository.migrate(legacy)
	h.check(Repository.validate(migrated) and migrated.completed and migrated.abilities == legacy.abilities and migrated.flags.is_empty(), "Version 1 migration preserves original progress")
	var invalid_spawn: Dictionary = migrated.duplicate(true)
	invalid_spawn.checkpoint_spawn = "rest"
	h.check(not Repository.validate(invalid_spawn), "Checkpoint IDs are validated against their own room")
	var path := Session.save_path + ".legacy"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	h.check(Repository.read(path).get("version") == 2, "Legacy file migrates through real repository read")
	DirAccess.remove_absolute(path)
	Session.reduce_shake = true
	Session.reduce_flashes = true
	h.check(Session.save_settings() == OK, "Accessibility settings save")
	Session.reduce_shake = false
	Session.reduce_flashes = false
	Session.load_settings()
	h.check(Session.reduce_shake and Session.reduce_flashes, "Accessibility settings restore")
	effects.show_impact(player.position,false)
	await h.frames(3)
	h.check(game.camera.offset == Vector2.ZERO, "Reduced shake setting suppresses camera offset")
	game.get_tree().paused = true
	game.ui.show_menu("pause")
	await h.shot("11_accessibility")
	game.resume()
	Session.settings_path = settings_path
	Session.reduce_shake = original_shake
	Session.reduce_flashes = original_flashes
	DirAccess.remove_absolute("user://test_settings_%s.cfg" % OS.get_process_id())
	await h.frames(20)
