extends Node
## Components use isolated positioning; chapter_two_route covers real full battles.

func setup(h: Node, game: Node, at := Vector2(850,480)) -> FurnaceKeeper:
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
	var boss := await setup(h,game,Vector2(620,480))
	player.revive(Vector2(620,480))
	await h.frames(2)
	h.check(game.room.get_node("ArenaGate").closed and game.room.nearby_exit_target().is_empty() and not game.room.get_node("Interactions/Return").visible and not game.room.get_node("Interactions/CoreEcho").visible, "Keeper room hides both exits until victory")
	h.check(game.camera.position == Vector2(860,330), "Keeper camera starts at its fixed combat position")
	Input.action_press("move_left")
	await h.frames(24)
	Input.action_release("move_left")
	h.check(player.position.x >= 590 and game.room.room_id == "furnace_core", "Player cannot move out of the fixed keeper chamber before combat")
	h.check(game.camera.position == Vector2(860,330), "Keeper camera does not pan when the player moves")
	player.revive(Vector2(700,480))
	await h.frames(2)
	Session.set_language("zh_CN")
	h.check(boss.state == FurnaceKeeper.State.DORMANT and not game.ui.boss_panel.visible and game.ui.prompt.text.contains("突进"), "Keeper entrance is safe and teaches both counters before activation")
	h.check(game.room.get_node("Enemies").get_child_count() == 1, "Furnace contains an independent keeper instead of the old mixed mobs")
	await h.shot("98_keeper_lesson_zh")
	player.revive(Vector2(850,480))
	await h.frames(3)
	h.check(boss.state == FurnaceKeeper.State.INTRO and game.ui.boss_title.text.contains("炉心监守者"), "Crossing arena boundary awakens keeper and its own translated boss bar")
	var gate := game.room.get_node("ArenaGate") as FurnaceArenaGate
	h.check(gate.closed and not gate.get_node("Shape").disabled, "Boss awakening seals the left entrance")
	var vents_off := true
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vents_off = vents_off and not vent.enabled
	h.check(vents_off, "Ordinary room vents turn off while boss patterns teach their timing")
	var hurt := boss.get_node("Hurtbox") as Hurtbox
	h.check(hurt.resolve_hit(1,player.position) == Hurtbox.HitResult.DAMAGED and boss.health.current == boss.config.maximum_health-1, "Keeper can be damaged immediately after entering the arena")
	h.check(await until(h,boss,FurnaceKeeper.State.WARNING), "Keeper reaches full first warning")
	boss.health.invulnerability_left = 0.0
	h.check(hurt.resolve_hit(1,player.position) == Hurtbox.HitResult.DAMAGED and boss.health.current == boss.config.maximum_health-2, "Ordinary warning does not silently block a sword hit")
	boss.health.restore_full()
	var timer := boss.timer
	get_tree().paused = true
	await h.frames(8)
	h.check(boss.timer == timer, "Pause freezes keeper warning")
	get_tree().paused = false
	var dash_visual := boss.get_node("VisualEffects")
	h.check((boss.sprite.material as ShaderMaterial).get_shader_parameter("charge_amount") > 0.0 and dash_visual.glow.visible, "Ground dash warning tints the full body red before the hitbox opens")
	await h.shot("99_keeper_wave_warning")
	var locked := boss.facing
	player.revive(Vector2(1010,480))
	await h.frames(2)
	h.check(boss.facing == locked, "Dash direction stays committed after player crosses behind")
	player.revive(Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.CAST)
	await h.frames(2)
	h.check((boss.sprite.material as ShaderMaterial).get_shader_parameter("charge_amount") > 0.0 and dash_visual.ghosts.any(func(ghost: Sprite2D) -> bool: return ghost.visible), "Ground dash keeps its red body and captured movement trail")
	await h.shot("100_keeper_wave_active")
	await h.frames(13)
	h.check(player.health.current == player.health.maximum-1, "Actual dash slash collision deals one damage")
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(boss.position-Vector2(40,0))
	player.facing = 1
	await h.frames(3)
	var hp := boss.health.current
	await h.press("attack",14)
	h.check(boss.health.current == hp-1 and boss.state == FurnaceKeeper.State.RECOVER, "Real mapped sword damages keeper during uninterrupted pressure release")
	await h.shot("101_keeper_recovery")
	# Normal jump clears the committed ground slash.
	boss = await setup(h,game,Vector2(850,480))
	gate = game.room.get_node("ArenaGate") as FurnaceArenaGate
	await until(h,boss,FurnaceKeeper.State.WARNING)
	while boss.timer > 0.18:
		await h.frames(1)
	Input.action_press("jump")
	await h.frames(37)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum, "Normal input jump clears keeper dash without shield or invulnerability")
	# Short hop repositions; the following slam rises above both ledges.
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(Vector2(850,480))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(boss.attack == FurnaceKeeper.Attack.HOP, "Second pattern is a distinct short hop")
	var hop_start := boss.position
	await until(h,boss,FurnaceKeeper.State.CAST)
	await h.frames(12)
	h.check(boss.position.y < hop_start.y-40 and absf(boss.position.x-hop_start.x)>20, "Short hop has real vertical and horizontal travel")
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(Vector2(638,320))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(boss.attack == FurnaceKeeper.Attack.SLAM and absf(boss.position.y-270)<1, "Slam hovers 210px above the floor, well above the ledges")
	var hover_at := boss.position
	while boss.timer > boss.config.hover_seconds*0.75:
		await h.frames(1)
	await h.shot("102p_keeper_charge_first_peak")
	await h.frames(6)
	h.check(boss.position.distance_to(hover_at)<1 and boss.flames.get_child_count()==0, "Hover holds its physical position without premature flames")
	var visual := boss.get_node("VisualEffects")
	var frozen_ages: Array = visual.ages.duplicate()
	var frozen_radius: float = visual.glow.material.get_shader_parameter("radius")
	get_tree().paused = true
	await h.frames(8)
	h.check(visual.ages == frozen_ages and visual.glow.material.get_shader_parameter("radius") == frozen_radius, "Pause freezes charge pulses and captured trails")
	get_tree().paused = false
	await h.shot("102_keeper_high_hover")
	while boss.timer > boss.config.hover_seconds*0.25:
		await h.frames(1)
	await h.shot("102q_keeper_charge_second_peak")
	await until(h,boss,FurnaceKeeper.State.LANDING)
	await h.frames(5)
	h.check(boss.position.y > hover_at.y+50 and absf(boss.position.x-hover_at.x)<1, "Slam descends rapidly and vertically")
	await h.shot("102a_keeper_slam")
	await until(h,boss,FurnaceKeeper.State.IMPACT)
	h.check(boss.sprite.animation == &"eruption_cast" and boss.pressure_guard(), "Landing release plays the source casting animation before recovery")
	await h.frames(1)
	var core := boss.flames.get_child(0) as FurnaceFlame
	var frozen_burst := core.elapsed
	get_tree().paused = true
	await h.frames(5)
	h.check(core.elapsed == frozen_burst, "Pause freezes the visible central impact and its damage lifetime")
	get_tree().paused = false
	await h.shot("102c0_keeper_impact_flash")
	await h.frames(7)
	await h.shot("102c_keeper_release_animation")
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	h.check(boss.flames.get_child_count()==2 and not is_instance_valid(core) and absf(boss.position.y-480)<1, "Central burst expires with its art while both traveling flames remain")
	var left := boss.flames.get_child(0) as FurnaceFlame
	var right := boss.flames.get_child(1) as FurnaceFlame
	var left_x := left.position.x
	var right_x := right.position.x
	await h.frames(12)
	h.check(left.position.x < left_x-50 and right.position.x > right_x+50, "Flame walls propagate away from the landing point in both directions")
	await h.shot("102b_keeper_outward_flames")
	await h.frames(36)
	h.check(player.health.current==player.health.maximum-1, "Visible upper flame wall damages a player standing on a ledge once")
	# Damage does not interrupt recovery or start a numbered phase.
	boss.health.invulnerability_left = 0
	boss.health.take_damage(8,boss.position)
	h.check(boss.state==FurnaceKeeper.State.RECOVER, "Half health never cuts recovery short")
	h.check(await until(h,boss,FurnaceKeeper.State.APPROACH) or await until(h,boss,FurnaceKeeper.State.WARNING), "Attack loop continues without a health-gated transition")
	h.check(game.ui.boss_title.text == "炉心监守者", "Keeper HUD shows its name without a numbered phase")
	await h.shot("103_keeper_next_attack")
	player.revive(Vector2(620,480))
	Input.action_press("move_left")
	await h.frames(35)
	Input.action_release("move_left")
	h.check(player.position.x >= gate.position.x+15 and boss.state != FurnaceKeeper.State.DORMANT and gate.closed, "Leftward movement cannot leave or reset an active boss fight")
	boss.reset_encounter()
	gate.set_closed(false)
	await h.frames(3)
	h.check(boss.health.current == boss.config.maximum_health and boss.flames.get_child_count() == 0 and not visual.glow.visible and visual.ghosts.all(func(ghost: Sprite2D) -> bool: return not ghost.visible), "Encounter reset clears hazards and visual trails")
	# Isolated real cast verifies shield, pause and expiry through the normal hurtbox.
	player.revive(Vector2(850,480))
	boss.set_physics_process(false)
	Session.unlock("double_jump")
	var edge_left := boss.config.arena_min_x
	var edge_right := boss.config.arena_max_x
	var edge_reached := [false,false]
	for side: float in [-1.0,1.0]:
		var sweep := preload("res://features/combat/furnace_flame.tscn").instantiate() as FurnaceFlame
		sweep.config = boss.config
		sweep.outward = true
		sweep.instant = true
		sweep.direction = side
		boss.flames.add_child(sweep)
		sweep.global_position = Vector2(edge_left+65 if side < 0 else edge_right-65,480)
		var index := 0 if side < 0 else 1
		for frame: int in range(20):
			await h.frames(1)
			if is_instance_valid(sweep):
				edge_reached[index] = edge_reached[index] or (sweep.global_position.x <= edge_left+6 if side < 0 else sweep.global_position.x >= edge_right-6)
	h.check(edge_reached[0] and edge_reached[1], "Air slam flame walls physically sweep to both arena boundaries")
	boss.clear_flames()
	# Full-height walls can be cleared with a normal jump from either real ledge.
	for side: float in [-1.0,1.0]:
		var ledge_x := 638.0 if side < 0 else 1080.0
		player.revive(Vector2(ledge_x,320))
		await h.frames(3)
		var wall := preload("res://features/combat/furnace_flame.tscn").instantiate() as FurnaceFlame
		wall.config = boss.config
		wall.outward = true
		wall.direction = side
		boss.flames.add_child(wall)
		wall.global_position = Vector2(ledge_x-side*110,480)
		Input.action_press("jump")
		var foot_peak := player.position.y
		for tick: int in range(24):
			await h.frames(1)
			foot_peak = minf(foot_peak,player.position.y)
		Input.action_release("jump")
		await h.frames(20)
		h.check(player.health.current == player.health.maximum and foot_peak < 480-boss.config.outward_height-20, "Mapped ledge jump clears full-height flame wall in direction " + str(side))
		boss.clear_flames()
		await h.frames(2)
	for ledge_x: float in [638.0,1080.0]:
		player.revive(Vector2(ledge_x,480))
		await h.frames(3)
		Input.action_press("jump")
		await h.frames(20)
		var peak_y := player.position.y
		Input.action_release("jump")
		await h.frames(2)
		Input.action_press("jump")
		for tick: int in range(20):
			await h.frames(1)
			peak_y = minf(peak_y,player.position.y)
		Input.action_release("jump")
		await h.frames(50)
		h.check(player.is_on_floor() and absf(player.position.y-320) < 1, "Mapped double jump lands on boss ledge at " + str(ledge_x) + " (peak=" + str(peak_y) + ", y=" + str(player.position.y) + ")")
	# Isolate the new ground patterns, retaining their real windup and hitboxes.
	boss.set_physics_process(true)
	boss.attack_count = 3
	player.revive(boss.position+Vector2(64,0))
	boss.start_attack()
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(boss.attack == FurnaceKeeper.Attack.MELEE and not boss.dash_hitbox.active, "Basic melee approaches and visibly winds up before damage")
	await h.shot("110_keeper_melee_warning")
	await until(h,boss,FurnaceKeeper.State.CAST)
	var melee_at := boss.position.x
	await h.frames(5)
	h.check(player.health.current == player.health.maximum-1 and absf(boss.position.x-melee_at)<1, "Basic melee hits once without turning into a dash")
	await until(h,boss,FurnaceKeeper.State.RECOVER)
	player.revive(Vector2(700,480))
	await until(h,boss,FurnaceKeeper.State.WARNING)
	h.check(boss.attack == FurnaceKeeper.Attack.COMBO and boss.timer > 0.85 and not boss.dash_hitbox.active, "Ground combo begins with a full visible charge and no early damage")
	await h.frames(13)
	await h.shot("111_keeper_ground_charge")
	for strike: int in range(boss.config.combo_strikes):
		player.revive(boss.position+Vector2(boss.facing*52,0))
		await until(h,boss,FurnaceKeeper.State.CAST)
		var committed := boss.facing
		await h.frames(5)
		h.check(player.health.current == player.health.maximum-1, "Charged combo strike " + str(strike+1) + " uses its own real damage window")
		player.revive(boss.position-Vector2(committed*100,0))
		await h.frames(2)
		h.check(boss.facing == committed, "Combo strike stays committed when player crosses behind")
		if strike == 0:
			await h.shot("112_keeper_combo_slash")
		while boss.state == FurnaceKeeper.State.CAST:
			await h.frames(1)
		h.check(not boss.dash_hitbox.active and boss.state == (FurnaceKeeper.State.WARNING if strike < boss.config.combo_strikes-1 else FurnaceKeeper.State.RECOVER), "Combo pauses between strikes and recovers after its final strike")
	h.check(boss.timer >= boss.config.recovery_seconds-0.1 and not boss.pressure_guard(), "Full combo recovery opens a reliable counterattack window")
	boss.reset_encounter()
	boss.set_physics_process(false)
	player.revive(Vector2(850,480))
	Session.unlock("steam_ward")
	await h.frames(3)
	boss.spawn_flame(player.position,false)
	var mark := boss.flames.get_child(0) as FurnaceFlame
	var frozen := mark.warning_left
	get_tree().paused = true
	await h.frames(5)
	h.check(mark.warning_left == frozen, "Pause also freezes spawned eruption clocks")
	game.resume()
	await h.frames(3)
	await h.press("steam_ward",2)
	await h.frames(115)
	h.check(player.health.current == player.health.maximum and player.steam_ward.active_left == 0 and boss.flames.get_child_count() == 0, "Shield consumes one full eruption and no later plume frame damages player")
	boss.spawn_flame(player.position,false)
	await h.frames(115)
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
	player.revive(Vector2(650,480))
	game.ui.reward_notice.remaining = 0
	await h.frames(3)
	await h.shot("105a_keeper_central_door")
	h.check(not (game.room.get_node("ArenaGate") as FurnaceArenaGate).closed and game.room.get_node("Interactions/Return").visible and game.room.get_node("Interactions/CoreEcho").visible and game.room.get_node("Interactions/CoreEcho").position.x == 1080, "Boss defeat opens the left run-out and reveals the right chapter door")
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
	# Old water restoration is preserved, but never stands in for a real boss victory.
	Session.flags.erase("furnace_keeper_defeated")
	Session.set_flag("cistern_restored")
	Session.set_flag("heart_bloom")
	Session.set_flag("cistern_heart")
	player.health.maximum = Session.maximum_health()
	Session.commit()
	var legacy_snapshot := Session.snapshot()
	var legacy_bytes := FileAccess.get_file_as_string(Session.save_path)
	var legacy_maximum := Session.maximum_health()
	h.check(legacy_maximum == 6, "Legacy heart and flower markers give six HP, with no extra vitality from the shield")
	var restored_player := preload("res://features/player/player.tscn").instantiate() as Player
	restored_player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(restored_player)
	h.check(restored_player.health.maximum == 6 and restored_player.health.current == 6, "A fresh player loaded from the legacy ability and reward state starts at six HP")
	restored_player.queue_free()
	h.check(Session.restore(), "Legacy cistern save still restores through the normal repository")
	game.load_room("ember_quay","checkpoint")
	h.check(Session.snapshot() == legacy_snapshot and Session.maximum_health() == legacy_maximum, "Legacy restore preserves abilities, health rewards and all earned flags")
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		h.check(not vent.enabled, "Legacy water restoration keeps ordinary steam disabled")
	Session.set_language("zh_CN")
	h.check(TextCatalog.text(JourneyProgress.objective(Session.abilities,Session.flags,Session.visited)).contains("击败监守者"), "Legacy objective names the unbeaten keeper instead of claiming both chapters are complete")
	game.ui.show_map("ember_quay")
	h.check(game.ui.world_map.target_room() == "furnace_core", "Legacy map still directs the player to the unbeaten keeper")
	await h.shot("134_legacy_keeper_map_zh")
	game.ui.hide_map()
	game.load_room("furnace_core","entry")
	player.revive(Vector2(700,480))
	await h.frames(3)
	h.check(not game.room.is_cleared() and game.room.get_node("Enemies/FurnaceKeeper") is FurnaceKeeper, "Legacy restored cistern with no keeper victory spawns the real boss")
	h.check(game.room.get_node("ArenaGate").closed and not game.room.get_node("Interactions/CoreEcho").visible and not game.room.get_node("Interactions/Return").visible and not game.room.get_node("Interactions/Rematch").visible, "Legacy boss fight closes both exits and hides practice until an actual victory")
	game._on_interaction(game.room.get_node("Interactions/CoreEcho"))
	game._on_interaction(game.room.get_node("Interactions/Rematch"))
	await h.frames(3)
	h.check(game.room.room_id == "furnace_core" and not game.room.rehearsal and not game.transition_pending, "Old completion cannot bypass a living boss or start a fake rematch")
	h.check(FileAccess.get_file_as_string(Session.save_path) == legacy_bytes, "Loading the repaired legacy encounter never rewrites the saved progress")
	await h.press("move_right",22)
	boss = game.room.get_node("Enemies/FurnaceKeeper")
	h.check(boss.state == FurnaceKeeper.State.INTRO and game.ui.boss_panel.visible, "Normal mapped movement awakens the legacy player's unbeaten boss")
	await h.shot("135_legacy_keeper_present_zh")
	player.health.take_damage(99,player.position)
	await h.frames(65)
	h.check(game.room.room_id == "ember_quay" and "cistern_restored" in Session.flags and "furnace_keeper_defeated" not in Session.flags, "Legacy player death keeps water restoration and returns to the safe checkpoint")
	game.load_room("furnace_core","entry")
	boss = game.room.get_node("Enemies/FurnaceKeeper")
	h.check(boss.health.current == boss.health.maximum, "Legacy keeper respawns at full health after a failed attempt")
	boss.health.take_damage(99,boss.position)
	await h.frames(3)
	h.check("furnace_keeper_defeated" in Session.flags and "cistern_restored" in Session.flags and Session.maximum_health() == legacy_maximum, "Actual legacy boss victory adds its own flag and preserves earlier rewards")
	h.check(game.room.get_node("Interactions/CoreEcho").visible and game.room.get_node("Interactions/Return").visible, "Actual legacy victory opens the right exit and left return")
	h.check(Session.restore() and "furnace_keeper_defeated" in Session.flags, "The newly earned legacy keeper victory survives save and restore")
	game.load_room("furnace_core","entry")
	h.check(game.room.is_cleared(), "A genuinely defeated legacy keeper stays absent on revisit")
	var snapshot := Session.snapshot()
	var bytes := FileAccess.get_file_as_string(Session.save_path)
	player.revive(Vector2(860,480))
	await h.frames(3)
	h.check(game.ui.prompt.text == TextCatalog.text("E / RECALL THE KEEPER (PRACTICE)"), "Practice interaction is reachable inside the fixed visible arena")
	await h.shot("136_keeper_rematch_visible_zh")
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
	h.check(not game.room.get_node("ArenaGate").closed and game.room.get_node("Interactions/CoreEcho").visible and game.room.get_node("Interactions/Return").visible, "Practice victory restores both arena exits")
	game.load_room("ember_quay","checkpoint")
	player.revive(Vector2(180,480))
	await h.frames(3)
