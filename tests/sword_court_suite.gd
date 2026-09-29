extends Node
## Real native scene, mapped movement, swept hits and isolated challenge progress.

func prepare(h: Node, game: Node, at := Vector2(180,480)) -> HollowWarden:
	game.start_boss_challenge(1)
	await h.frames(4)
	var boss: HollowWarden = game.room.get_node("Enemies/Warden")
	game.player.revive(at)
	boss.health.take_damage(6,game.player.position)
	boss.attack_count = 2
	boss._start_attack()
	return boss

func wait_lock(h: Node, court: SwordCourt, round_index: int) -> bool:
	for tick: int in range(650):
		if not is_instance_valid(court):
			return false
		if court.phase == SwordCourt.Phase.LOCK and court.round_index == round_index:
			return true
		await h.frames(1)
	return false

func finish(h: Node, court: SwordCourt) -> void:
	for tick: int in range(1000):
		if not is_instance_valid(court):
			return
		await h.frames(1)

func test_sword(game: Node, config: SwordCourtConfig, from: Vector2, at: Vector2, hits: Array[int]) -> RoyalSword:
	var sword := preload("res://features/combat/royal_sword.tscn").instantiate() as RoyalSword
	sword.config = config
	game.room.add_child(sword)
	sword.global_position = from
	sword.lock_on(at,0.55)
	sword.launch(hits)
	return sword

func run(h: Node, game: Node) -> void:
	var boss := await prepare(h,game)
	var player: Player = game.player
	var court := boss.sword_court
	h.check(boss.state == HollowWarden.State.SWORD_COURT and court.swords.size() == 7, "Attack loop opens the grounded seven-sword court")
	var at := boss.position
	await h.frames(15)
	player.revive(boss.position + Vector2(-54,0))
	player.facing = 1
	await h.frames(2)
	var hp := boss.health.current
	await h.press("attack",12)
	h.check(boss.health.current == hp and boss.flash_left == 0 and boss.summon_guard(), "A real player sword cannot damage or interrupt the invulnerable summon")
	player.revive(Vector2(180,480))
	await h.frames(40)
	h.check(boss.position.distance_to(at) < 0.2 and boss.is_on_floor() and not boss.attack_box.active, "Protected charge holds the king grounded without a hidden melee hit")
	h.check(player.health.current == player.health.maximum and court.swords.all(func(s: RoyalSword) -> bool: return not s.dangerous()), "Summoning swords remain harmless")
	var source := court.swords[0].sprite.sprite_frames
	var visible_frames := true
	for clip: StringName in source.get_animation_names():
		for index: int in range(source.get_frame_count(clip)):
			visible_frames = visible_frames and not source.get_frame_texture(clip,index).get_image().is_invisible()
	h.check(visible_frames, "Every sword animation cell contains real source artwork")
	await h.shot("126_sword_court_crown")
	await wait_lock(h,court,0)
	h.check(boss.state == HollowWarden.State.CHASE and not boss.summon_guard() and not court.swords[0].dangerous(), "Charge releases the king before the first sword launches, without waiting")
	h.check(boss.get_node("Hurtbox").receive_hit(1,player.position) and boss.health.current == hp-1, "The summon shield ends immediately while the sword court stays active")
	var released_at := boss.position
	await h.frames(20)
	h.check(boss.position.x < released_at.x-20 and court.phase == SwordCourt.Phase.LOCK, "The king genuinely chases during the first sword warning")
	get_tree().paused = true
	var elapsed := court.elapsed
	var sword_elapsed := court.swords[0].elapsed
	var boss_at := boss.position
	await h.frames(8)
	h.check(court.elapsed == elapsed and court.swords[0].elapsed == sword_elapsed and boss.position == boss_at, "Pause freezes independent king movement and sword clocks together")
	get_tree().paused = false
	await h.shot("127_sword_court_aim")
	for tick: int in range(130):
		if boss.state == HollowWarden.State.WINDUP:
			break
		await h.frames(1)
	h.check(is_instance_valid(court) and boss.state == HollowWarden.State.WINDUP and boss.attack != HollowWarden.Attack.CHARGED, "The live king starts ordinary attacks while summoned swords remain")
	var clip := boss.sprite.animation
	var timer := boss.timer
	court.volley_locked.emit(2)
	court.volley_fired.emit(2)
	h.check(boss.sprite.animation == clip and boss.timer == timer, "Independent sword events never overwrite the king's ordinary attack animation")
	await h.shot("132_sword_court_concurrent")
	for tick: int in range(90):
		if boss.state == HollowWarden.State.STRIKE:
			break
		await h.frames(1)
	h.check(is_instance_valid(court) and boss.state == HollowWarden.State.STRIKE and boss.attack_box.active, "Concurrent ordinary attacks reach a real damaging strike while the court is active")
	var ordinary_before := boss.ordinary_attacks_since_court
	boss.ordinary_attacks_since_court = 99
	boss.court_cooldown_left = 0
	h.check(boss._choose_attack() != HollowWarden.Attack.CHARGED, "An active court cannot summon a second overlapping court")
	boss.ordinary_attacks_since_court = ordinary_before
	await h.shot("133_sword_court_melee")
	# Isolate projectile rounds from the already verified moving/melee body.
	boss = await prepare(h,game)
	player = game.player
	court = boss.sword_court
	await wait_lock(h,court,0)
	boss.set_physics_process(false)
	var rounds: Array[int] = []
	court.volley_fired.connect(func(index: int) -> void: rounds.append(index))
	await h.frames(39)
	await h.shot("128_sword_court_volley")
	await wait_lock(h,court,3)
	h.check(rounds == [0,1,2] and player.health.current < player.health.maximum, "Three homing pairs fire in order and cause real damage")
	h.check(not court.swords[3].dangerous() and court.swords[3].aim_seconds >= 0.65, "The royal homing blade retains its own harmless warning")
	await h.shot("129_sword_court_verdict")
	for tick: int in range(170):
		if not is_instance_valid(court.swords[3]) or court.swords[3].phase == RoyalSword.Phase.IMPACT:
			break
		await h.frames(1)
	await h.shot("131_sword_court_royal_impact")
	var state_before := boss.state
	var animation_before := boss.sprite.animation
	await finish(h,court)
	h.check(rounds == [0,1,2,3] and boss.state == state_before and boss.sprite.animation == animation_before, "Ending the court never forces a recovery or interrupts the king")
	h.check(boss.court_cooldown_left >= 9.9 and boss.sword_court == null, "The finished independent court clears its reference and starts cooldown")
	boss.court_cooldown_left = 0
	h.check(boss._choose_attack() != HollowWarden.Attack.CHARGED, "A new court still requires two intervening ordinary attacks")
	# Steering is measured against the live target while airborne, with a turn cap.
	player.revive(Vector2(160,480))
	var tracking_config := boss.config.court.duplicate() as SwordCourtConfig
	var tracking_hits: Array[int] = []
	var tracking := test_sword(game,tracking_config,Vector2(320,190),Vector2(160,458),tracking_hits)
	tracking.target = player
	await h.frames(4)
	player.revive(Vector2(480,480))
	var direction_before := tracking.direction
	var expected_turn := tracking.direction.angle_to(tracking.global_position.direction_to(player.global_position+tracking_config.aim_offset))
	await h.frames(1)
	var actual_turn := direction_before.angle_to(tracking.direction)
	h.check(signf(actual_turn) == signf(expected_turn) and absf(actual_turn) > 0.005 and absf(actual_turn) <= tracking_config.turn_speed/60.0+0.002, "A flying sword truly tracks a moved player without exceeding its turn limit")
	get_tree().paused = true
	var flight_at := tracking.position
	var flight_angle := tracking.rotation
	await h.frames(8)
	h.check(tracking.position == flight_at and tracking.rotation == flight_angle, "Pause freezes homing flight and blade rotation")
	get_tree().paused = false
	tracking.retire()
	# Actual running and a timed jump evade curved flights at both boundaries.
	for edge: float in [86.0,570.0]:
		boss = await prepare(h,game,Vector2(edge,480))
		boss.position.x = 448 if edge < 320 else 180
		court = boss.sword_court
		await wait_lock(h,court,0)
		boss.set_physics_process(false)
		Input.action_press("move_right" if edge < 320 else "move_left")
		await h.frames(32)
		Input.action_press("jump")
		await h.frames(20)
		Input.action_release("jump")
		await h.frames(12)
		Input.action_release("move_right")
		Input.action_release("move_left")
		for tick: int in range(160):
			if court.round_index > 0:
				break
			await h.frames(1)
		h.check(game.player.health.current == game.player.health.maximum, "Real inward run and jump evade homing from arena edge " + str(edge))
	# Isolated high-speed casts verify shape sweeping, ward grouping and cover.
	game.start_boss_challenge(1)
	await h.frames(4)
	boss = game.room.get_node("Enemies/Warden")
	boss.set_physics_process(false)
	player = game.player
	player.revive(Vector2(250,480))
	await h.frames(3)
	var settings := boss.config.court.duplicate() as SwordCourtConfig
	settings.sword_speed = 18000
	var handled: Array[int] = []
	var sword := test_sword(game,settings,player.position+Vector2(0,-100),player.position+Vector2(0,-22),handled)
	await h.frames(2)
	h.check(player.health.current == player.health.maximum-1 and sword.phase == RoyalSword.Phase.IMPACT, "Swept sword crosses over 250px per tick and still hits the real hurtbox once")
	var damage_hp := player.health.current
	await h.frames(35)
	h.check(not is_instance_valid(sword) and player.health.current == damage_hp, "Impact and vanish animations are harmless and expire")
	player.revive(Vector2(250,480))
	await h.frames(3)
	if "steam_ward" not in Session.abilities:
		Session.abilities.append("steam_ward")
	await h.press("steam_ward",1)
	h.check(player.steam_ward.active_left > 0, "Optional ward is armed before the paired-sword collision")
	handled = []
	var first := test_sword(game,settings,player.position+Vector2(-3,-100),player.position+Vector2(0,-22),handled)
	var second := test_sword(game,settings,player.position+Vector2(3,-100),player.position+Vector2(0,-22),handled)
	await h.frames(2)
	h.check(handled.size() == 1 and player.health.current == player.health.maximum and player.steam_ward.active_left == 0 and first.phase == RoyalSword.Phase.IMPACT and second.phase == RoyalSword.Phase.IMPACT, "One ward blocks a whole sword pair, with no second-blade damage")
	await h.frames(35)
	handled = []
	test_sword(game,settings,player.position+Vector2(0,-100),player.position+Vector2(0,-22),handled)
	await h.frames(2)
	h.check(player.health.current == player.health.maximum-1, "The next distinct sword volley can damage after the shield was used")
	await h.frames(35)
	player.revive(Vector2(300,480))
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,160)
	shape.shape = rectangle
	wall.add_child(shape)
	game.room.add_child(wall)
	wall.position = Vector2(260,420)
	await h.frames(3)
	handled = []
	sword = test_sword(game,settings,Vector2(200,458),Vector2(300,458),handled)
	await h.frames(2)
	h.check(player.health.current == player.health.maximum and sword.phase == RoyalSword.Phase.IMPACT and sword.position.x <= 262, "A two-pixel wall stops a fast sword before the player")
	boss = await prepare(h,game)
	court = boss.sword_court
	game.player.health.take_damage(99,game.player.position)
	h.check(court.phase == SwordCourt.Phase.FINISHED and court.swords.all(func(s: RoyalSword) -> bool: return not s.dangerous() and not s.visible), "Player death cancels every pending and flying sword immediately")
	await h.frames(65)
	h.check(game.room.get_node("Enemies/Warden").sword_court == null, "Challenge retry contains no old court")
	boss = await prepare(h,game)
	court = boss.sword_court
	await wait_lock(h,court,0) # The charge shield has now ended.
	boss.get_node("Hurtbox").receive_hit(99,boss.position)
	h.check(court.phase == SwordCourt.Phase.FINISHED and not court.visible, "King death clears the sword court before the victory menu")
	boss = await prepare(h,game)
	player = game.player
	court = boss.sword_court
	player.health.current = 1
	await wait_lock(h,court,0)
	for tick: int in range(120):
		if player.state == Player.State.DEAD:
			break
		await h.frames(1)
	h.check(player.state == Player.State.DEAD and (not is_instance_valid(court) or court.phase == SwordCourt.Phase.FINISHED), "A lethal real sword hit cancels its own cast without reviving impact visuals")
	boss = await prepare(h,game)
	court = boss.sword_court
	game.start_boss_challenge(2)
	await h.frames(3)
	h.check(not is_instance_valid(court), "Changing boss rooms frees the entire sword court")
	game.return_to_title()
	await h.frames(3)
