extends "res://tests/bell_court_suite.gd"
## Chapter I stays readable; Chapter II uses spacing without shortening warnings.

func spawn_enemy(scene: PackedScene, at := Vector2(360,320)) -> CharacterBody2D:
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.position = at
	arena.add_child(enemy)
	if not enemy is Slime:
		enemy.target = player
	return enemy

func run() -> void:
	await slime_decisions()
	await armor_decisions()
	await scribe_decisions()
	await rose_decisions()
	await chest_decisions()
	await native_visuals()
	release()
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(3)
	print("CHAPTER_ENEMY_AI_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func slime_decisions() -> void:
	await fixture(Vector2(600,320))
	var slime := spawn_enemy(preload("res://features/enemies/slime.tscn")) as Slime
	await frames(3)
	slime.position.x = slime.origin_x+slime.patrol_distance+30
	var start := slime.position.x
	await frames(12)
	check(slime.position.x<start-6 and slime.direction<0,"Slime outside patrol bounds returns inward without alternating every frame")
	await fixture(Vector2(600,320))
	box(Vector2(384,280),Vector2(8,80))
	slime = spawn_enemy(preload("res://features/enemies/slime.tscn"))
	slime.direction = 1
	await frames(45)
	check(slime.position.x<350 and slime.direction<0,"Slime turns away from a wall without sticky collision or position nudges")
	await fixture(Vector2(360,320))
	slime = spawn_enemy(preload("res://features/enemies/slime.tscn"))
	slime.speed = 0 # Explicit stationary overlap fixture; continuous routes are unchanged.
	player.set_physics_process(false)
	player.steam_ward.activate()
	await frames(190)
	check(player.health.current==5 and player.steam_ward.active_left==0,"Continuous slime contact spends a ward once and cannot rearm on a timer")
	player.position.x = 450
	await frames(4)
	player.position.x = 360
	await frames(4)
	check(player.health.current==4,"Leaving and touching the slime again remains a real new contact hit")

func armor_decisions() -> void:
	await fixture(Vector2(530,320))
	var armor := spawn_enemy(preload("res://features/enemies/living_armor.tscn")) as LivingArmor
	await frames(12)
	var start := armor.position.x
	player.position.x = 950
	await frames(12)
	check(armor.state==LivingArmor.State.CHASE and armor.position.x>start+8 and not armor.attack_box.active,"Armor briefly searches the last visible position instead of instantly turning around")
	var search := armor.search_left
	get_tree().paused = true
	await frames(8)
	check(armor.search_left==search,"Pause freezes armor search memory")
	get_tree().paused = false
	await frames(40)
	check(armor.state==LivingArmor.State.PATROL and armor.facing<0,"Expired armor memory returns it toward its patrol without a blind strike")
	await fixture(Vector2(450,320))
	armor = spawn_enemy(preload("res://features/enemies/living_armor.tscn"))
	armor.home_x = 100
	await frames(25)
	check(armor.position.x<362 and armor.state==LivingArmor.State.CHASE,"Armor cannot chase a target beyond its bounded home territory")
	await fixture(Vector2(600,320))
	box(Vector2(381,280),Vector2(8,80))
	armor = spawn_enemy(preload("res://features/enemies/living_armor.tscn"))
	armor.target = null
	armor.facing = 1
	await frames(45)
	check(armor.position.x<355 and armor.facing<0,"Armor patrol can walk away from the wall it just touched")
	await fixture(Vector2(410,320))
	armor = spawn_enemy(preload("res://features/enemies/living_armor.tscn"))
	await frames(5)
	check(armor.state==LivingArmor.State.WINDUP,"Armor retains the full original first-encounter warning")
	armor.target = null
	await frames(4)
	check(armor.state==LivingArmor.State.RECOVER and not armor.attack_box.active,"Removing the player cancels an armor attack safely")

func scribe_decisions() -> void:
	await fixture(Vector2(500,320))
	var scribe := spawn_enemy(preload("res://features/enemies/doom_scribe.tscn")) as DoomScribe
	scribe.target = null
	box(Vector2(430,289),Vector2(2,2))
	await frames(3)
	scribe.target = player
	var ray := PhysicsRayQueryParameters2D.create(scribe.cast_origin(),player.position+Vector2(0,-24),1)
	check(scribe.get_world_2d().direct_space_state.intersect_ray(ray).is_empty() and not scribe.can_see_target(),"Scribe checks bolt thickness rather than firing through a center-ray-only gap")
	await frames(65)
	check(scribe.state==DoomScribe.State.IDLE and scribe.casts==0,"Scribe holds fire while its real projectile lane is obstructed")
	arena.get_child(arena.get_child_count()-1).queue_free()
	await frames(4)
	check(scribe.state==DoomScribe.State.WINDUP and scribe.timer>0.7,"Opening a firing lane starts the full warning, not an instant shot")
	await fixture(Vector2(500,320))
	hold("jump",true)
	await frames(8)
	scribe = spawn_enemy(preload("res://features/enemies/doom_scribe.tscn"))
	scribe.casts = 1 # Later-shot decision fixture.
	await frames(4)
	check(scribe.state==DoomScribe.State.IDLE and scribe.aim_wait>0,"After its teaching shot, scribe briefly waits while the target rises")
	var patience := scribe.aim_wait
	get_tree().paused = true
	await frames(6)
	check(scribe.aim_wait==patience,"Pause also freezes the scribe's aim patience")
	get_tree().paused = false
	await frames(22)
	release()
	check(scribe.state==DoomScribe.State.WINDUP and scribe.casts==1,"Scribe resumes a telegraphed shot as ascent ends without firing early")
	var locked := scribe.locked_direction
	player.position.x = 230
	await frames(4)
	check(scribe.locked_direction==locked,"Patient targeting still locks aim for the entire committed windup")

func rose_decisions() -> void:
	await fixture(Vector2(450,320))
	var knight := spawn_enemy(preload("res://features/enemies/rose_sentinel.tscn")) as RoseSentinel
	await frames(7)
	check(knight.state==RoseSentinel.State.RETREAT and knight.position.x<360,"Knight's first encounter still teaches the original retreat")
	await fixture(Vector2(450,320))
	knight = spawn_enemy(preload("res://features/enemies/rose_sentinel.tscn"))
	knight.completed_strikes = 1
	await frames(5)
	check(knight.state==RoseSentinel.State.WARNING and absf(knight.position.x-360)<1 and knight.timer>0.6,"Experienced knight already at good spacing warns without an unnecessary retreat")
	await fixture(Vector2(410,320))
	box(Vector2(344,280),Vector2(8,80))
	knight = spawn_enemy(preload("res://features/enemies/rose_sentinel.tscn"))
	await frames(5)
	check(knight.state==RoseSentinel.State.WARNING and knight.timer>0.6,"Wall behind knight causes a full stationary warning instead of futile backpedaling")
	var locked := knight.facing
	player.position.x = 300
	await frames(8)
	check(knight.facing==locked,"Even cornered knight cannot turn a committed warning into a surprise strike")
	await fixture(Vector2(500,320))
	knight = spawn_enemy(preload("res://features/enemies/rose_sentinel.tscn"))
	await frames(12)
	check(knight.position.x>370,"Knight closes a distant visible target")
	player.position.x = 950
	await frames(30)
	check(absf(knight.position.x-knight.home_x)<9 and knight.state==RoseSentinel.State.IDLE,"Knight returns to its post after losing the target")
	await fixture(Vector2(500,320))
	knight = spawn_enemy(preload("res://features/enemies/rose_sentinel.tscn"))
	knight.home_x = 100
	await frames(15)
	check(knight.position.x<362,"Knight's pursuit cannot spill beyond its home leash")

func chest_decisions() -> void:
	await fixture(Vector2(520,320))
	var chest := spawn_enemy(preload("res://features/enemies/winged_chest.tscn")) as WingedChest
	await frames(15)
	check(chest.state==WingedChest.State.APPROACH and chest.position.x>367 and not chest.attack_box.active,"Distant chest approaches into bite range instead of repeatedly pouncing short")
	var start := chest.position
	get_tree().paused = true
	await frames(8)
	check(chest.position==start,"Pause freezes the chest approach")
	get_tree().paused = false
	for tick: int in range(80):
		await frames()
		if chest.state==WingedChest.State.WARNING:
			break
	check(chest.state==WingedChest.State.WARNING and absf(player.position.x-chest.position.x)<=111 and chest.timer>0.65,"Chest starts a complete warning only once its bite is in range")
	var facing := chest.facing
	player.position.x = chest.position.x-60
	await frames(8)
	check(chest.facing==facing,"Approaching chest still locks direction before the pounce")
	await fixture(Vector2(500,320))
	arena.get_child(0).queue_free()
	box(Vector2(280,336),Vector2(200,32))
	box(Vector2(540,336),Vector2(160,32))
	chest = spawn_enemy(preload("res://features/enemies/winged_chest.tscn"))
	await frames(45)
	check(chest.position.x<365 and chest.position.y<321 and chest.state==WingedChest.State.IDLE,"Chest sees a player across a gap but refuses an unsupported approach")
	await fixture(Vector2(520,320))
	chest = spawn_enemy(preload("res://features/enemies/winged_chest.tscn"))
	await frames(20)
	player.position.x = 950
	await frames(40)
	check(chest.state==WingedChest.State.IDLE and absf(chest.position.x-chest.home_x)<9,"Chest returns home after the player leaves detection")
	await fixture(Vector2(520,320))
	chest = spawn_enemy(preload("res://features/enemies/winged_chest.tscn"))
	chest.home_x = 140
	await frames(12)
	check(chest.position.x<362,"Chest approach respects its home leash")

func native_visuals() -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	release()
	arena.queue_free()
	await frames(2)
	game = preload("res://app/main.tscn").instantiate()
	add_child(game)
	await frames(4)
	game.start_game(false)
	player = game.player
	game.load_room("training","entry")
	player.revive(Vector2(660,480))
	await frames(10)
	var armor := game.room.get_node("Enemies/ArmorSolo") as LivingArmor
	player.position.x = 820
	await frames(10)
	check(armor.state==LivingArmor.State.CHASE,"Native training room retains the armor's short pursuit memory")
	game.set_process(false) # Frame both actors after explicit test-only placement.
	game.camera.position = Vector2((armor.position.x+player.position.x)*0.5,415)
	game.camera.reset_smoothing()
	await shot("chapter_ai_armor_search")
	game.set_process(true)
	game.load_room("valve_gallery","entry")
	player.revive(Vector2(840,352))
	await frames(14)
	var chest := game.room.get_node("Enemies/WingedChest") as WingedChest
	check(chest.state==WingedChest.State.APPROACH,"Native gallery chest moves into a useful bite distance")
	await shot("chapter_ai_chest_approach")
	game.load_room("cistern_archive","entry")
	player.revive(Vector2(570,480))
	var knight := game.room.get_node("Enemies/RoseSentinel") as RoseSentinel
	knight.completed_strikes = 1
	await frames(5)
	check(knight.state==RoseSentinel.State.WARNING,"Native archive shows knight warning from existing spacing")
	game.set_process(false)
	game.camera.position = Vector2((knight.position.x+player.position.x)*0.5,415)
	game.camera.reset_smoothing()
	await shot("chapter_ai_knight_spacing")
	game.set_process(true)
