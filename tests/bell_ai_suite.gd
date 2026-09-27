extends "res://tests/bell_court_suite.gd"
## Isolated decision fixtures. Route HP and enemy configurations are never changed.

func run() -> void:
	await mage_decisions()
	await mage_boundaries()
	await bird_decisions()
	await bird_boundaries()
	await native_ai_visuals()
	release()
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(3)
	print("BELL_AI_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func mage_decisions() -> void:
	await fixture(Vector2(500,320))
	var caster := invoker()
	caster.ranged_left = 2.0
	await frames(30)
	check(absf(caster.position.x-360)<1 and caster.state==BellInvoker.State.IDLE,"Cooling caster holds ranged spacing instead of marching into a sword")
	await fixture(Vector2(400,320))
	caster = invoker()
	for tick: int in range(100):
		await frames()
		if caster.state==BellInvoker.State.RECOVER:
			break
	check(caster.completed_casts==1 and caster.state==BellInvoker.State.RECOVER,"First close cast completes before considering an evasive step")
	var origin := caster.position
	await frames(50)
	check(caster.state==BellInvoker.State.RECOVER and caster.position.distance_to(origin)<1,"Closing player cannot cancel the mage's full counterattack window")
	# The close arc now genuinely hits: walk back after its knockback before
	# asking the AI to respond to close pressure. Do not undo the damage.
	for tick: int in range(24):
		if player.position.x-caster.position.x<=42:
			break
		hold("move_left",true)
		await frames()
	release()
	for tick: int in range(40):
		await frames()
		if caster.state==BellInvoker.State.RETREAT:
			break
	check(caster.state==BellInvoker.State.RETREAT,"After recovery a nearby player triggers a short retreat")
	var direction := caster.retreat_direction
	var remaining := caster.retreat_left
	get_tree().paused = true
	await frames(8)
	check(caster.retreat_left==remaining and caster.position.distance_to(origin)<1,"Pause freezes retreat movement and cooldown")
	get_tree().paused = false
	player.position.x = 260 # Crossing behind during the committed retreat.
	await frames(30)
	check(caster.retreat_direction==direction and caster.position.x<origin.x-30 and caster.position.x>origin.x-46,"Retreat keeps its chosen direction and ends within forty-five pixels")
	var retreat_count := 0
	for tick: int in range(85):
		await frames()
		if caster.state==BellInvoker.State.RETREAT:
			retreat_count += 1
	check(retreat_count==0,"Retreat cooldown prevents repeated instant backpedaling")
	await fixture(Vector2(500,320))
	caster = invoker()
	caster.ranged_casts = 1 # Explicit later-cast fixture, no prior damage injection.
	await frames(4)
	check(caster.ranged_cast and caster.cast_variant==1,"Later cast punishes a stationary grounded target with a ground seal")
	var locked: Vector2 = caster.spell.locked_position
	hold("move_right",true)
	await frames(12)
	release()
	check(caster.cast_variant==1 and caster.spell.locked_position==locked,"Changing movement during windup cannot retarget the chosen ground seal")
	await fixture(Vector2(480,320))
	hold("move_right",true)
	await frames(8)
	caster = invoker()
	caster.ranged_casts = 1
	await frames(4)
	release()
	check(caster.ranged_cast and caster.cast_variant==0,"Moving grounded target prompts a travelling wave instead of a fixed rotation")
	await fixture(Vector2(500,320))
	caster = invoker()
	caster.next_spell = 0
	await frames(4)
	check(caster.cast_variant==0,"Authored first wave remains the opening lesson against a stationary player")
	await fixture(Vector2(500,320))
	caster = invoker()
	caster.ranged_casts = 2
	caster.last_spell = 1
	caster.spell_repeats = 2
	await frames(4)
	check(caster.cast_variant==0,"Two repeated ground seals prompt a different grounded tactic")

func mage_boundaries() -> void:
	await fixture(Vector2(500,320))
	var caster := invoker()
	caster.target = null
	await frames(3)
	check(caster._safe_step(-1) and caster._safe_step(1),"Mage can use either clear side on open ground")
	box(Vector2(391,280),Vector2(8,80))
	await frames(2)
	check(not caster._safe_step(1) and caster._safe_step(-1),"Mage rejects a blocked side but can step away from its wall")
	caster.home.x = caster.position.x-caster.config.leash_distance
	check(not caster._safe_step(1),"Mage cannot chase outside its home leash")
	await fixture(Vector2(300,320))
	# Replace only the isolated fixture floor with a short ledge.
	arena.get_child(0).queue_free()
	box(Vector2(280,336),Vector2(200,32))
	caster = invoker()
	caster.target = null
	await frames(4)
	check(not caster._safe_step(1) and caster._safe_step(-1),"Mage checks real ground before retreating at a cliff")
	await fixture(Vector2(570,320))
	caster = invoker()
	caster.ranged_left = 10
	await frames(12)
	check(caster.position.x>366,"Distant visible player still draws the caster forward")
	player.position.x = 950
	await frames(110)
	check(absf(caster.position.x-caster.home.x)<10 and caster.state==BellInvoker.State.IDLE,"Lost target produces a short search then return, without blind attacks")

func bird_decisions() -> void:
	await fixture(Vector2(410,272))
	var bird := skimmer()
	await frames(3)
	check(bird.state==BellSkimmer.State.REPOSITION,"Close airborne player prompts lateral space instead of body chasing")
	var goal := bird.reposition_goal
	var origin := bird.position
	var cooldown := bird.reposition_left
	get_tree().paused = true
	await frames(8)
	check(bird.position==origin and bird.reposition_left==cooldown,"Pause freezes the bird's reposition and its cooldown")
	get_tree().paused = false
	player.position.x = 250
	await frames(12)
	check(bird.reposition_goal==goal and bird.position.y==origin.y,"Bird commits its lateral waypoint without tracking or gaining height")
	await frames(52)
	check(bird.state!=BellSkimmer.State.REPOSITION and bird.position.distance_to(origin)<=bird.config.reposition_distance+1,"Bird's evasive movement is short and time bounded")
	await fixture(Vector2(410,320))
	bird = skimmer()
	bird.consecutive_dives = 2
	await frames(3)
	check(bird.state==BellSkimmer.State.REPOSITION,"After two dives the bird seeks spacing for its ranged tactic")
	await frames(65)
	check(bird.state==BellSkimmer.State.SCREECH_WARNING and bird.consecutive_dives==0,"Successful reposition leads to a readable screech, not endless evasion")
	await fixture(Vector2(400,320))
	bird = skimmer()
	await frames(5)
	check(bird.state==BellSkimmer.State.WARNING,"First grounded close encounter still teaches the dive")
	for tick: int in range(95):
		await frames()
		if bird.state==BellSkimmer.State.RECOVER:
			break
	var low := bird.position
	player.position = low+Vector2(42,0)
	await frames(50)
	check(bird.state==BellSkimmer.State.RECOVER and bird.position==low,"Airborne proximity cannot cancel the low dive recovery punish window")

func bird_boundaries() -> void:
	await fixture(Vector2(400,320))
	var bird := skimmer()
	bird.target = null
	await frames(2)
	box(Vector2(385,260),Vector2(4,4))
	await frames(2)
	var destination := Vector2(400,302)
	var ray := PhysicsRayQueryParameters2D.create(bird.position,destination,1)
	check(bird.get_world_2d().direct_space_state.intersect_ray(ray).is_empty() and not bird._flight_clear(destination),"Body-width dive sweep rejects a shoulder obstacle missed by a center ray")
	bird.target = player
	await frames(6)
	check(bird.state==BellSkimmer.State.HOVER,"Blocked dive path does not launch the bird into an obstacle")
	await fixture(Vector2(410,272))
	box(Vector2(333,248),Vector2(8,110))
	bird = skimmer()
	await frames(3)
	check(bird.state==BellSkimmer.State.HOVER and absf(bird.position.x-360)<1,"Blocked escape path leaves the bird approachable rather than pushing through a wall")
	check(not bird._flight_clear(bird.home+Vector2(bird.config.leash_distance+1,0)),"Flying pursuit respects the home leash")
	await fixture(Vector2(520,320))
	box(Vector2(430,240),Vector2(8,160))
	bird = skimmer()
	await frames(110)
	check(bird.state==BellSkimmer.State.HOVER and bird.pulses.is_empty() and player.health.current==5,"Hidden target causes no blind screech or movement through a wall")

func native_ai_visuals() -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	release()
	arena.queue_free()
	await frames(2)
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	player = game.player
	game.load_room("bell_guard_walk","entry")
	player.revive(Vector2(488,704))
	var caster := game.room.get_node("Enemies/FirstInvoker") as BellInvoker
	for tick: int in range(180):
		hold("move_left",caster.state==BellInvoker.State.RECOVER and player.position.x-caster.position.x>42)
		await frames()
		if caster.state==BellInvoker.State.RETREAT and caster.elapsed>0.15:
			break
	release()
	check(caster.state==BellInvoker.State.RETREAT,"Native guard walk shows the post-recovery retreat")
	game.notice.text = ""
	await shot("bell_ai_mage_retreat")
	game.load_room("hanging_gallery","entry")
	player.revive(Vector2(802,272))
	var bird := game.room.get_node("Enemies/FirstSkimmer") as BellSkimmer
	# Explicit visual placement must settle the player's old floor-contact cache.
	bird.target = null
	await frames(2)
	bird.target = player
	await frames(10)
	check(bird.state==BellSkimmer.State.REPOSITION,"Native gallery shows the airborne spacing decision")
	game.notice.text = ""
	await shot("bell_ai_bird_reposition")
