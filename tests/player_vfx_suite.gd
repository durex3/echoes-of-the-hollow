extends Node
## Actual input, physics and source-art checks. The boss is frozen as a test target.

func run(h: Node, game: Node) -> void:
	game.start_boss_challenge(1)
	await h.frames(3)
	var player: Player = game.player
	var boss: HollowWarden = game.room.get_node("Enemies/Warden")
	boss.set_physics_process(false)
	var shape: RectangleShape2D = player.attack_box.get_node("Shape").shape
	var original_size := shape.size
	var original_profile := [player.config.attack.windup, player.config.attack.active_seconds, player.config.attack.recovery]
	for direction: float in [1.0, -1.0]:
		player.revive(Vector2(320,480))
		player.facing = direction
		boss.position = player.position + Vector2(direction*58,0)
		await h.frames(3)
		var hp := boss.health.current
		Input.action_press("attack")
		await h.frames(2)
		h.check(not player.slash.visible and not player.attack_box.active, "Sword windup has no premature glow or damage facing " + str(direction))
		await h.frames(6)
		Input.action_release("attack")
		h.check(player.slash.visible and player.slash.pose == 1 and player.visual.scale.x == direction, "Source smear peak matches active sword and facing " + str(direction))
		var texture := player.slash.core.texture as AtlasTexture
		h.check(texture.atlas.resource_path.ends_with("weapon_smears.png") and not texture.get_image().is_invisible(), "Sword uses the course smear artwork instead of a drawn arc")
		h.check(boss.health.current == hp - 1, "Glowing sword still deals exactly one real hit")
		await h.shot("117_player_sword_right" if direction > 0 else "118_player_sword_left")
		get_tree().paused = true
		var captured := player.slash.pose
		var elapsed := player.attack_elapsed
		await h.frames(4)
		h.check(player.slash.pose == captured and player.attack_elapsed == elapsed, "Pause freezes source sword pose and damage clock")
		get_tree().paused = false
		await h.frames(4)
		h.check(player.slash.pose >= 2 and player.slash.visible, "Bright sword breaks into thin source streaks before ending")
		await h.frames(35)
		h.check(player.state == Player.State.MOVE and not player.slash.visible and not player.attack_box.active and boss.health.current == hp - 1 and player.attack_variant == 0, "One press plays only one hand and never launches the other automatically")
		await h.press("attack", 8)
		h.check(player.attack_variant == 1 and player.sprite.animation == &"attack_return" and player.slash.visible, "The next distinct press chooses the other hand")
		var other_smear := player.slash.core.texture as AtlasTexture
		h.check(other_smear.region.position.x >= 512 and boss.health.current == hp - 2, "Other hand uses its matching smear and deals one hit")
		await h.shot("124_player_other_hand_right" if direction > 0 else "125_player_other_hand_left")
		await h.frames(20)
	h.check(shape.size == original_size and original_profile == [player.config.attack.windup, player.config.attack.active_seconds, player.config.attack.recovery], "Sword presentation preserves the attack shape and timing resource")
	boss.position = Vector2(560,480)
	player.revive(Vector2(320,480))
	await h.frames(3)
	Input.action_press("attack")
	await h.frames(60)
	h.check(player.state == Player.State.MOVE and player.attack_variant == 0 and player.next_attack_variant == 1 and not player.attack_box.active, "Holding attack plays one hand only, with no automatic alternation")
	Input.action_release("attack")
	await h.frames(2)
	player.revive(Vector2(320,480))
	await h.press("attack", 1)
	await h.frames(16)
	var end_pose := player.sprite.sprite_frames.get_frame_texture(&"attack",5) as AtlasTexture
	var next_pose := player.sprite.sprite_frames.get_frame_texture(&"attack_return",0) as AtlasTexture
	h.check(end_pose.region == next_pose.region and end_pose.region != Rect2(0,0,80,80), "First hand recovery joins the other hand preparation without an idle pose")
	await h.press("attack", 1)
	h.check(player.attack_buffer_left > 0, "A fresh recovery press queues exactly one opposite-hand stroke")
	await h.frames(4)
	h.check(player.state == Player.State.ATTACK and player.attack_variant == 1 and player.attack_elapsed < 0.08, "Queued press starts the other hand after the full recovery")
	await h.frames(30)
	h.check(player.state == Player.State.MOVE and player.next_attack_variant == 0, "Two presses produce two strokes and no third automatic attack")
	# A queued input is discarded when hurt, so there is no surprise follow-up.
	await h.press("attack", 1)
	await h.frames(16)
	await h.press("attack", 1)
	player.health.take_damage(1, player.position + Vector2(100,0))
	await h.frames(40)
	h.check(player.attack_phase == AttackProfile.Phase.FINISHED and player.attack_buffer_left == 0 and not player.slash.visible and not player.attack_box.active, "Damage discards a queued recovery press without a delayed attack")
	player.revive(Vector2(320,480))
	h.check(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer" and ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), "Pixel presentation uses integer window scaling and snapped transforms")
	h.check(is_equal_approx(boss.sprite.scale.x * 1.4, 2.0) and boss.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "King pixels render at two internal pixels with nearest sampling")
	for direction: float in [1.0, -1.0]:
		player.revive(Vector2(260 if direction > 0 else 400,480))
		player.facing = direction
		await h.frames(3)
		var start := player.position
		Input.action_press("dash")
		await h.frames(7)
		var effects := player.effects
		var visible_count := 0
		var stationary_index := -1
		for index: int in range(effects.ghosts.size()):
			if effects.ghosts[index].visible:
				visible_count += 1
				if effects.ages[index] > 0.06:
					stationary_index = index
		h.check(visible_count >= 3 and effects.front.visible and effects.aura.visible, "Dash has multiple captured green silhouettes and a leading glow")
		h.check(player.health.invulnerability_left == 0 and not player.attack_box.active, "Dash presentation adds neither invulnerability nor attack damage")
		await h.shot("119_player_dash_right" if direction > 0 else "120_player_dash_left")
		if stationary_index >= 0:
			var ghost := effects.ghosts[stationary_index]
			var at := ghost.global_position
			await h.frames(1)
			h.check(ghost.global_position == at and signf(ghost.global_transform.x.x) == direction, "Captured dash pose stays at its world position with correct facing")
		get_tree().paused = true
		var ages := effects.ages.duplicate()
		var dash_left := player.dash_left
		await h.frames(5)
		h.check(ages == effects.ages and dash_left == player.dash_left, "Pause freezes dash silhouettes, fade and movement together")
		get_tree().paused = false
		Input.action_release("dash")
		await h.frames(4)
		h.check(absf(player.position.x - start.x) > 105 and absf(player.position.x - start.x) < 125, "Dash retains its measured travel with new effects")
		await h.frames(18)
		h.check(not effects.front.visible and effects.ghosts.all(func(ghost: Sprite2D) -> bool: return not ghost.visible), "Dash afterimages expire completely after movement ends")
	player.revive(Vector2(260,480))
	player.facing = 1
	await h.frames(2)
	Session.reduce_flashes = true
	await h.press("dash",5)
	h.check(player.effects.aura.modulate.a < 0.5 and player.effects.front.modulate.a < 0.3, "Reduced flashes lowers dash aura and front tint")
	await h.shot("121_player_dash_reduced")
	player.health.take_damage(1,player.position + Vector2(100,0))
	h.check(player.state == Player.State.HURT and not player.effects.front.visible and player.effects.ghosts.all(func(ghost: Sprite2D) -> bool: return not ghost.visible), "A real hit interrupts dash and immediately clears every afterimage")
	Session.reduce_flashes = false
	player.revive(Vector2(260,480))
	await h.frames(2)
	await h.press("dash",4)
	game.load_room("heart_chamber","entry")
	await h.frames(2)
	h.check(player.effects.ghosts.all(func(ghost: Sprite2D) -> bool: return not ghost.visible), "Changing rooms leaves no world-space player trails")
	player.revive(Vector2(260,480))
	player.facing = 1
	await h.frames(2)
	await h.press("dash",4)
	h.check(player.effects.front.visible, "Death cleanup starts from a real active dash")
	player.health.take_damage(99,player.position)
	h.check(not player.effects.front.visible and player.effects.ghosts.all(func(ghost: Sprite2D) -> bool: return not ghost.visible), "Death clears green dash art immediately")
	game.return_to_title()
	await h.frames(3)
