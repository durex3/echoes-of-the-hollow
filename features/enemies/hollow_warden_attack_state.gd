class_name HollowWardenAttackState
extends BossAttackState

func _init(id := 0, label := "", cooldown_seconds := 0.0) -> void:
	attack_id = id
	name_id = label
	cooldown = cooldown_seconds

func enter() -> void:
	super.enter()
	_begin_phase(HollowWarden.State.SWORD_COURT if attack_id == HollowWarden.Attack.CHARGED else HollowWarden.State.WINDUP)

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var boss := host as HollowWarden
	match boss.state:
		HollowWarden.State.WINDUP:
			if boss.timer <= 0.0:
				_begin_phase(HollowWarden.State.STRIKE)
		HollowWarden.State.STRIKE:
			if boss.timer <= 0.0:
				_begin_phase(HollowWarden.State.RECOVER)
			elif attack_id == HollowWarden.Attack.RUSH:
				boss.velocity.x = boss.facing * boss.config.rush_speed
		HollowWarden.State.RECOVER:
			if boss.timer <= 0.0:
				machine.finish()
				boss._enter(HollowWarden.State.CHASE)

func exit() -> void:
	var boss := host as HollowWarden
	boss.attack_box.end_swing()
	boss.charged_box.end_swing()
	super.exit()

func after_move() -> void:
	var boss := host as HollowWarden
	if boss.state == HollowWarden.State.STRIKE and attack_id == HollowWarden.Attack.RUSH and boss.is_on_wall():
		_begin_phase(HollowWarden.State.RECOVER)

func _begin_phase(next: HollowWarden.State) -> void:
	var boss := host as HollowWarden
	boss.state = next
	boss.velocity.x = 0.0
	boss.attack_box.end_swing()
	boss.charged_box.end_swing()
	match next:
		HollowWarden.State.WINDUP:
			boss.timer = boss.active_profile.windup
			boss.attack_box.position.x = boss.facing * 44
			boss.attack_box.damage = boss.active_profile.damage
			boss.attack_box.begin_swing()
			boss._play_clip("rush_windup" if attack_id == HollowWarden.Attack.RUSH else "windup", boss.timer)
			boss.cue_changed.emit("RUSH / Jump over" if attack_id == HollowWarden.Attack.RUSH else "SWEEP / Step back or behind")
			Audio.play_sound("jump" if attack_id == HollowWarden.Attack.RUSH else "attack", 0.7, -7.0)
		HollowWarden.State.STRIKE:
			boss.timer = boss.active_profile.active_seconds
			boss.attack_box.active = true
			boss._play_clip("rush_strike" if attack_id == HollowWarden.Attack.RUSH else "strike", boss.timer)
			Audio.play_sound("attack")
		HollowWarden.State.SWORD_COURT:
			boss.timer = boss.config.court.summon_seconds
			boss._play_clip("charged_windup", boss.timer)
			boss._spawn_court()
			boss.cue_changed.emit("SWORD COURT / Invulnerable while summoning")
			Audio.play_sound("ability_acquire", 0.6, -5.0)
		HollowWarden.State.RECOVER:
			boss.timer = boss.active_profile.recovery
			boss._play_clip("rush_recover" if attack_id == HollowWarden.Attack.RUSH else "recover", boss.timer)
			boss.cue_changed.emit("RECOVERY / Strike now")
