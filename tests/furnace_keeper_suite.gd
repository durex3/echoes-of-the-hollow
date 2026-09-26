extends Node
## Components use isolated positioning; chapter_two_route covers real full battles.

func setup(h: Node, game: Node, at := Vector2(700,480)) -> FurnaceKeeper:
	Session.flags.erase("furnace_keeper_defeated")
	Session.flags.erase("cistern_restored")
	game.load_room("furnace_core","entry")
	game.player.revive(at)
	game.ui.reward_notice.remaining = 0
	game.ui.toast_left = 0
	game.ui.set_text(game.ui.toast,"")
	await h.frames(3)
	return game.room.get_node("Enemies/FurnaceKeeper") as FurnaceKeeper

func until(h: Node, boss: FurnaceKeeper, state: FurnaceKeeper.State, limit := 300) -> bool:
	for tick: int in range(limit):
		if boss.state == state:
			return true
		await h.frames(1)
	return false

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	var boss := await setup(h,game,Vector2(200,480))
	Session.set_language("zh_CN")
	h.check(boss.state == FurnaceKeeper.State.DORMANT and not game.ui.boss_panel.visible and game.ui.prompt.text.contains("裂焰"), "Keeper entrance is safe and teaches both counters before activation")
	h.check(game.room.get_node("Enemies").get_child_count() == 1, "Furnace contains an independent keeper instead of the old mixed mobs")
	await h.shot("98_keeper_lesson_zh")
	player.revive(Vector2(850,480))
	await h.frames(3)
	h.check(boss.state == FurnaceKeeper.State.INTRO and game.ui.boss_title.text.contains("炉心监守者"), "Crossing arena boundary awakens keeper and its own translated boss bar")
	var vents_off := true
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vents_off = vents_off and not vent.enabled
	h.check(vents_off, "Ordinary room vents turn off while boss patterns teach their timing")
	var hurt := boss.get_node("Hurtbox") as Hurtbox
	h.check(hurt.resolve_hit(1,player.position) == Hurtbox.HitResult.BLOCKED and boss.health.current == 14, "Pressure seal protects keeper outside recovery")
	h.check(await until(h,boss,FurnaceKeeper.State.WARNING), "Keeper reaches full first warning")
	var timer := boss.timer
	get_tree().paused = true
	await h.frames(8)
	h.check(boss.timer == timer, "Pause freezes keeper warning")
	get_tree().paused = false
	await h.shot("99_keeper_wave_warning")
	var locked := boss.facing
	player.revive(Vector2(1010,480))
	await h.frames(2)
	h.check(boss.facing == locked, "Wave direction stays committed after player crosses behind")
	player.revive(Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.CAST)
	await h.frames(2)
	await h.shot("100_keeper_wave_active")
	await h.frames(13)
	h.check(player.health.current == player.health.maximum-1, "Actual low flame collision deals one damage")
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(boss.position-Vector2(40,0))
	player.facing = 1
	await h.frames(3)
	var hp := boss.health.current
	await h.press("attack",14)
	h.check(boss.health.current == hp-1 and boss.state == FurnaceKeeper.State.RECOVER, "Real mapped sword damages keeper during uninterrupted pressure release")
	await h.shot("101_keeper_recovery")
	# Normal jump alone clears the measured 38px low flame.
	boss = await setup(h,game,Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	while boss.timer > 0.18:
		await h.frames(1)
	Input.action_press("jump")
	await h.frames(37)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum, "Normal input jump clears keeper flame without shield or invulnerability")
	# Second attack locks a marker and waits the same full 0.9s warning.
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(not boss.wave_attack and boss.flames.get_child_count() == 1, "First phase introduces a single locked eruption after its low wave")
	var mark := boss.flames.get_child(0) as FurnaceFlame
	var mark_at := mark.global_position
	Input.action_press("move_left")
	await h.frames(30)
	Input.action_release("move_left")
	h.check(mark.global_position == mark_at and player.health.current == player.health.maximum, "Warning is harmless and eruption marker does not follow moving player")
	await h.shot("102_keeper_eruption_mark")
	await h.frames(26)
	await h.shot("102b_keeper_eruption_active")
	await h.frames(24)
	h.check(player.health.current == player.health.maximum, "Walking clear of the mark avoids eruption")
	# Force only HP for transition boundary coverage; timers and attacks remain real.
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	boss.health.invulnerability_left = 0
	boss.health.take_damage(8,boss.position)
	h.check(boss.phase == 1 and boss.state == FurnaceKeeper.State.RECOVER, "Half-health never cuts the current recovery short")
	await until(h,boss,FurnaceKeeper.State.TRANSITION)
	h.check(boss.phase == 2 and boss.timer > 1.1, "Phase two has a separate safe transition")
	await h.shot("103_keeper_phase_two")
	await until(h,boss,FurnaceKeeper.State.WARNING)
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(not boss.wave_attack and boss.flames.get_child_count() == 2 and boss.timer > 0.8, "Phase two combines two spaced marks without shortening warning")
	var a := boss.flames.get_child(0) as FurnaceFlame
	var b := boss.flames.get_child(1) as FurnaceFlame
	h.check(absf(a.position.x-b.position.x) == 120 and absf(a.position.x-b.position.x)-66 >= 54, "Twin marks leave a body-width safe gap and movement space")
	await h.shot("104_keeper_twin_marks")
	player.revive(Vector2(420,480))
	await h.frames(3)
	h.check(boss.state == FurnaceKeeper.State.DORMANT and boss.health.current == 14 and boss.flames.get_child_count() == 0 and not game.ui.boss_panel.visible, "Retreat resets boss and clears pending hazards without awarding progress")
	# Isolated real cast verifies shield, pause and expiry through the normal hurtbox.
	player.revive(Vector2(850,480))
	boss.set_physics_process(false)
	Session.unlock("steam_ward")
	await h.frames(3)
	boss.spawn_flame(player.position,false)
	mark = boss.flames.get_child(0)
	var frozen := mark.warning_left
	get_tree().paused = true
	await h.frames(5)
	h.check(mark.warning_left == frozen, "Pause also freezes spawned eruption clocks")
	game.resume()
	await h.frames(3)
	await h.press("steam_ward",2)
	await h.frames(75)
	h.check(player.health.current == player.health.maximum and player.steam_ward.active_left == 0 and boss.flames.get_child_count() == 0, "Shield consumes one full eruption and no later plume frame damages player")
	boss.spawn_flame(player.position,false)
	await h.frames(75)
	h.check(player.health.current == player.health.maximum-1, "Unshielded eruption damages once and expires")
	boss.spawn_flame(player.position,false)
	player.health.invulnerability_left = 0
	Session.checkpoint_room = "ember_quay"
	Session.checkpoint_spawn = "checkpoint"
	player.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(boss.flames.get_child_count() == 0, "Player death immediately cancels boss hazards")
	await h.frames(65)
	h.check(game.room.room_id == "ember_quay" and player.health.current == player.health.maximum, "Boss defeat retry uses safe quay checkpoint")
	# Same-frame death cannot grant a win; stale callbacks cannot affect a new room.
	boss = await setup(h,game)
	boss.health.take_damage(99,boss.position)
	player.health.take_damage(99,player.position)
	await h.frames(3)
	h.check("furnace_keeper_defeated" not in Session.flags, "Simultaneous keeper/player death does not grant victory")
	await h.frames(65)
	boss = await setup(h,game)
	boss.health.take_damage(99,boss.position)
	game.load_room("ember_quay","checkpoint")
	await h.frames(3)
	h.check("furnace_keeper_defeated" not in Session.flags, "Old-room deferred victory cannot award a keeper flag")
	# Failure retains the live session; shrine retry persists the stable flag.
	boss = await setup(h,game)
	var save_path: String = Session.save_path
	Session.save_path = "user://missing_keeper_test_directory/save.json"
	boss.health.take_damage(99,boss.position)
	await h.frames(3)
	h.check("furnace_keeper_defeated" in Session.flags and not game.ui.reward_notice.save_succeeded and player.health.current == player.health.maximum, "Keeper victory heals and retains progress even if save fails")
	Session.save_path = save_path
	await h.shot("105_keeper_reward_save_failure")
	await h.frames(65)
	game.load_room("ember_quay","checkpoint")
	player.revive(Vector2(180,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(Session.restore() and "furnace_keeper_defeated" in Session.flags, "Shrine retry persists keeper victory")
	game.load_room("furnace_core","entry")
	h.check(game.room.is_cleared() and game.room.get_node("Interactions/Rematch").visible, "Defeated keeper stays absent while optional practice becomes available")
	# A 0.13 completed save remains completed without inventing a mandatory new fight.
	Session.flags.erase("furnace_keeper_defeated")
	Session.set_flag("cistern_restored")
	Session.commit()
	game.load_room("furnace_core","entry")
	h.check(game.room.is_cleared() and not game.room.get_node("Interactions/CoreEcho").visible, "Old chapter-complete save bypasses new boss and keeps its ending")
	var snapshot := Session.snapshot()
	var bytes := FileAccess.get_file_as_string(Session.save_path)
	player.revive(Vector2(290,480))
	await h.frames(3)
	await h.press("interact",2)
	h.check(game.room.rehearsal and game.room.get_node("Enemies").get_child_count() == 1, "Real rematch interaction starts practice for a completed save")
	player.revive(Vector2(850,480))
	await h.frames(5)
	Session.set_language("en")
	await h.shot("106_keeper_practice_en")
	boss = game.room.get_node("Enemies/FurnaceKeeper")
	boss.health.take_damage(99,boss.position)
	await h.frames(3)
	h.check(Session.snapshot() == snapshot and FileAccess.get_file_as_string(Session.save_path) == bytes, "Practice victory changes no completion flags or saved bytes")
	game.load_room("ember_quay","checkpoint")
	player.revive(Vector2(180,480))
	await h.frames(3)
