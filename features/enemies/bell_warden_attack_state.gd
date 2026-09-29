class_name BellWardenAttackState
extends BossAttackState

func _init(id := 0, label := "", cooldown_seconds := 0.0) -> void:
	attack_id = id
	name_id = label
	cooldown = cooldown_seconds

func enter() -> void:
	super.enter()
	_begin_phase(BellWarden.State.WINDUP)

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var boss := host as BellWarden
	match boss.state:
		BellWarden.State.WINDUP:
			if boss.timer <= 0.0:
				_begin_phase(BellWarden.State.STRIKE)
		BellWarden.State.STRIKE:
			if attack_id == BellWarden.Attack.DASH:
				boss.velocity.x = boss.facing * boss.config.dash_speed
			if boss.timer <= 0.0 or (attack_id == BellWarden.Attack.DASH and (boss.is_on_wall() or boss.global_position.x <= boss.config.arena_min_x or boss.global_position.x >= boss.config.arena_max_x)):
				_begin_phase(BellWarden.State.RECOVER)
		BellWarden.State.RECOVER:
			boss.velocity.x = move_toward(boss.velocity.x, -boss.facing * boss.config.recovery_retreat_speed, 1500.0 * delta)
			if boss.timer <= 0.0:
				machine.finish()
				boss._enter(BellWarden.State.CHASE)

func exit() -> void:
	(host as BellWarden).attack_box.end_swing()
	super.exit()

func _begin_phase(next: BellWarden.State) -> void:
	var boss := host as BellWarden
	boss.state = next
	boss.action_elapsed = 0.0
	boss.velocity.x = 0.0
	boss.attack_box.end_swing()
	match next:
		BellWarden.State.WINDUP:
			boss.timer = boss.config.sweep_windup if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_windup
			boss.attack_box.position.x = boss.facing * (34.0 if attack_id == BellWarden.Attack.SWEEP else 42.0)
			boss.attack_box.damage = boss.config.sweep_damage if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_damage
			boss.attack_box.begin_swing()
			boss.cue_changed.emit("红色横扫：后撤或绕后" if attack_id == BellWarden.Attack.SWEEP else "红色突进：跳过或绕后")
		BellWarden.State.STRIKE:
			boss.timer = boss.config.sweep_active if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_active
			boss.attack_box.active = true
		BellWarden.State.RECOVER:
			boss.timer = boss.config.sweep_recovery if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_recovery
			boss.contact_box.begin_swing()
			boss.cue_changed.emit("反击窗口")
