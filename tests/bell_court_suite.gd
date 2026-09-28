extends Node
## Component fixtures are explicitly placed; the final route uses only InputMap.
var checks := 0
var failures: Array[String] = []
var arena: Node2D
var player: Player
var game: Node2D
var route_deaths := 0
var route_hits := 0
var route_ticks := 0
var wall_jumps := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.save_path = "user://test_bell_suite_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_bell_suite_%s.cfg" % OS.get_process_id()
	Session.bindings.apply({})
	get_tree().create_timer(180.0,true,false,true).timeout.connect(func() -> void:
		push_error("Bell court suite timed out; incomplete runs cannot pass.")
		get_tree().quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:
		failures.append(message)

func frames(count := 1) -> void:
	for tick: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame
		route_ticks += 1

func hold(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func release() -> void:
	for action: String in ["move_left","move_right","jump","attack","dash","steam_ward","interact"]:
		Input.action_release(action)

func box(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)

func fixture(at := Vector2(300,320)) -> void:
	release()
	if is_instance_valid(arena):
		arena.queue_free()
		await frames(2)
	Session.reset()
	Session.abilities.assign(["double_jump","dash","steam_ward"])
	arena = Node2D.new()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	box(Vector2(600,336),Vector2(1400,32))
	player = preload("res://features/player/player.tscn").instantiate()
	player.position = at
	arena.add_child(player)
	await frames(4)

func invoker(at := Vector2(360,320)) -> BellInvoker:
	var enemy := preload("res://features/enemies/bell_invoker.tscn").instantiate() as BellInvoker
	enemy.position = at
	arena.add_child(enemy)
	enemy.target = player
	return enemy

func skimmer(at := Vector2(360,248)) -> BellSkimmer:
	var enemy := preload("res://features/enemies/bell_skimmer.tscn").instantiate() as BellSkimmer
	enemy.position = at
	arena.add_child(enemy)
	enemy.target = player
	return enemy

func shot(name_text: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	var was_paused := get_tree().paused
	get_tree().paused = true
	# An obscured/minimized test window may stop normal frame_post_draw emission.
	# Force one real render rather than waiting indefinitely or saving an old frame.
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var result := get_viewport().get_texture().get_image().save_png("res://artifacts/"+name_text+".png")
	get_tree().paused = was_paused
	check(result == OK,"Saved native screenshot " + name_text)

func run() -> void:
	await invoker_checks()
	await ranged_skill_checks()
	await skimmer_checks()
	await screech_checks()
	await slab_checks()
	await authored_route()
	await feedback_checks()
	await visual_encounters()
	release()
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(3)
	print("BELL_COURT_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func invoker_checks() -> void:
	for side: float in [-1.0,1.0]:
		for variant: int in range(2):
			await fixture(Vector2(360+side*60,320))
			var caster := invoker()
			caster.next_variant = variant
			await frames(92)
			check(player.health.current == 4,"Actual spell arc hits once in variant %d facing %s" % [variant,side])
			check(not caster.strike.active,"Spell damage closes after the visible release")
	await fixture()
	var enemy := invoker()
	await frames(6)
	check(enemy.state == BellInvoker.State.WARNING and enemy.cast_variant == 0,"Invoker teaches rising arc first")
	var locked_facing := enemy.facing
	player.position.x = 400 # Fixture probes crossing behind a committed cast.
	await frames(8)
	check(enemy.facing == locked_facing and not enemy.strike.active,"Invoker locks facing and warning is harmless")
	var elapsed := enemy.elapsed
	get_tree().paused = true
	await frames(8)
	check(enemy.elapsed == elapsed,"Pause freezes the new enemy gameplay clock")
	get_tree().paused = false
	var saw_active := false
	var saw_curl := false
	var saw_recover := false
	for tick: int in range(260):
		await frames()
		if enemy.state == BellInvoker.State.ACTIVE:
			saw_active = true
			check(enemy.sprite.frame >= (3 if enemy.cast_variant == 0 else 4) and enemy.strike.active,"Damage occurs only on the displayed solid spell frames")
			# One observation per cast, then skip over the remaining active frames.
			await frames(22)
		saw_recover = saw_recover or enemy.state == BellInvoker.State.RECOVER
		if enemy.state == BellInvoker.State.WARNING and enemy.cast_variant == 1:
			saw_curl = true
			break
	check(saw_active and saw_recover and saw_curl,"Two distinct casts alternate with a complete recovery")
	# Real player attack, not direct enemy health subtraction.
	player.position = enemy.position + Vector2(38,0)
	Input.action_press("move_left")
	await frames(1)
	release()
	Input.action_press("attack")
	await frames(12)
	release()
	check(enemy.health.current == 3 and enemy.state == BellInvoker.State.HURT and not enemy.strike.active,"Actual sword interrupts warning and cancels the spell")
	await fixture(Vector2(360,320))
	enemy = invoker()
	player.steam_ward.activate()
	await frames(12)
	check(player.health.current == 5 and player.steam_ward.active_left == 0,"Body overlap uses actual shield damage resolution")
	await frames(112)
	check(player.health.current == 5,"One blocked cast cannot deal follow-up contact damage while overlapping")
	# The caster can now take a bounded retreat before its next independent cast.
	for tick: int in range(180):
		if player.health.current < 5:
			break
		await frames()
	check(player.health.current < 5,"Next independent enemy attack can hurt after the ward was spent")
	await fixture(Vector2(300,320))
	box(Vector2(330,240),Vector2(8,160))
	enemy = invoker()
	await frames(100)
	check(enemy.state == BellInvoker.State.IDLE and player.health.current == 5,"Thin world wall blocks detection and spell damage")
	# Body contact without a target still damages, once per continuous contact.
	await fixture(Vector2(360,320))
	enemy = invoker()
	enemy.target = null
	await frames(90)
	check(player.health.current == 4,"Idle body contact is damage, not physical blocking")
	check(enemy.health.maximum == 4 and is_equal_approx(enemy.sprite.scale.x,1) and enemy.sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Invoker grows forty percent with nearest sampling and retains four HP")
	# Character queries must not extend to the atlas's transparent 250px corners.
	await fixture(Vector2(490,320))
	enemy = invoker()
	enemy.set_physics_process(false)
	var polygon := PackedVector2Array()
	for source: Vector2 in enemy.config.curling_shapes[0]:
		polygon.append((source-Vector2(125,167))*enemy.config.sprite_scale)
	enemy.strike.strike(polygon,1)
	check(player.health.current==5,"Transparent atlas margins never become an attack rectangle")

func ranged_skill_checks() -> void:
	for side: float in [-1.0,1.0]:
		await fixture(Vector2(360+side*180,320))
		var caster := invoker()
		await frames(8)
		check(caster.ranged_cast and is_instance_valid(caster.spell) and not caster.spell.released,"Distant player triggers a harmless charged toll %s" % side)
		await frames(116)
		check(player.health.current==4,"Travelling toll damages through the real hurt chain once %s" % side)
		await fixture(Vector2(360+side*180,320))
		caster = invoker()
		caster.next_spell = 1
		await frames(8)
		var seal: Node2D = caster.spell
		var locked := seal.global_position
		player.position.x += side*64 # Explicit old-position lock fixture.
		await frames(60)
		check(is_instance_valid(seal) and seal.released and seal.global_position==locked and player.health.current==5,"Ground seal stays at the old floor position and movement evades it %s" % side)
	await fixture(Vector2(540,320))
	var caster := invoker()
	caster.next_spell = 1
	await frames(56)
	player.steam_ward.activate()
	await frames(30)
	check(player.health.current==5 and player.steam_ward.active_left==0,"One shield consumes the ground eruption with no overlap follow-up damage")
	await fixture(Vector2(540,320))
	caster = invoker()
	caster.next_spell = 1
	await frames(74)
	check(player.health.current==4,"Ignoring the grounded seal causes one real hit")
	await fixture(Vector2(540,320))
	caster = invoker()
	await frames(8)
	box(Vector2(432,272),Vector2(4,96)) # Added after targeting, before release.
	await frames(118)
	check(player.health.current==5 and not is_instance_valid(caster.spell),"Travelling spell dies at a thin wall instead of tunnelling through")
	await fixture(Vector2(540,320))
	caster = invoker()
	await frames(8)
	var seal: Node2D = caster.spell
	var age: float = seal.elapsed
	get_tree().paused = true
	await frames(12)
	check(seal.elapsed==age,"Pause freezes spell preparation and travel")
	get_tree().paused = false
	player.position = caster.position+Vector2(38,0)
	hold("move_left",true)
	await frames()
	release()
	hold("attack",true)
	for tick: int in range(18):
		await frames()
		if caster.health.current<4:
			break
	release()
	check(caster.health.current==3 and caster.flash_left>0 and not is_instance_valid(caster.spell),"Actual sword flashes the caster and cancels the ranged skill before release")
	Session.reduce_flashes = true
	await frames()
	check(caster.sprite.modulate==Color.WHITE,"Reduced flashes suppresses the new enemy flash, keeping the hurt clip")
	Session.reduce_flashes = false
	await fixture(Vector2(540,320))
	caster = invoker()
	await frames(85)
	hold("jump",true)
	await frames(30)
	release()
	check(player.health.current==5,"A real timed jump clears the travelling toll without a shield")

func feedback_checks() -> void:
	game.cleared_rooms.clear()
	game.load_room("bell_guard_walk","entry")
	player.revive(Vector2(486,704))
	var caster := game.room.get_node("Enemies/FirstInvoker") as BellInvoker
	await frames(3)
	var count: int = game.get_node("Feedback").impacts
	hold("move_left",true)
	await frames()
	release()
	hold("attack",true)
	for tick: int in range(18):
		await frames()
		if caster.health.current<4:
			break
	release()
	check(game.get_node("Feedback").impacts==count+1 and caster.state==BellInvoker.State.HURT,"Preview actual sword dispatches one visible impact and the enemy hurt clip")
	game.notice.text = ""
	await shot("bell_hit_feedback")
	game.load_room("broken_bell_atrium","checkpoint")
	await frames(2)
	check(game.get_node("Feedback").get_child_count()==0 and game.camera.offset==Vector2.ZERO,"Room switch clears impact particles and camera shake")

func skimmer_checks() -> void:
	await fixture()
	var enemy := skimmer()
	await frames(8)
	check(enemy.state == BellSkimmer.State.WARNING,"Bat folds its wings before the first dive")
	var locked := enemy.locked_position
	player.position.x = 440
	await frames(50)
	check(enemy.locked_position == locked,"Bat does not retarget after locking the player's old position")
	for tick: int in range(40):
		if enemy.state == BellSkimmer.State.RECOVER:
			break
		await frames()
	check(enemy.state == BellSkimmer.State.RECOVER and absf(enemy.position.y-(320-18)) < 8,"Bat finishes at a low, reachable counterattack height")
	var origin := enemy.position
	await frames(45)
	check(enemy.position.distance_to(origin)<1 and enemy.state == BellSkimmer.State.RECOVER,"Bat stays vulnerable throughout its low recovery window")
	player.position = enemy.position + Vector2(38,18)
	Input.action_press("move_left")
	await frames(1)
	release()
	Input.action_press("attack")
	await frames(12)
	release()
	check(enemy.health.current == 1,"Grounded sword reaches the bat during recovery")
	await frames(24)
	Input.action_press("attack")
	await frames(13)
	release()
	check(enemy.health.current == 0 and not enemy.contact_box.active,"Second real sword hit kills bat and closes all damage")
	await frames(18)
	if is_instance_valid(enemy):
		check(enemy.state in [BellSkimmer.State.FALLING,BellSkimmer.State.DEAD],"Bat uses fall then real-ground death states")
	await fixture(Vector2(360,320))
	enemy = skimmer(Vector2(360,320))
	enemy.target = null
	player.steam_ward.activate()
	await frames(80)
	check(player.health.current == 5 and player.steam_ward.active_left == 0,"Bat body also consumes ward once without repeated overlap damage")
	await fixture(Vector2(300,320))
	enemy = skimmer()
	await frames(5)
	player.health.take_damage(5,player.position)
	await frames(65)
	check(enemy.state not in [BellSkimmer.State.WARNING,BellSkimmer.State.DIVE] and not enemy.strike.active,"Player death cancels the pending bat dive")

func screech_checks() -> void:
	for side: float in [-1.0,1.0]:
		await fixture(Vector2(360+side*160,320))
		var bird := skimmer()
		await frames(8)
		check(bird.state==BellSkimmer.State.SCREECH_WARNING and bird.pulses.is_empty(),"Distant flying enemy prepares its screech without premature damage %s" % side)
		await frames(132)
		check(player.health.current==4,"Actual sound fan damages a stationary player once %s" % side)
	await fixture(Vector2(520,320))
	var bird := skimmer()
	await frames(10)
	var aim := bird.locked_aim
	var elapsed := bird.elapsed
	get_tree().paused = true
	await frames(8)
	check(bird.elapsed==elapsed and bird.pulses.is_empty(),"Pause freezes screech preparation")
	get_tree().paused = false
	player.position = Vector2(520,224) # Explicit target-lock fixture.
	await frames(57)
	check(bird.locked_aim==aim and bird.pulses.size()==3 and bird.pulses[1].direction.is_equal_approx(aim),"Screech releases three fixed directions without retargeting a moved player")
	var pulse := bird.pulses[1]
	var location := pulse.global_position
	get_tree().paused = true
	await frames(6)
	check(pulse.global_position==location,"Pause also freezes released sound blades")
	get_tree().paused = false
	await fixture(Vector2(452,320))
	bird = skimmer()
	await frames(78)
	player.steam_ward.activate()
	await frames(48)
	check(player.health.current==5 and player.steam_ward.active_left==0,"One shield blocks the whole fan without a second blade bypassing defense")
	await fixture(Vector2(520,320))
	bird = skimmer()
	await frames(8)
	box(Vector2(415,240),Vector2(4,160))
	await frames(140)
	check(player.health.current==5 and not bird._has_pulses(),"A thin solid wall blocks every sound blade")
	await fixture(Vector2(520,320))
	bird = skimmer()
	await frames(8)
	player.position = Vector2(398,266)
	hold("move_left",true)
	await frames()
	release()
	hold("attack",true)
	for tick: int in range(18):
		await frames()
		if bird.health.current<2:
			break
	release()
	check(bird.health.current==1 and bird.state==BellSkimmer.State.HURT and bird.pulses.is_empty(),"Real sword interrupts screech preparation")
	await fixture(Vector2(520,320))
	bird = skimmer()
	await frames(70)
	check(bird._has_pulses(),"Death cleanup fixture starts with real flying sound blades")
	bird.health.take_damage(2,player.position)
	await frames(2)
	check(not bird._has_pulses(),"Killing the flying caster cancels its released blades")
	await fixture(Vector2(520,320))
	bird = skimmer()
	await frames(90)
	hold("jump",true)
	await frames(38)
	release()
	check(player.health.current==5,"A real timed jump escapes the locked sound fan")

func slab_checks() -> void:
	await fixture(Vector2(360,320))
	var slab := preload("res://features/world/resonant_slab.tscn").instantiate() as ResonantSlab
	slab.position = Vector2(360,320)
	arena.add_child(slab)
	await frames(8)
	check(slab.state == ResonantSlab.State.WARNING and player.health.current == 5,"Pressure starts a harmless warning, not an automatic periodic eruption")
	player.steam_ward.activate()
	await frames(65)
	check(player.health.current == 5 and player.steam_ward.active_left == 0,"Four visible stone teeth share one shield-deduplicated pulse")
	await frames(180)
	check(player.health.current == 5 and slab.state == ResonantSlab.State.IDLE,"Standing still never rearms a pressure slab indefinitely")
	player.position.x = 480
	await frames(6)
	player.position.x = 360
	await frames(90)
	check(player.health.current == 4,"Leaving and stepping again starts a new damaging pulse")
	await fixture(Vector2(360,240))
	slab = preload("res://features/world/resonant_slab.tscn").instantiate()
	slab.position = Vector2(360,320)
	arena.add_child(slab)
	box(Vector2(360,260),Vector2(96,16))
	await frames(80)
	check(player.health.current == 5 and slab.state == ResonantSlab.State.IDLE,"Standing on a platform above the slab does not trigger it")

func walk_to(at: Vector2, max_ticks := 480) -> bool:
	for tick: int in range(max_ticks):
		if route_deaths > 0:
			return false
		var dx := at.x-player.position.x
		if absf(dx)<6 and absf(at.y-player.position.y)<5 and player.is_on_floor():
			release()
			await frames(5)
			return true
		hold("move_left",dx < -5)
		hold("move_right",dx > 5)
		if player.is_on_floor() and at.y < player.position.y-35:
			hold("jump",true)
		elif tick%40 == 25:
			hold("jump",false)
		await frames()
	release()
	print("ROUTE_WALK_BLOCKED: ",at," actual=",player.position)
	return false

func use(id: String) -> bool:
	var point := game.room.get_node("Interactions/"+id) as WorldInteraction
	if not await walk_to(point.position):
		return false
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(5)
	return true

func fight(enemy: Node2D) -> bool:
	for tick: int in range(2400):
		if route_deaths > 0:
			return false
		if not is_instance_valid(enemy) or enemy.health.current <= 0:
			release()
			await frames(40)
			return true
		var side := -1.0 if player.position.x < enemy.position.x else 1.0
		var punish: bool
		var desired: float
		if enemy is BellInvoker:
			punish = enemy.state in [BellInvoker.State.RECOVER,BellInvoker.State.HURT]
			desired = enemy.position.x+side*(38 if punish else 112)
			if enemy.state in [BellInvoker.State.IDLE,BellInvoker.State.APPROACH]:
				desired = enemy.position.x+side*70
		else:
			punish = enemy.state in [BellSkimmer.State.RECOVER,BellSkimmer.State.HURT]
			desired = enemy.position.x+side*(38 if punish else 100)
			if enemy.state == BellSkimmer.State.HOVER:
				desired = enemy.position.x+side*60
			elif enemy.state in [BellSkimmer.State.WARNING,BellSkimmer.State.DIVE]:
				desired = enemy.locked_position.x+side*100
		var dx := desired-player.position.x
		hold("move_left",dx < -5)
		hold("move_right",dx > 5)
		# Face the enemy on a fresh approach frame before committing a sword swing.
		var in_range := absf(enemy.position.x-player.position.x)<55 and absf(enemy.position.y-player.position.y)<35
		if punish and in_range and player.state == Player.State.MOVE and signf(enemy.position.x-player.position.x) != player.facing:
			hold("move_left",side > 0)
			hold("move_right",side < 0)
		hold("attack",punish and in_range and tick%26<12)
		await frames()
	release()
	print("ROUTE_FIGHT_BLOCKED: ",enemy.name," hp=",enemy.health.current," player=",player.position)
	return false

func climb(top: float, landing_x: float, initial_right: bool) -> bool:
	release()
	hold("move_right",initial_right)
	hold("move_left",not initial_right)
	hold("jump",true)
	var held := 0
	for tick: int in range(480):
		await frames()
		held += 1
		if player.is_on_floor() and absf(player.position.y-top)<3:
			release()
			return true
		if player.position.y < top-18:
			hold("move_left",landing_x<player.position.x)
			hold("move_right",landing_x>player.position.x)
			if absf(landing_x-player.position.x)<10:
				release()
		elif held>=16:
			hold("jump",false)
			if player.wall_echo.can_jump() and not player.jump_held:
				hold("jump",true)
				held = 0
	release()
	print("ROUTE_CLIMB_BLOCKED: ",player.position," top=",top)
	return false

func authored_route() -> void:
	release()
	arena.queue_free()
	await frames(3)
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	player = game.player
	player.died.connect(func() -> void: route_deaths += 1)
	player.health.damaged.connect(func(_amount: int,_origin: Vector2) -> void: route_hits += 1)
	player.wall_echo.jumped.connect(func(_id: StringName) -> void: wall_jumps += 1)
	route_ticks = 0
	await frames(10)
	check(player.health.maximum == (5 if game.baseline else 6),"Preview starts with correct inherited life and old abilities")
	await shot("bell_slice_entry")
	# Walk through the warning, before its pressure pulse. No teleport or shield.
	check(await use("Shrine") and await use("East"),"Real input crosses first taught slab and reaches the exterior walk")
	if not await fight(game.room.get_node("Enemies/FirstInvoker")):
		check(false,"First wizard route fight")
		return
	await shot("bell_slice_guard")
	if not await fight(game.room.get_node("Enemies/SecondInvoker")):
		check(false,"Second wizard route fight")
		return
	check(await use("East") and game.room.room_id == "broken_bell_atrium","Two real wizard victories open the safe hub")
	check(await use("Shrine") and await use("EastLower"),"Hub checkpoint and east door lead into the safe ability lesson")
	check(await use("WallEcho") and "wall_echo" in Session.abilities,"Real interaction acquires wall echo without replacing old abilities")
	check(await walk_to(Vector2(352,640)) and await walk_to(Vector2(480,640)),"Introductory ledge leads beneath the first marked shaft")
	var jumps_before := wall_jumps
	if not await climb(416,368,true):
		check(false,"First short shaft reaches the wide rest platform")
		return
	check(wall_jumps-jumps_before<=4,"First shaft needs at most four wall jumps before resting")
	await shot("bell_slice_rest_ledge")
	check(await walk_to(Vector2(208,416)),"Wide middle platform lets the player reset before the second shaft")
	jumps_before = wall_jumps
	if not await climb(192,328,false):
		check(false,"Second short shaft reaches the upper latch")
		return
	check(wall_jumps-jumps_before<=4,"Second shaft also has at most four wall jumps")
	check(await use("UpperLatch") and "wall_passage_open" in game.preview_flags,"Actual upper interaction opens the physical return gate")
	check(await use("UpperReturn") and game.room.room_id=="broken_bell_atrium" and player.position.y<300,"New return door leads to the previously unreachable hub upper level")
	await shot("bell_slice_upper_hub")
	check(await use("WestUpper") and game.room.room_id=="hanging_gallery","Upper west route connects to the bat teaching wing")
	check(await use("Shrine"),"Bat wing checkpoint records a retry without healing")
	if not await fight(game.room.get_node("Enemies/FirstSkimmer")):
		check(false,"First bat route fight")
		return
	await shot("bell_slice_bat_wing")
	if not await fight(game.room.get_node("Enemies/SecondSkimmer")):
		check(false,"Second bat and known slab route fight")
		return
	check(await use("PreviewEnd") and game.finished,"Full front-half route reaches its honest preview endpoint")
	check(route_deaths==0,"Authored route completes with no deaths or route-time HP injection")
	check(await use("East") and game.room.room_id=="broken_bell_atrium","Gallery return door preserves the upper hub orientation")
	check(await use("EastUpper") and await use("UpperReturn"),"Unlocked upper connection works in both directions")
	check(not FileAccess.file_exists(Session.save_path),"Entire preview route never writes a progress file")
	print("BELL_ROUTE_PASS: %.2fs deaths=%d hits=%d wall_jumps=%d baseline=%s" % [route_ticks/60.0,route_deaths,route_hits,wall_jumps,game.baseline])
	# Post-route lifecycle fixture: checkpoint is a memory-only retry, never healing.
	game.load_room("broken_bell_atrium","checkpoint")
	player.health.take_damage(1,player.position)
	await frames(45)
	var before := player.health.current
	check(await use("Shrine") and player.health.current==before,"Actual repeat checkpoint interaction does not heal")
	player.health.take_damage(player.health.maximum,player.position)
	await frames(8)
	check(game.room.room_id=="broken_bell_atrium" and player.health.current==player.health.maximum,"Death separately restores health at the memory checkpoint")
	check("wall_echo" in Session.abilities and "wall_passage_open" in game.preview_flags,"Death retains the earned ability and opened return route in this preview")

func visual_encounters() -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	# Explicit visual fixtures, separate from the input-driven route above.
	game.cleared_rooms.clear()
	game.load_room("bell_guard_walk","entry")
	player.revive(Vector2(384,704))
	game.room.get_node("Enemies/FirstInvoker").target = null
	await frames(20)
	game.notice.text = ""
	await shot("bell_invoker_larger")
	game.load_room("hanging_gallery","entry")
	player.revive(Vector2(914,320))
	await frames(35)
	game.notice.text = ""
	await shot("bell_screech_warning")
	await frames(48)
	await shot("bell_screech_fan")
	for side: float in [-1.0,1.0]:
		game.load_room("echo_cloister","entry")
		if "wall_echo" not in Session.abilities:
			Session.abilities.append("wall_echo")
		player.revive(Vector2(512+side*40,500))
		hold("move_right",side>0)
		hold("move_left",side<0)
		await frames(18)
		game.notice.text = ""
		check(player.wall_echo.sliding and player.sprite.animation==&"wall_slide","Authored shaft presents wall brace %s" % side)
		await shot("bell_wall_brace_%d" % int(side))
		hold("jump",true)
		await frames(4)
		check(player.sprite.animation==&"wall_push" and not player.effects.wall_dust.is_empty(),"Authored shaft presents push-off and contact dust %s" % side)
		await shot("bell_wall_launch_%d" % int(side))
		release()
	for variant: int in range(2):
		game.cleared_rooms.clear()
		game.load_room("bell_guard_walk","entry")
		player.revive(Vector2(628,704))
		var caster := game.room.get_node("Enemies/FirstInvoker") as BellInvoker
		caster.next_spell = variant
		await frames(35)
		game.notice.text = ""
		await shot("bell_ranged_warning_%d" % variant)
		await frames(35)
		await shot("bell_ranged_active_%d" % variant)
	for side: float in [-1.0,1.0]:
		for variant: int in range(2):
			game.cleared_rooms.clear()
			game.load_room("bell_guard_walk","entry")
			player.revive(Vector2(448+side*70,704))
			var enemy := game.room.get_node("Enemies/FirstInvoker") as BellInvoker
			enemy.next_variant = variant
			await frames(30)
			game.notice.text = ""
			await shot("bell_invoker_warning_%d_%d" % [variant,int(side)])
			for tick: int in range(70):
				if enemy.state==BellInvoker.State.ACTIVE and enemy.elapsed>0.09:
					break
				await frames()
			await shot("bell_invoker_active_%d_%d" % [variant,int(side)])
	game.load_room("hanging_gallery","entry")
	player.revive(Vector2(810,320))
	await frames(34)
	game.notice.text = ""
	await shot("bell_skimmer_warning")
	await frames(25)
	await shot("bell_skimmer_dive")
	await frames(28)
	await shot("bell_skimmer_recovery")
	game.load_room("broken_bell_atrium","checkpoint")
	player.revive(Vector2(512,704))
	await frames(30)
	await shot("bell_court_landmark")
	game.load_room("windworn_steps","entry")
	player.revive(Vector2(480,704))
	await frames(60)
	await shot("bell_slab_active")
