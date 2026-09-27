extends "res://tests/enemy_stagger_suite.gd"

func run() -> void:
	for kind: String in ["rose_sentinel","winged_chest","bell_invoker"]:
		for side: float in [-1.0,1.0]:
			for gap: float in [32.0,42.0,52.0]:
				await fixed_counter(kind,side,gap)
	for side: float in [-1.0,1.0]:
		await fixed_counter("bell_invoker",side,26.0)
		await fixed_counter("bell_invoker",side,42.0,true)
	release()
	if is_instance_valid(arena):
		arena.queue_free()
	await frames(3)
	Audio.stop_all()
	await frames(3)
	print("COUNTER_DAMAGE_RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func fixed_counter(kind: String, side: float, gap: float, use_ward := false) -> void:
	await fixture(Vector2(360+side*gap,320))
	var enemy := spawn_mob(kind)
	player.facing = -side
	var events: Array[Dictionary] = []
	player.health.damaged.connect(func(amount: int, source: Vector2) -> void:
		events.append({"damage":amount,"state":enemy.state,"source":str(source),"gap":absf(player.position.x-enemy.position.x),"active":is_attacking(enemy)}))
	var hits := 0
	var reached_active := false
	var active_variant := -1
	var ward_requested := false
	var full_warning := false
	for tick: int in range(270):
		if not is_instance_valid(enemy) or enemy.health.current<=0 or player.health.current<=0:
			break
		hold("attack",hits<enemy.health.maximum-1 and tick%24<2)
		if enemy is BellInvoker and enemy.state==BellInvoker.State.WARNING:
			full_warning = full_warning or enemy.elapsed>=enemy.warning_seconds()-0.04
			if use_ward and not ward_requested and enemy.elapsed>=enemy.warning_seconds()-0.12:
				hold("steam_ward",true)
				ward_requested = true
		var before: int = enemy.health.current
		await frames()
		if enemy.health.current<before:
			hits += before-enemy.health.current
			enemy.target = player
		if is_attacking(enemy):
			reached_active = true
			if enemy is BellInvoker:
				active_variant = enemy.cast_variant
		elif reached_active:
			await frames(3)
			break
	release()
	var label := "%s side=%s gap=%s ward=%s" % [kind,side,gap,use_ward]
	check(hits>0 and reached_active,"Real stationary sword hits are followed by a counter: "+label)
	if use_ward:
		check(ward_requested and player.steam_ward.active_left==0 and player.health.current==5 and events.is_empty(),"A real ward blocks the close counter once without follow-up damage: "+label)
	else:
		check(events.size()==1 and events[0].active and player.health.current==4,"Stationary attacker takes one hit in the counter's active phase: "+label)
	if enemy is BellInvoker:
		check(active_variant==(1 if gap<enemy.config.rising_minimum else 0) and full_warning,"Mage chooses an in-range source arc and keeps its complete warning: "+label)
	print("FIXED_COUNTER: ",kind," side=",side," gap=",gap," hits=",hits," active=",reached_active," variant=",active_variant," player_hp=",player.health.current," events=",events)
