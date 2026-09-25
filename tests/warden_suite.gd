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
	await h.press("interact",2)
	await h.frames(5)
	h.check(game.room.room_id == "heart_chamber" and Session.checkpoint_room == "atrium", "Arena entrance establishes a safe antechamber retry checkpoint")
	var boss := game.room.get_node("Enemies/Warden") as HollowWarden
	h.check(boss.state == HollowWarden.State.DORMANT and not game.ui.boss_panel.visible, "Arena entry is safe before crossing the activation line")
	h.check(not game.room.get_node("Interactions/FinalEcho").visible, "Final echo remains hidden while the warden lives")
	game._on_interaction(game.room.get_node("Interactions/FinalEcho"))
	h.check("journey_restored" not in Session.flags, "Final echo cannot be claimed before boss defeat")
	await h.frames(30)
	await h.shot("46_warden_entry")
	player.revive(Vector2(380,480))
	await h.frames(2)
	h.check(boss.state == HollowWarden.State.INTRO and game.ui.boss_panel.visible and game.ui.boss_bar.value == 12, "Crossing the arena starts a harmless introduction and full boss bar")
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Warden reaches a natural sweep windup")
	var hp := player.health.current
	var direction := boss.facing
	await h.frames(20)
	h.check(player.health.current == hp and not boss.attack_box.active, "Sweep warning cannot damage a nearby grounded player")
	player.revive(boss.position+Vector2(60,0))
	await h.frames(3)
	h.check(boss.facing == direction, "Sweep never turns toward a player crossing behind during warning")
	await h.shot("47_warden_sweep_warning")
	player.revive(boss.position+Vector2(direction*60,0))
	await h.frames(3)
	h.check(await wait_state(h,boss,HollowWarden.State.STRIKE), "Sweep warning transitions into a real active hitbox")
	await h.frames(8)
	h.check(player.health.current == hp-1, "Standing in the sweep takes exactly one point of damage")
	await h.frames(8)
	h.check(not boss.attack_box.active and player.health.current == hp-1, "Sweep recovery disables damage without a repeated hit")
	# Rush starts after recovery and locks the current direction.
	player.revive(boss.position+Vector2(-80,0))
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Second natural attack begins after its recovery")
	h.check(boss.rush_attack and boss.timer > 0.9, "Second attack is a full one-second rush warning")
	await h.frames(38)
	await h.shot("55_warden_rush_warning")
	await h.frames(10)
	Input.action_press("jump")
	await h.frames(13)
	await h.shot("48_warden_rush_jump")
	await h.frames(36)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum, "Actual normal jump clears the warned rush without invulnerability")
	h.check(boss.state == HollowWarden.State.RECOVER and not boss.attack_box.active, "Rush ends in a harmless punish window")
	# A damaged boss completes its current recovery before phase transition.
	var phase_changes := [0]
	boss.phase_changed.connect(func(_phase: int) -> void: phase_changes[0] += 1)
	boss.health.take_damage(6,player.position)
	h.check(boss.phase == 1 and boss.state == HollowWarden.State.RECOVER, "Half health does not cancel an existing recovery window")
	h.check(await wait_state(h,boss,HollowWarden.State.TRANSITION), "Half health starts the second phase at a safe boundary")
	h.check(boss.phase == 2 and not boss.attack_box.active and game.ui.boss_title.text.contains("第二阶段"), "Second phase updates Chinese HUD and has no transition damage")
	var time_left := boss.timer
	get_tree().paused = true
	game.ui.show_menu("pause")
	await h.frames(10)
	h.check(boss.timer == time_left, "Pause freezes the boss state timer")
	game.resume()
	await h.frames(2)
	await h.shot("49_warden_phase_two")
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
	h.check(await wait_state(h,boss,HollowWarden.State.WINDUP), "Phase two returns from its transition into a telegraphed attack")
	await wait_state(h,boss,HollowWarden.State.RECOVER)
	await wait_state(h,boss,HollowWarden.State.WINDUP)
	h.check(boss.rush_attack and boss.timer > 0.9, "Second phase retains the full rush warning duration")
	await wait_state(h,boss,HollowWarden.State.STRIKE)
	await h.frames(12)
	h.check(boss.position.x <= 568.1 and boss.state == HollowWarden.State.RECOVER and not boss.attack_box.active, "Rush stops at a two-pixel wall and immediately enters recovery")
	h.check(player.health.current == player.health.maximum, "Boss attacks cannot damage through a world wall")
	h.check(phase_changes[0] == 1 and boss.config.sweep.recovery == 0.95, "Second phase occurs once and never mutates shared attack resources")
	wall.queue_free()
	await h.frames(2)
	# Withdraw to the actual west door. Re-entry creates a fresh encounter.
	player.revive(Vector2(48,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.room_id == "atrium" and not game.ui.boss_panel.visible and "warden_defeated" not in Session.flags, "Retreat removes the boss HUD without awarding victory")
	player.revive(Vector2(816,352))
	await h.frames(3)
	await h.press("interact",2)
	boss = game.room.get_node("Enemies/Warden") as HollowWarden
	h.check(boss.health.current == 12 and boss.phase == 1, "Retreat and re-entry reset health and phase")
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
	await h.shot("50_warden_defeated")
	await h.frames(50)
	h.check(game.room.get_node("Enemies").get_child_count() == 0, "Defeated boss releases its scene after the death animation")
	game.load_room("heart_chamber","entry")
	await h.frames(4)
	h.check(game.room.get_node("Enemies").get_child_count() == 0 and game.room.get_node("Interactions/FinalEcho").visible, "Revisiting a defeated boss keeps it absent and reveals final echo")
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
