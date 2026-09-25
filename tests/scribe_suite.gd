extends Node
## Real scene/physics regressions; repositioning isolates each mechanic.
const BOLT := preload("res://features/combat/ink_bolt.tscn")
const SCRIBE := preload("res://features/enemies/doom_scribe.tscn")
const Repository := preload("res://core/save_repository.gd")

func bolt(room: GameRoom, at: Vector2, direction := Vector2.LEFT, speed := 190.0, lifetime := 3.2) -> InkBolt:
	var instance := BOLT.instantiate() as InkBolt
	instance.config = (load("res://features/enemies/scribe_config.tres") as ScribeConfig).duplicate() as ScribeConfig
	instance.config.bolt_speed = speed
	instance.config.bolt_lifetime = lifetime
	instance.direction = direction
	instance.position = at
	room.projectiles.add_child(instance)
	return instance

func wall(room: GameRoom, at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2,100)
	shape.shape = rect
	body.add_child(shape)
	room.add_child(body)
	body.position = at
	return body

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	# The new door has a distinct, reachable interaction area, and respects the seal.
	game.load_room("training","scribe_return")
	Session.flags.erase("training_cleared")
	player.revive(Vector2(1035,480))
	player.health.invulnerability_left = 5
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "training", "Ink Sanctum door requires the training seal")
	Session.set_flag("training_cleared")
	await h.press("interact",2)
	h.check(game.room.room_id == "scriptorium", "Training branch door enters Ink Sanctum")
	player.revive(Vector2(48,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "training", "Uncleared Sanctum allows returning through its west door")
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "scriptorium", "Sanctum return spawn permits entering again without an interaction loop")
	player.revive(Vector2(110,480))
	game.ui.toast.text = ""
	await h.frames(10)
	var scribe: DoomScribe = game.room.get_node("Enemies/ScribeSolo")
	h.check(game.room.get_node("Enemies").get_child_count() == 3, "Sanctum contains solo caster and mixed melee/ranged encounter")
	h.check(scribe.state == DoomScribe.State.IDLE and game.room.projectiles.get_child_count() == 0, "Sanctum entrance is outside caster aggro")
	await h.shot("14_sanctum_entry")
	player.revive(Vector2(245,480))
	await h.frames(4)
	h.check(game.ui.prompt.text.contains("Violet charge"), "Ranged lesson explains jumping and cover")
	await h.shot("15_ink_lesson")
	# Prove first 64px cover is reachable with normal jump only.
	var abilities := Session.abilities.duplicate()
	Session.abilities.clear()
	player.revive(Vector2(275,480))
	await h.frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	await h.frames(23)
	Input.action_release("move_right")
	Input.action_release("jump")
	await h.frames(25)
	h.check(player.is_on_floor() and absf(player.position.y-416)<2, "Normal jump reaches the new 64px cover block")
	Session.abilities.assign(abilities)
	Session.progress_changed.emit()
	# Reset the room to discard a cast started during traversal.
	game.load_room("scriptorium","entry")
	scribe = game.room.get_node("Enemies/ScribeSolo")
	player.revive(Vector2(450,480))
	await h.frames(4)
	h.check(scribe.state == DoomScribe.State.WINDUP and scribe.casts == 0, "Caster telegraphs before emitting a projectile")
	h.check(player.health.current == 5, "Caster windup deals no contact damage")
	var aim := scribe.locked_direction
	game.camera.position = player.position + Vector2(45,-65)
	game.camera.reset_smoothing()
	await h.shot("16_scribe_warning")
	# Jump after the aim has locked; the shot must fly through the old position.
	await h.frames(32)
	Input.action_press("jump")
	await h.frames(14)
	h.check(scribe.locked_direction == aim and scribe.casts == 1, "Caster locks aim and emits only one bolt per cast")
	await h.frames(9)
	await h.shot("17_ink_dodge")
	await h.frames(14)
	Input.action_release("jump")
	h.check(player.health.current == 5, "A real jump dodges the non-homing projectile")
	h.check(scribe.state == DoomScribe.State.RECOVER and scribe.casts == 1, "Caster recovery leaves a safe approach window")
	await h.frames(20)
	# Sword interruption prevents the queued cast and leaves a longer recovery.
	game.load_room("scriptorium","entry")
	scribe = game.room.get_node("Enemies/ScribeSolo")
	player.revive(Vector2(565,480))
	player.facing = 1
	await h.frames(4)
	await h.press("attack",10)
	h.check(scribe.health.current == 1 and scribe.state == DoomScribe.State.HURT, "Sword interrupts the caster during windup")
	await h.frames(45)
	h.check(scribe.casts == 0 and game.room.projectiles.get_child_count() == 0, "Interrupted cast never produces a delayed projectile")
	# Wall blocks caster sight. Hide the player behind the authored first cover.
	game.load_room("scriptorium","entry")
	scribe = game.room.get_node("Enemies/ScribeSolo")
	player.revive(Vector2(315,480))
	await h.frames(65)
	h.check(not scribe.can_see_target() and scribe.casts == 0, "Authored solid cover blocks caster sight")
	player.revive(Vector2(775,480))
	await h.frames(65)
	h.check(player.health.current == 5 and game.room.projectiles.get_child_count() == 0, "Middle checkpoint is protected by cover from both encounters")
	# Isolated real projectile collisions on the first open firing lane.
	for enemy: Node in game.room.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	game.room.clear_projectiles()
	player.revive(Vector2(450,480))
	await h.frames(3)
	var shot := bolt(game.room,Vector2(550,456))
	await h.frames(40)
	h.check(player.health.current == 4 and not is_instance_valid(shot), "Projectile damages once and is released on player contact")
	player.revive(Vector2(450,480))
	player.health.invulnerability_left = 2
	shot = bolt(game.room,Vector2(450,456))
	await h.frames(3)
	h.check(player.health.current == 5 and not is_instance_valid(shot), "Projectile starting inside an invulnerable target is consumed safely")
	player.revive(Vector2(450,480))
	var cover := wall(game.room,Vector2(500,440))
	await h.frames(3)
	shot = bolt(game.room,Vector2(560,456),Vector2.LEFT,12000)
	await h.frames(3)
	h.check(player.health.current == 5 and not is_instance_valid(shot), "Swept fast projectile cannot tunnel through a two-pixel wall")
	cover.queue_free()
	await h.frames(2)
	# Nearest collision must win even if a wall lies further behind the player.
	cover = wall(game.room,Vector2(410,440))
	await h.frames(3)
	shot = bolt(game.room,Vector2(560,456),Vector2.LEFT,12000)
	await h.frames(3)
	h.check(player.health.current == 4 and not is_instance_valid(shot), "Projectile resolves target before a wall farther along its path")
	cover.queue_free()
	await h.frames(2)
	player.revive(Vector2(450,480))
	shot = bolt(game.room,Vector2(550,456),Vector2.LEFT,1000)
	game.get_tree().paused = true
	var paused_at := shot.position
	await h.frames(10)
	h.check(shot.position == paused_at and shot.age == 0 and player.health.current == 5, "Pause freezes projectile motion and lifetime")
	game.resume()
	await h.frames(10)
	h.check(player.health.current == 4 and not is_instance_valid(shot), "Projectile resumes collision normally after pause")
	shot = bolt(game.room,Vector2(500,300),Vector2.UP,20,0.08)
	await h.frames(8)
	h.check(not is_instance_valid(shot), "Missed projectile expires by lifetime")
	# Death while preparing prevents a shot; death after release cancels owned shots.
	game.load_room("scriptorium","entry")
	scribe = game.room.get_node("Enemies/ScribeSolo")
	player.revive(Vector2(450,480))
	await h.frames(4)
	scribe.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(not is_instance_valid(scribe) and game.room.projectiles.get_child_count() == 0, "Caster death during windup cannot fire later")
	game.load_room("scriptorium","entry")
	scribe = game.room.get_node("Enemies/ScribeSolo")
	player.revive(Vector2(450,480))
	await h.frames(51)
	h.check(game.room.projectiles.get_child_count() == 1, "Live caster produces a room-owned projectile")
	scribe.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(game.room.projectiles.get_child_count() == 0 and player.health.current == 5, "Caster death cancels its existing projectile")
	shot = bolt(game.room,Vector2(500,300))
	game.load_room("forest","entry")
	await h.frames(3)
	h.check(not is_instance_valid(shot) and game.room.projectiles.get_child_count() == 0, "Room transition destroys old projectile instances")
	# Room progression and death checkpoint use actual interactions.
	game.load_room("scriptorium","rest")
	player.revive(Vector2(775,480))
	await h.frames(4)
	await h.press("interact",2)
	h.check(Session.checkpoint_room == "scriptorium" and Session.checkpoint_spawn == "rest", "Sanctum middle checkpoint commits its stable spawn")
	shot = bolt(game.room,Vector2(780,300))
	player.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(not is_instance_valid(shot), "Player death immediately clears room projectiles")
	await h.frames(64)
	h.check(game.room.room_id == "scriptorium" and absf(player.position.x-775)<2 and player.health.current == 5, "Sanctum death returns to a safe exact checkpoint")
	player.revive(Vector2(1540,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "scriptorium", "Sanctum return route remains sealed before clearing")
	player.revive(Vector2(1470,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check("scriptorium_cleared" not in Session.flags, "Living enemies prevent claiming the ink seal")
	player.revive(Vector2(1190,480))
	player.health.invulnerability_left = 5
	game.camera.position = player.position + Vector2(45,-65)
	game.camera.reset_smoothing()
	await h.frames(5)
	await h.shot("19_mixed_encounter")
	# Real sword hits for all enemies; harness invulnerability isolates attack output.
	for enemy: Node in game.room.get_node("Enemies").get_children():
		var health := enemy.get_node("Health") as HealthComponent
		for attempt: int in range(8):
			if not is_instance_valid(enemy) or health.current <= 0:
				break
			player.revive(enemy.position - Vector2(44,0))
			player.health.invulnerability_left = 5
			player.facing = 1
			await h.frames(3)
			await h.press("attack",24)
	await h.frames(60)
	h.check(game.room.is_cleared() and game.room.projectiles.get_child_count() == 0, "Sword combat clears mixed melee/ranged encounter without lingering bolts")
	player.revive(Vector2(1470,480))
	await h.frames(4)
	await h.press("interact",2)
	h.check("scriptorium_cleared" in Session.flags and not game.room.get_node("Interactions/Seal").visible, "Ink seal persists and cannot be claimed twice")
	await h.shot("18_ink_clear")
	player.revive(Vector2(1540,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "ruins", "Cleared Sanctum exit returns to the archive")
	h.check(Session.restore() and "scriptorium_cleared" in Session.flags and Session.checkpoint_room == "scriptorium", "Sanctum progress and checkpoint survive save restore")
	var old_v2 := {"version":2,"checkpoint_room":"training","checkpoint_spawn":"rest","abilities":["double_jump"],"visited":["forest","ruins","training"],"completed":true,"flags":["training_cleared"]}
	h.check(Repository.validate(old_v2) and Repository.migrate(old_v2) == old_v2, "Existing version 2 saves remain valid without data changes")
	game.load_room("scriptorium","rest")
	await h.frames(4)
	h.check(not game.room.get_node("Interactions/Seal").visible, "Revisiting cleared Sanctum retains reward state while enemies respawn")
	game.load_room("ruins","checkpoint")
	player.revive(Vector2(160,480))
	await h.frames(3)
