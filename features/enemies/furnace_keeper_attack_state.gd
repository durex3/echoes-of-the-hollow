class_name FurnaceKeeperAttackState
extends BossAttackState

func _init(id := 0, label := "", cooldown_seconds := 0.0) -> void:
	attack_id = id
	name_id = label
	cooldown = cooldown_seconds

func enter() -> void:
	super.enter()
	var boss := host as FurnaceKeeper
	_begin_phase(FurnaceKeeper.State.TAKEOFF if attack_id == FurnaceKeeper.Attack.SLAM else FurnaceKeeper.State.APPROACH if attack_id == FurnaceKeeper.Attack.MELEE else FurnaceKeeper.State.WARNING)

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var boss := host as FurnaceKeeper
	match boss.state:
		FurnaceKeeper.State.TAKEOFF:
			if boss.position.y <= boss.home_position.y - boss.config.flight_height + 0.1 or boss.is_on_ceiling():
				_begin_phase(FurnaceKeeper.State.WARNING)
		FurnaceKeeper.State.WARNING:
			if boss.timer <= 0.0:
				_begin_phase(FurnaceKeeper.State.CAST)
		FurnaceKeeper.State.CAST:
			if attack_id in [FurnaceKeeper.Attack.DASH, FurnaceKeeper.Attack.MELEE, FurnaceKeeper.Attack.COMBO] and boss.timer <= 0.0:
				if attack_id == FurnaceKeeper.Attack.COMBO and boss.combo_left > 1:
					boss.combo_left -= 1
					boss.facing = -1 if boss.target.position.x < boss.position.x else 1
					_begin_phase(FurnaceKeeper.State.WARNING)
				else:
					_begin_phase(FurnaceKeeper.State.RECOVER)
			elif attack_id == FurnaceKeeper.Attack.HOP and boss.is_on_floor() and boss.velocity.y >= 0:
				_begin_phase(FurnaceKeeper.State.RECOVER)
		FurnaceKeeper.State.LANDING:
			if boss.is_on_floor():
				boss._slam_impact()
				_begin_phase(FurnaceKeeper.State.IMPACT)
		FurnaceKeeper.State.IMPACT:
			if boss.timer <= 0.0:
				_begin_phase(FurnaceKeeper.State.RECOVER)
		FurnaceKeeper.State.RECOVER:
			if boss.timer <= 0.0:
				machine.finish()
				boss.start_attack()
		FurnaceKeeper.State.APPROACH:
			boss.facing = -1 if boss.target.position.x < boss.position.x else 1
			if absf(boss.target.position.x - boss.position.x) <= boss.config.melee_range or boss.timer <= 0.0:
				_begin_phase(FurnaceKeeper.State.WARNING)
	boss.velocity.x = 0.0
	if boss.state == FurnaceKeeper.State.TAKEOFF:
		var distance := maxf(0.0, boss.position.y - (boss.home_position.y - boss.config.flight_height))
		boss.velocity.y = -minf(boss.config.ascent_speed, distance / delta)
		boss.velocity.x = (boss.config.slam_x - boss.position.x) / maxf(distance / boss.config.ascent_speed, delta)
	elif boss.state == FurnaceKeeper.State.WARNING and attack_id == FurnaceKeeper.Attack.SLAM:
		boss.velocity.y = 0.0
	elif boss.state == FurnaceKeeper.State.LANDING:
		boss.velocity.y = boss.config.slam_speed
	elif boss.state == FurnaceKeeper.State.CAST and attack_id == FurnaceKeeper.Attack.DASH:
		var progress := clampf(1.0 - boss.timer / boss.config.dash_seconds, 0.0, 1.0)
		var speed_factor := boss.config.dash_motion_curve.sample(progress) if boss.config.dash_motion_curve else 1.0
		boss.velocity.x = boss.facing * boss.config.dash_speed * speed_factor
	elif boss.state == FurnaceKeeper.State.APPROACH:
		boss.velocity.x = boss.facing * boss.config.approach_speed
	elif boss.state == FurnaceKeeper.State.CAST and attack_id == FurnaceKeeper.Attack.COMBO:
		boss.velocity.x = boss.facing * boss.config.combo_speed
	elif boss.state == FurnaceKeeper.State.CAST and attack_id == FurnaceKeeper.Attack.HOP:
		boss.velocity.x = boss.facing * boss.config.hop_speed
	if boss.state not in [FurnaceKeeper.State.TAKEOFF, FurnaceKeeper.State.LANDING] and not (boss.state == FurnaceKeeper.State.WARNING and attack_id == FurnaceKeeper.Attack.SLAM):
		boss.velocity.y = minf(950.0, boss.velocity.y + boss.config.gravity * delta)

func exit() -> void:
	(host as FurnaceKeeper).dash_hitbox.end_swing()
	super.exit()

func _begin_phase(next: FurnaceKeeper.State) -> void:
	var boss := host as FurnaceKeeper
	if boss.state == FurnaceKeeper.State.CAST and attack_id in [FurnaceKeeper.Attack.DASH, FurnaceKeeper.Attack.MELEE, FurnaceKeeper.Attack.COMBO]:
		boss.dash_hitbox.end_swing()
	boss.state = next
	match next:
		FurnaceKeeper.State.TAKEOFF:
			boss.clip("takeoff", boss.config.flight_height / boss.config.ascent_speed)
			boss.cue_changed.emit("TAKEOFF / Watch the landing line")
			boss._spawn_burst(boss.global_position + Vector2(0.0, -26.0), Color("f4d49a"), 30.0, 0.28, 2, 8)
		FurnaceKeeper.State.APPROACH:
			boss.timer = boss.config.approach_seconds
			boss.clip("idle")
			boss.cue_changed.emit("APPROACH / Watch the sword")
		FurnaceKeeper.State.WARNING:
			if attack_id == FurnaceKeeper.Attack.SLAM:
				boss.timer = boss.config.hover_seconds
				boss.clip("eruption_warning", boss.timer)
				boss.cue_changed.emit("HIGH SLAM / Leave the landing line")
			elif attack_id == FurnaceKeeper.Attack.MELEE:
				boss.timer = boss.config.melee_warning
				boss.clip("wave_warning", boss.timer)
				boss.cue_changed.emit("MELEE / Step back or jump")
			elif attack_id == FurnaceKeeper.Attack.COMBO:
				boss.timer = boss.config.combo_charge if boss.combo_left == boss.config.combo_strikes else boss.config.combo_gap
				boss.clip("wave_warning", boss.timer)
				boss.cue_changed.emit("CHARGED COMBO / Three strikes, then recovery")
				Audio.play_sound("attack", 0.6, -6.0)
			else:
				boss.timer = boss.config.dash_warning_seconds if attack_id == FurnaceKeeper.Attack.DASH else boss.config.hop_warning_seconds
				boss.clip("wave_warning" if attack_id == FurnaceKeeper.Attack.DASH else "takeoff", boss.timer)
				boss.cue_changed.emit("DASH SLASH / Jump or move behind" if attack_id == FurnaceKeeper.Attack.DASH else "SHORT HOP / Watch the landing")
			Audio.play_sound("attack", 0.7, -6.0)
		FurnaceKeeper.State.CAST:
			if attack_id in [FurnaceKeeper.Attack.DASH, FurnaceKeeper.Attack.MELEE, FurnaceKeeper.Attack.COMBO]:
				boss.timer = boss.config.dash_seconds if attack_id == FurnaceKeeper.Attack.DASH else boss.config.melee_seconds if attack_id == FurnaceKeeper.Attack.MELEE else boss.config.combo_seconds
				boss.clip("wave_cast", boss.timer)
				boss.dash_hitbox.begin_swing()
				boss.dash_hitbox.active = true
			elif attack_id == FurnaceKeeper.Attack.HOP:
				boss.velocity.y = boss.config.hop_velocity
				boss.clip("takeoff")
			else:
				_begin_phase(FurnaceKeeper.State.LANDING)
		FurnaceKeeper.State.LANDING:
			boss.velocity.y = boss.config.slam_speed
			boss.clip("eruption_cast")
			boss.cue_changed.emit("SLAM / Jump above the flame walls")
			Audio.play_sound("attack", 0.65, -5.0)
		FurnaceKeeper.State.IMPACT:
			boss.timer = boss.config.impact_seconds
			boss.velocity = Vector2.ZERO
			boss.clip("eruption_cast", boss.timer)
			boss.cue_changed.emit("SLAM IMPACT / Flames spread outward")
		FurnaceKeeper.State.RECOVER:
			boss.timer = boss.config.recovery_seconds
			if attack_id == FurnaceKeeper.Attack.MELEE:
				boss.timer = boss.config.melee_recovery
			boss.clip("eruption_recover" if attack_id == FurnaceKeeper.Attack.SLAM else "wave_recover", boss.timer)
			boss.cue_changed.emit("PRESSURE RELEASE / Strike now")
	boss.queue_redraw()
