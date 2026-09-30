extends Node
## Real physics and sword hits. Positioning/invulnerability isolate attack and persistence rules.

func wait_state(h: Node, boss: HollowWarden, desired: HollowWarden.State, limit := 240) -> bool:
	for index: int in range(limit):
		if not is_instance_valid(boss):
			return false
		if boss.state == desired:
			return true
		await h.frames(1)
	return false

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	Session.flags.erase("warden_defeated")
	Session.flags.erase("journey_restored")
	Session.set_language("zh_CN")
	game.load_room("atrium","boss_return")
	player.revive(Vector2(816,352))
	await h.frames(3)
	player.health.take_damage(1,player.position)
	var entry_health := player.health.current
	await h.press("interact",2)
	await h.frames(5)
	h.check(game.room.room_id == "heart_chamber" and Session.checkpoint_room == "atrium" and player.health.current == entry_health, "Arena entrance saves an antechamber retry checkpoint without healing")
	var boss := game.room.get_node("Enemies/Warden") as HollowWarden
	h.check(game.room.get_node("ArenaGate").closed and game.room.nearby_exit_target().is_empty() and not game.room.get_node("Interactions/Return").visible and not game.room.get_node("Interactions/ChapterDoor").visible, "Warden room hides both exits until victory")
	h.check(game.camera.position == Vector2(320,396), "Warden camera starts at its fixed combat position")
	Input.action_press("move_left")
	await h.frames(24)
	Input.action_release("move_left")
	h.check(player.position.x >= 80 and game.room.room_id == "heart_chamber", "Player cannot move out of the fixed warden chamber before combat")
	player.revive(Vector2(96,480))
	h.check(boss.state == HollowWarden.State.DORMANT and not game.ui.boss_panel.visible, "Arena entry is safe before crossing the activation line")
	boss.set_physics_process(false)
	var stationary_boss_position := boss.position
	player.revive(Vector2(380,480))
	Input.action_press("move_right")
	await h.frames(32)
	Input.action_release("move_right")
	h.check(player.position.x > boss.position.x + 18.0 and boss.position == stationary_boss_position, "Player crosses the stationary warden without physically pushing it")
	player.revive(Vector2(380,480))
	boss.set_physics_process(true)
	await h.frames(2)
	h.check(not game.room.get_node("Interactions/FinalEcho").visible, "Final echo remains hidden while the warden lives")
	game._on_interaction(game.room.get_node("Interactions/FinalEcho"))
	h.check("journey_restored" not in Session.flags, "Final echo cannot be claimed before boss defeat")
	var idle_frame := boss.sprite.frame
	await h.frames(7)
	var idle_advanced := boss.sprite.frame != idle_frame
	await h.frames(23)
	h.check(boss.sprite.animation == "idle" and boss.sprite.is_playing() and idle_advanced, "Idle clip advances across time instead of freezing on a recovery pose")
	var opaque_frames := true
	for clip: StringName in boss.sprite.sprite_frames.get_animation_names():
		for index: int in range(boss.sprite.sprite_frames.get_frame_count(clip)):
			var texture := boss.sprite.sprite_frames.get_frame_texture(clip,index) as AtlasTexture
			opaque_frames = opaque_frames and not texture.atlas.get_image().get_region(Rect2i(texture.region)).is_invisible()
	h.check(opaque_frames, "Every boss animation frame contains visible artwork including the complete death sequence")
	await h.shot("46_warden_entry")
	player.revive(Vector2(380,480))
	await h.frames(2)
	h.check(boss.state == HollowWarden.State.INTRO and game.ui.boss_panel.visible and game.ui.boss_bar.value == boss.config.maximum_health, "Crossing the arena starts a harmless introduction and full boss bar")
	var arena_gate := game.room.get_node("ArenaGate") as FurnaceArenaGate
	h.check(arena_gate.closed and not arena_gate.get_node("Shape").disabled, "Warden awakening seals the left entrance")
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Warden reaches a natural sweep windup")
	player.revive(boss.position+Vector2(20,0))
	player.health.invulnerability_left = 0
	var contact_hp := player.health.current
	await h.frames(5)
	h.check(player.health.current == contact_hp-1, "Touching the warden body deals contact damage")
	var warning_texture := boss.sprite.sprite_frames.get_frame_texture("windup",0) as AtlasTexture
	h.check(boss.sprite.animation == "windup" and warning_texture.region == Rect2(0,0,160,111) and warning_texture.atlas.resource_path.ends_with("warden_attack1.png"), "King warning starts on its raised-sword preparation, not the armor sheet")
	var hp := player.health.current
	var direction := boss.facing
	await h.frames(20)
	h.check(player.health.current == hp and not boss.attack_box.active, "Sweep warning cannot damage a nearby grounded player")
	player.revive(boss.position+Vector2(60,0))
	await h.frames(3)
	h.check(boss.facing == direction, "Sweep never turns toward a player crossing behind during warning")
	await h.shot("47_warden_sweep_warning")
	player.revive(boss.position+Vector2(direction*60,0))
	player.health.invulnerability_left = 0
	hp = player.health.current
	await h.frames(3)
	h.check(await wait_state(h,boss,HollowWarden.State.STRIKE), "Sweep warning transitions into a real active hitbox")
	var strike_texture := boss.sprite.sprite_frames.get_frame_texture("strike",0) as AtlasTexture
	h.check(boss.sprite.animation == "strike" and strike_texture.region == Rect2(320,0,160,111), "Active damage uses the king's visible sword arc rather than windup frames")
	await h.shot("56_warden_sweep_active")
	await h.frames(8)
	h.check(player.health.current == hp-1, "Standing in the sweep takes exactly one point of damage")
	await h.frames(8)
	h.check(not boss.attack_box.active and player.health.current == hp-1, "Sweep recovery disables damage without a repeated hit")
	var recovery_duration := boss.sprite.sprite_frames.get_frame_count("recover")/(boss.sprite.sprite_frames.get_animation_speed("recover")*boss.sprite.speed_scale)
	h.check(boss.sprite.animation == "recover" and absf(recovery_duration-boss.config.sweep.recovery)<0.001, "Recovery animation lasts for the configured punish window")
	# Rush starts after recovery and locks the current direction.
	player.revive(boss.position+Vector2(-80,0))
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Second natural attack begins after its recovery")
	h.check(boss.rush_attack and boss.timer > 0.7, "Second attack keeps a readable rush warning")
	h.check(boss.sprite.animation == "rush_windup" and boss.sprite.flip_h == (boss.facing < 0), "King rush uses its own attack strip with correct left-facing artwork")
	await h.frames(37)
	await h.shot("55_warden_rush_warning")
	await h.frames(4)
	Input.action_press("jump")
	await h.frames(13)
	await h.shot("48_warden_rush_jump")
	await h.frames(36)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum, "Actual normal jump clears the warned rush without invulnerability")
	h.check(boss.state == HollowWarden.State.RECOVER and not boss.attack_box.active, "Rush ends in a harmless punish window")
	# Damage does not interrupt recovery or gate the sword court by health.
	boss.health.take_damage(6,player.position)
	h.check(boss.state == HollowWarden.State.RECOVER and not boss.attack_box.active, "Half health does not cancel an existing recovery window")
	h.check(game.ui.boss_title.text == "空谷守门者", "Boss HUD shows its name without a numbered phase")
	var time_left := boss.timer
	get_tree().paused = true
	game.ui.show_menu("pause")
	await h.frames(10)
	h.check(boss.timer == time_left, "Pause freezes the boss state timer")
	game.resume()
	await h.frames(2)
	await h.shot("49_warden_recovery")
	# The opening sequence introduces the grounded sword court; detailed projectile checks
	# live in sword_court_suite, not the old charged-melee fixture.
	boss.position = Vector2(400,480)
	player.revive(Vector2(150,480))
	h.check(await wait_state(h,boss,HollowWarden.State.SWORD_COURT), "Opening attack loop introduces the seven-sword summon")
	h.check(boss.attack == HollowWarden.Attack.CHARGED and is_instance_valid(boss.sword_court) and not boss.charged_box.active, "Sword court replaces the old ground scar without invisible melee damage")
	await h.frames(65)
	await h.shot("58_warden_sword_court")
	# Damage isolation here preserves this older suite's later wall fixtures.
	player.health.invulnerability_left = 12
	h.check(await wait_state(h,boss,HollowWarden.State.CHASE,90) and is_instance_valid(boss.sword_court), "Charge immediately returns the king to pursuit while swords remain")
	boss.clear_court() # Keep the legacy thin-wall fixture exclusively melee.
	# Dedicated thin wall isolates rush motion and the shared occluded-hit rule.
	boss.position = Vector2(550,480)
	player.revive(Vector2(620,480))
	var wall := StaticBody2D.new()
	wall.position = Vector2(585,400)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2,160)
	collision.shape = shape
	wall.add_child(collision)
	game.room.add_child(wall)
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Boss continues into its sweep warning")
	h.check(boss.attack == HollowWarden.Attack.SWEEP, "Charged attack does not replace the basic sweep")
	await wait_state(h,boss,HollowWarden.State.RECOVER)
	await wait_state(h,boss,HollowWarden.State.WINDUP)
	h.check(boss.rush_attack and boss.timer > 0.7, "Rush retains its configured warning duration")
	await wait_state(h,boss,HollowWarden.State.STRIKE)
	await h.shot("57_warden_right_strike")
	await h.frames(12)
	h.check(boss.position.x <= 568.1 and boss.state == HollowWarden.State.RECOVER and not boss.attack_box.active, "Rush stops at a two-pixel wall and immediately enters recovery")
	h.check(player.health.current == player.health.maximum, "Boss attacks cannot damage through a world wall")
	h.check(boss.config.sweep.recovery == 0.5, "Attack loop never mutates shared attack resources")
	wall.queue_free()
	await h.frames(2)
	player.revive(Vector2(220,480))
	Input.action_press("move_left")
	await h.frames(20)
	Input.action_release("move_left")
	h.check(player.position.x >= arena_gate.position.x+15 and game.room.room_id == "heart_chamber" and boss.state != HollowWarden.State.DORMANT, "Leftward movement cannot escape an active warden fight")
	game.load_room("heart_chamber","entry")
	boss = game.room.get_node("Enemies/Warden") as HollowWarden
	h.check(boss.health.current == boss.config.maximum_health and boss.attack_count == 0, "Reloading an unfinished fight resets health and attack history")
	player.revive(Vector2(380,480))
	await h.frames(3)
	h.check(await wait_state(h,boss,HollowWarden.State.STRIKE), "Retry encounter starts attacks normally")
	player.health.invulnerability_left = 0
	player.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(not boss.attack_box.active and not game.ui.boss_panel.visible, "Player death immediately shuts down boss damage and HUD")
	await h.frames(65)
	h.check(game.room.room_id == "atrium" and absf(player.position.x-240)<2 and player.health.current == player.health.maximum, "Boss death retry returns to the safe antechamber shrine")
	player.revive(Vector2(816,352))
	await h.frames(3)
	await h.press("interact",2)
	boss = game.room.get_node("Enemies/Warden") as HollowWarden
	game.load_room("atrium","checkpoint")
	boss.health.take_damage(99,player.position)
	await h.frames(3)
	h.check("warden_defeated" not in Session.flags, "A deferred defeat from a discarded room cannot award victory")
	player.revive(Vector2(816,352))
	await h.frames(3)
	await h.press("interact",2)
	boss = game.room.get_node("Enemies/Warden") as HollowWarden
	boss.health.take_damage(99,player.position)
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "atrium" and "warden_defeated" not in Session.flags, "Simultaneous defeat returns to checkpoint without a stale victory")
	# Complete with real sword strikes; temporary immunity isolates outgoing combat.
	player.revive(Vector2(816,352))
	await h.frames(3)
	await h.press("interact",2)
	boss = game.room.get_node("Enemies/Warden") as HollowWarden
	for attempt: int in range(22):
		if not is_instance_valid(boss) or boss.health.current <= 0:
			break
		var side := -boss.facing
		player.revive(boss.position+Vector2(side*43,0))
		player.facing = -side
		player.health.invulnerability_left = 10
		await h.frames(3)
		await h.press("attack",24)
	await h.frames(3)
	h.check("warden_defeated" in Session.flags and game.room.is_cleared(), "Real sword strikes defeat the warden and set its unique persistent mark")
	h.check(not game.ui.boss_panel.visible and game.ui.reward_notice.save_succeeded and player.health.current == player.health.maximum, "Boss defeat hides bar heals and confirms successful save")
	h.check(Session.restore() and "warden_defeated" in Session.flags, "Boss victory survives a saved-state restore")
	h.check(is_instance_valid(boss) and boss.sprite.animation == "death" and not boss.sprite.sprite_frames.get_frame_texture("death",boss.sprite.frame).get_image().is_invisible(), "A defeated boss visibly collapses before its scene is released")
	await h.shot("50_warden_defeated")
	await h.frames(50)
	h.check(game.room.get_node("Enemies").get_child_count() == 0, "Defeated boss releases its scene after the death animation")
	game.load_room("heart_chamber","entry")
	await h.frames(4)
	h.check(game.room.get_node("Enemies").get_child_count() == 0 and game.room.get_node("Interactions/Return").visible and game.room.get_node("Interactions/ChapterDoor").visible and game.room.get_node("Interactions/ChapterDoor").position.x == 560, "Revisiting a defeated boss reveals the left return door and right Chapter II door")
	var camera_at: Vector2 = game.camera.position
	await h.press("jump",20)
	h.check(game.camera.position == camera_at, "Arena camera remains fixed while the player jumps")
	await h.frames(35)
	player.revive(Vector2(560,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check("journey_restored" in Session.flags and get_tree().paused and game.ui.menu_mode == "finale", "Final echo opens a distinct paused ending after boss victory")
	h.check(game.ui.finale_saved and game.ui.menu.get_child(0).text == "空谷复苏", "Ending accurately confirms its save in Chinese")
	await h.shot("51_finale_chinese")
	(game.ui.menu.get_node("LanguageButton") as Button).pressed.emit()
	await h.frames(3)
	h.check(get_tree().paused and game.ui.menu.get_child(0).text == "HOLLOW RESTORED", "Ending language switch preserves its paused state")
	await h.shot("52_finale_english")
	game.map_return_paused = true
	game.map_return_menu = "finale"
	game.ui.show_map("heart_chamber")
	await h.frames(3)
	await h.shot("53_heart_map")
	game.close_map()
	h.check(get_tree().paused and game.ui.menu_mode == "finale", "Closing the map returns to the ending overlay")
	game.resume()
	await h.press("interact",2)
	h.check(not get_tree().paused and Session.flags.count("journey_restored") == 1, "Continue exploring does not replay or duplicate the ending")
	h.check(Session.restore() and "journey_restored" in Session.flags, "Final ending mark survives saved-state restore")
	# Failed finale save keeps session benefit and reports failure on the ending itself.
	Session.flags.erase("journey_restored")
	game.load_room("heart_chamber", "chapter_return")
	player.revive(Vector2(560,480))
	await h.frames(3)
	game.room.update_progress()
	var save_path := Session.save_path
	Session.save_path = "user://missing_finale_test_directory/save.json"
	await h.press("interact",2)
	h.check(game.ui.menu_mode == "finale" and not game.ui.finale_saved and game.ui.menu.get_child(2).text.contains("Save failed"), "Ending save failure is visible on the ending overlay")
	await h.shot("54_finale_save_failure")
	Session.save_path = save_path
	game.resume()
	game.load_room("atrium","checkpoint")
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.restore() and "journey_restored" in Session.flags, "Shrine retry persists ending after a failed automatic save")
