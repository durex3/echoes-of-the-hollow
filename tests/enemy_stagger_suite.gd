extends "res://tests/bell_court_suite.gd"
const MOBS := ["slime","living_armor","doom_scribe","rose_sentinel","winged_chest","bell_invoker","bell_skimmer"]
const SCENES := {
	"slime": preload("res://features/enemies/slime.tscn"),
	"living_armor": preload("res://features/enemies/living_armor.tscn"),
	"doom_scribe": preload("res://features/enemies/doom_scribe.tscn"),
	"rose_sentinel": preload("res://features/enemies/rose_sentinel.tscn"),
	"winged_chest": preload("res://features/enemies/winged_chest.tscn"),
	"bell_invoker": preload("res://features/enemies/bell_invoker.tscn"),
	"bell_skimmer": preload("res://features/enemies/bell_skimmer.tscn"),
}

func spawn_mob(kind: String) -> CharacterBody2D:
	var enemy := (SCENES[kind] as PackedScene).instantiate() as CharacterBody2D
	enemy.position = Vector2(360,300 if kind=="bell_skimmer" else 320)
	arena.add_child(enemy)
	return enemy

func clock_value(enemy: Node) -> float:
	return enemy.elapsed if enemy is BellInvoker or enemy is BellSkimmer else enemy.timer

func is_attacking(enemy: Node) -> bool:
	if enemy is RoseSentinel:
		return enemy.state==RoseSentinel.State.STRIKE
	if enemy is WingedChest:
		return enemy.state==WingedChest.State.LUNGE
	return enemy.state==BellInvoker.State.ACTIVE

func run() -> void:
	await component_checks()
	await recovery_checks()
	for kind: String in ["rose_sentinel","winged_chest","bell_invoker"]:
		await fixture(Vector2(318,320))
		var enemy := spawn_mob(kind)
		await pressure_counter(enemy,kind)
	await native_visuals()
	release()
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(3)
	print("ENEMY_STAGGER_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func component_checks() -> void:
	for kind: String in MOBS:
		await fixture(Vector2(900,320))
		var enemy := spawn_mob(kind)
		await frames(3)
		var maximum: int = enemy.health.maximum
		var hurt := enemy.get_node("Hurtbox") as Hurtbox
		check(hurt.resolve_hit(1,enemy.position-Vector2(40,0))==Hurtbox.HitResult.DAMAGED and enemy.health.current==maximum-1,"First hit damages and reacts normally: "+kind)
		var guard := enemy.get_node("Stagger") as EnemyStagger
		var clock := guard.quiet_left
		get_tree().paused = true
		await frames(6)
		check(guard.quiet_left==clock,"Pause freezes interruption reset: "+kind)
		get_tree().paused = false
		await frames(13) # Beyond the existing 0.16s damage immunity, inside burst gap.
		var state_before: int = enemy.state
		var time_before := clock_value(enemy)
		check(hurt.resolve_hit(1,enemy.position-Vector2(40,0))==Hurtbox.HitResult.DAMAGED and enemy.health.current==maximum-2,"Burst protection never absorbs or reduces the next hit: "+kind)
		if maximum>2:
			check(enemy.state==state_before and is_equal_approx(clock_value(enemy),time_before),"A second surviving hit cannot reset the action clock: "+kind)
		else:
			check(enemy.health.current==0,"Two-HP enemy still dies from two ordinary hits: "+kind)
	await fixture(Vector2(900,320))
	var mage := spawn_mob("bell_invoker") as BellInvoker
	var other := spawn_mob("bell_invoker") as BellInvoker
	other.position.x = 660
	await frames(3)
	var hurt := mage.get_node("Hurtbox") as Hurtbox
	hurt.resolve_hit(1,mage.position-Vector2(40,0))
	check(other.stagger.quiet_left==0 and mage.stagger.config==other.stagger.config,"Interruption memory belongs to each instance, not the shared configuration")
	await frames(50)
	hurt.resolve_hit(1,mage.position-Vector2(40,0))
	check(mage.state==BellInvoker.State.HURT and mage.elapsed==0,"After a quiet gap, a new hit can interrupt normally again")
	await frames(20)
	check(mage.state in [BellInvoker.State.IDLE,BellInvoker.State.APPROACH],"An interrupted mage returns to decisions without an extra full attack recovery")

func recovery_checks() -> void:
	for kind: String in ["living_armor","doom_scribe","rose_sentinel","winged_chest","bell_invoker","bell_skimmer"]:
		await fixture(Vector2(900,320))
		var enemy := spawn_mob(kind)
		await frames(3)
		var recovery: int
		enemy.target = player # A live distant target keeps the normal recovery valid.
		if enemy is LivingArmor:
			recovery = LivingArmor.State.RECOVER
		elif enemy is DoomScribe:
			recovery = DoomScribe.State.RECOVER
		elif enemy is RoseSentinel:
			recovery = RoseSentinel.State.RECOVER
		elif enemy is WingedChest:
			recovery = WingedChest.State.RECOVER
		elif enemy is BellInvoker:
			recovery = BellInvoker.State.RECOVER
		else:
			recovery = BellSkimmer.State.RECOVER
		enemy._enter(recovery) # Explicit recovery-boundary fixture, no route mutation.
		await frames(3)
		(enemy.get_node("Hurtbox") as Hurtbox).resolve_hit(1,enemy.position-Vector2(40,0))
		await frames(20)
		check(enemy.state==recovery,"Hitting a recovery cannot shorten the original counterattack window: "+kind)

func pressure_counter(enemy: Node, label: String, capture := false) -> void:
	var maximum: int = enemy.health.maximum
	var hits := 0
	var saw_counter := false
	var saw_persistent_warning := false
	for tick: int in range(300):
		if not is_instance_valid(enemy) or enemy.health.current<=0 or player.health.current<=0:
			break
		var difference: float = enemy.position.x-player.position.x
		var minimum := 37.0
		var maximum_gap := minimum+10.0
		hold("move_right",difference>maximum_gap)
		hold("move_left",difference<minimum)
		hold("attack",hits<maximum-1 and tick%24<2)
		var before: int = enemy.health.current
		await frames()
		if enemy.health.current<before:
			hits += before-enemy.health.current
			enemy.target = player
			if hits>=2:
				if enemy is BellInvoker:
					saw_persistent_warning = enemy.state==BellInvoker.State.WARNING
				elif enemy is RoseSentinel:
					saw_persistent_warning = enemy.state==RoseSentinel.State.WARNING
				elif enemy is WingedChest:
					saw_persistent_warning = enemy.state==WingedChest.State.WARNING
				if capture and hits==2:
					await shot("stagger_"+label+"_second_hit")
		if hits==maximum-1 and is_attacking(enemy):
			saw_counter = true
			if capture:
				await shot("stagger_"+label+"_counter")
			release()
			for active_tick: int in range(20):
				var hp_before := player.health.current
				await frames()
				if capture and player.health.current<hp_before:
					await shot("stagger_"+label+"_counter_hit")
			break
	release()
	check(hits==maximum-1 and saw_persistent_warning,"Real repeated sword presses damage without repeatedly cancelling warning: "+label)
	check(saw_counter and enemy.health.current==1,"Surviving enemy completes a normal telegraphed counter after the sword burst: "+label)
	check(player.health.current<player.health.maximum,"Counter uses actual player damage resolution: "+label)
	print("STAGGER_COUNTER: ",label," hits=",hits," enemy_hp=",enemy.health.current," player_hp=",player.health.current)

func native_visuals() -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	arena.queue_free()
	await frames(2)
	game = preload("res://features/world/prototypes/bell_court_preview.tscn").instantiate()
	add_child(game)
	await frames(4)
	player = game.player
	game.load_room("bell_guard_walk","entry")
	var mage := game.room.get_node("Enemies/FirstInvoker") as BellInvoker
	mage.target = null
	player.revive(mage.position-Vector2(42,0))
	game.notice.text = ""
	await pressure_counter(mage,"native_mage",true)
