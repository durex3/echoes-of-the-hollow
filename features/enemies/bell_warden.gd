class_name BellWarden
extends CharacterBody2D

signal defeated
signal awakened
signal phase_changed(next_phase: int)
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)

enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, ECHO_WARNING, ECHO_ACTIVE, RECOVER, DEAD, GHOST_WARNING, GHOST_ACTIVE, TRANSITION, DROP_WARNING, DROP_ACTIVE, STAGGER }
enum Attack { SWEEP, DASH, ECHO, RESONANCE, DROP }

@export var config: BellWardenConfig
@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var contact_box: Hitbox = $ContactBox
@onready var combat_effect: BellWardenEffect = $CombatEffect
var target: Player
var state := State.DORMANT
var attack := Attack.SWEEP
var attack_count := 0
var facing := -1.0
var timer := 0.0
var flash_left := 0.0
var mark: EchoMark
var phase_marks: Array[EchoMark] = []
var phase := 1
var last_attack := -1
var last_mark_position := Vector2.ZERO
var ghost: EchoMark
var phase_ghosts: Array[EchoMark] = []
var walk_clock := 0.0
var walk_frame := -1
var action_elapsed := 0.0
var resonance_marks: Array[EchoMark] = []
var staggered_by_ghost := false

func _ready() -> void:
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))
	contact_box.end_swing()
	attack_box.end_swing()
	_set_frame(0)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		action_elapsed += delta
		_set_strip_frame(29 + mini(9, int(action_elapsed * 12.0)))
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		attack_box.end_swing()
		contact_box.end_swing()
		velocity = Vector2.ZERO
		return
	timer = maxf(0.0, timer - delta)
	action_elapsed += delta
	flash_left = maxf(0.0, flash_left - delta)
	walk_clock += delta
	velocity.y = minf(velocity.y + 1600.0 * delta, 950.0)
	match state:
		State.DORMANT:
			if target.global_position.x >= config.activation_x:
				facing = signf(target.global_position.x - global_position.x)
				if is_zero_approx(facing):
					facing = -1.0
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO:
			if timer <= 0.0:
				_enter(State.CHASE)
		State.TRANSITION:
			if timer <= 0.0:
				_enter(State.CHASE)
		State.CHASE:
			facing = signf(target.global_position.x - global_position.x)
			if is_zero_approx(facing):
				facing = -1.0
			var distance := absf(target.global_position.x - global_position.x)
			if timer > 0.0:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			elif distance <= config.sweep_range and distance >= 36.0:
				_start_attack()
			elif phase >= 2 and distance <= 260.0 and attack_count > 0 and attack_count % 3 == 2:
				_start_attack()
			else:
				# Keep a readable gap instead of walking into the player and trading body damage.
				var move_direction := facing if distance > config.sweep_range else -facing
				var chase_speed := config.move_speed * (1.0 + 0.12 * float(phase - 1))
				velocity.x = move_toward(velocity.x, move_direction * chase_speed, 1100.0 * delta)
		State.WINDUP:
			if timer <= 0.0:
				_enter(State.STRIKE)
		State.STRIKE:
			if attack == Attack.DASH:
				velocity.x = facing * config.dash_speed
			if timer <= 0.0 or (attack == Attack.DASH and (is_on_wall() or global_position.x <= config.arena_min_x or global_position.x >= config.arena_max_x)):
				_enter(State.RECOVER)
		State.ECHO_WARNING:
			if timer <= 0.0:
				_enter(State.ECHO_ACTIVE)
		State.ECHO_ACTIVE:
			var pressure_direction := signf(target.global_position.x - global_position.x)
			if is_zero_approx(pressure_direction):
				pressure_direction = facing
			velocity.x = move_toward(velocity.x, pressure_direction * config.move_speed * 1.25, 1000.0 * delta)
			if timer <= 0.0:
				attack = Attack.SWEEP if target.is_on_floor() else Attack.DASH
				facing = signf(target.global_position.x - global_position.x)
				if is_zero_approx(facing):
					facing = -1.0
				_enter(State.WINDUP)
		State.GHOST_WARNING:
			if timer <= 0.0:
				_enter(State.GHOST_ACTIVE)
		State.GHOST_ACTIVE:
			if timer <= 0.0:
				_enter(State.CHASE)
		State.DROP_WARNING:
			if timer <= 0.0:
				_enter(State.DROP_ACTIVE)
		State.DROP_ACTIVE:
			if timer <= 0.0:
				_enter(State.RECOVER)
		State.STAGGER:
			if timer <= 0.0:
				_enter(State.CHASE)
		State.RECOVER:
			# Recovery is a real punish window, but the warden retreats so a player
			# cannot hold attack inside its body and trade hits indefinitely.
			var retreat_direction := -signf(target.global_position.x - global_position.x)
			if is_zero_approx(retreat_direction):
				retreat_direction = facing
			velocity.x = move_toward(velocity.x, retreat_direction * config.recovery_retreat_speed, 1200.0 * delta)
			if timer <= 0.0:
				if phase == 1 and health.current <= config.phase_two_threshold:
					phase = 2
					attack_count = 2
					phase_changed.emit(phase)
					_enter(State.TRANSITION)
				elif phase == 2 and health.current <= config.phase_three_threshold:
					phase = 3
					attack_count = 2
					phase_changed.emit(phase)
					_enter(State.TRANSITION)
				else:
					_enter(State.CHASE)
	move_and_slide()
	contact_box.active = state in [State.CHASE, State.STRIKE, State.ECHO_ACTIVE, State.GHOST_ACTIVE]
	global_position.x = clampf(global_position.x, config.arena_min_x, config.arena_max_x)
	_update_visual()
	var effect_windup := config.resonance_warning + config.echo_stagger * 2.0 if state == State.ECHO_WARNING else config.drop_warning if state == State.DROP_WARNING else config.sweep_windup if attack == Attack.SWEEP else config.dash_windup
	var effect_active := config.memory_replay_seconds if state == State.ECHO_ACTIVE else config.drop_active if state == State.DROP_ACTIVE else config.sweep_active if attack == Attack.SWEEP else config.dash_active
	combat_effect.configure(int(state), int(attack), facing, phase, timer, effect_windup, effect_active)

func _start_attack() -> void:
	if phase == 3 and attack_count > 0 and attack_count % 4 == 2 and not is_instance_valid(ghost):
		attack = Attack.ECHO
		attack_count += 1
		_enter(State.GHOST_WARNING)
		return
	if phase == 3 and attack_count > 0 and attack_count % 4 == 3:
		attack = Attack.RESONANCE
		attack_count += 1
		_enter(State.ECHO_WARNING)
		return
	attack = Attack.SWEEP if attack_count == 0 else Attack.RESONANCE if phase >= 2 and attack_count % 3 == 2 else Attack.DASH if last_attack == Attack.SWEEP else Attack.SWEEP
	if int(attack) == last_attack and attack not in [Attack.RESONANCE, Attack.DROP]:
		attack = Attack.DASH if attack == Attack.SWEEP else Attack.SWEEP
	last_attack = int(attack)
	attack_count += 1
	_enter(State.ECHO_WARNING if attack == Attack.RESONANCE else State.WINDUP)

func _enter(next: State) -> void:
	state = next
	action_elapsed = 0.0
	velocity.x = 0.0
	attack_box.end_swing()
	if next in [State.DORMANT, State.INTRO, State.DEAD]:
		contact_box.end_swing()
	match state:
		State.INTRO:
			timer = config.intro_seconds
			cue_changed.emit("缚钟守望者苏醒")
		State.TRANSITION:
			timer = config.phase_transition_seconds
			contact_box.end_swing()
			cue_changed.emit("缚钟守望者进入新阶段")
		State.CHASE:
			timer = maxf(timer, config.attack_gap_seconds)
			contact_box.begin_swing()
		State.WINDUP:
			timer = config.sweep_windup if attack == Attack.SWEEP else config.dash_windup
			attack_box.position.x = facing * (34.0 if attack == Attack.SWEEP else 42.0)
			attack_box.damage = config.sweep_damage if attack == Attack.SWEEP else config.dash_damage
			attack_box.begin_swing()
			contact_box.hit_ids = attack_box.hit_ids
			cue_changed.emit("镰刀横扫 / 后撤或绕到身后" if attack == Attack.SWEEP else "锁向镰突 / 跳过或绕后")
		State.STRIKE:
			timer = config.sweep_active if attack == Attack.SWEEP else config.dash_active
			contact_box.hit_ids = attack_box.hit_ids
			attack_box.active = true
			_clear_ghost_on_scythe()
		State.ECHO_WARNING:
			timer = config.resonance_warning + config.echo_stagger * (3.0 if phase == 3 else 2.0)
			cue_changed.emit("终钟回响 / 记住旧位置")
			for old_mark: EchoMark in phase_marks:
				if is_instance_valid(old_mark): old_mark.queue_free()
			phase_marks.clear()
			_spawn_resonance()
		State.ECHO_ACTIVE:
			timer = config.memory_replay_seconds
		State.GHOST_WARNING:
			timer = config.ghost_warning
			cue_changed.emit("逆相残像")
			_spawn_ghost()
		State.GHOST_ACTIVE:
			timer = 0.18
			if is_instance_valid(ghost):
				var old_x := global_position.x
				global_position.x = clampf(ghost.global_position.x, config.arena_min_x + 20.0, config.arena_max_x - 20.0)
				ghost.global_position.x = old_x
		State.RECOVER:
			timer = config.ghost_recovery if phase == 3 and attack_count % 3 == 0 else config.sweep_recovery if attack == Attack.SWEEP else config.dash_recovery if attack == Attack.DASH else config.drop_recovery if attack == Attack.DROP else config.echo_recovery
			contact_box.begin_swing()
			cue_changed.emit("反击窗口")
		State.DROP_WARNING:
			timer = config.drop_warning
			cue_changed.emit("断钟坠落 / 离开锁点")
			_spawn_drop()
		State.DROP_ACTIVE:
			timer = config.drop_active
		State.STAGGER:
			timer = config.stagger_seconds
			contact_box.end_swing()
			cue_changed.emit("幽魂反噬 / 失衡")
		State.DEAD:
			attack_box.end_swing()
			contact_box.end_swing()
			_set_strip_frame(29)

func _spawn_resonance() -> void:
	for index: int in range(4 if phase == 3 else 3):
		var lane := EchoMark.new()
		lane.player = target
		lane.pattern = "memory"
		lane.delay_seconds = 0.0
		lane.phase_offset = float(index) * config.memory_record_gap
		lane.replay_delay = config.resonance_warning + config.echo_stagger * (3.0 if phase == 3 else 2.0)
		lane.active_seconds = config.resonance_active
		lane.damage = config.resonance_damage
		lane.global_position = target.global_position
		get_parent().add_child(lane)
		phase_marks.append(lane)
	mark = phase_marks.back()
	last_mark_position = target.global_position

func _spawn_drop() -> void:
	var drop := EchoMark.new()
	drop.player = target
	drop.pattern = "drop"
	drop.delay_seconds = config.drop_warning
	drop.active_seconds = config.drop_active
	drop.radius = config.drop_radius
	drop.damage = config.drop_damage
	drop.global_position = _ground_target_position()
	get_parent().add_child(drop)
	phase_marks.append(drop)

func _spawn_ghost() -> void:
	for old_ghost: EchoMark in phase_ghosts:
		if is_instance_valid(old_ghost): old_ghost.queue_free()
	phase_ghosts.clear()
	var center := _ground_target_position()
	var next_ghost := EchoMark.new()
	next_ghost.player = target
	next_ghost.delay_seconds = config.ghost_warning
	next_ghost.active_seconds = 2.8
	next_ghost.radius = config.ghost_radius
	next_ghost.damage = 1
	next_ghost.ghost_visual = true
	next_ghost.global_position = Vector2(clampf(center.x, config.arena_min_x + 20.0, config.arena_max_x - 20.0), center.y - 26.0)
	get_parent().add_child(next_ghost)
	phase_ghosts.append(next_ghost)
	ghost = next_ghost

func _ground_target_position() -> Vector2:
	var target_x := clampf(target.global_position.x, config.arena_min_x, config.arena_max_x)
	var start := Vector2(target_x, target.global_position.y)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2.DOWN * 400.0)
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return Vector2(target_x, hit.position.y if not hit.is_empty() else target.global_position.y)

func _clear_ghost_on_scythe() -> void:
	if not is_instance_valid(ghost):
		return
	var toward := (ghost.global_position.x - global_position.x) * facing
	if toward >= -12.0 and toward <= 112.0 and absf(ghost.global_position.y - global_position.y) <= 58.0:
		ghost.dispel()
		staggered_by_ghost = true
		_enter(State.STAGGER)

func _update_visual() -> void:
	# The Bringer sheet is authored facing left; flip only when travelling right.
	body_sprite.flip_h = facing > 0.0
	# Its opaque body is centered at source x=105, not at the 140px cell center.
	body_sprite.position.x = facing * 40.0
	body_sprite.modulate = Color(2.6, 2.6, 2.6) if flash_left > 0.0 and not Session.reduce_flashes else Color.WHITE
	if state == State.WINDUP:
		var duration := config.sweep_windup if attack == Attack.SWEEP else config.dash_windup
		_set_strip_frame(16 + mini(3, int(action_elapsed / duration * 4.0)))
	elif state == State.STRIKE:
		var duration := config.sweep_active if attack == Attack.SWEEP else config.dash_active
		_set_strip_frame(20 + mini(3, int(action_elapsed / duration * 4.0)))
	elif state in [State.ECHO_WARNING, State.ECHO_ACTIVE, State.GHOST_WARNING, State.GHOST_ACTIVE, State.DROP_WARNING, State.DROP_ACTIVE, State.STAGGER]:
		var duration := config.resonance_warning if state == State.ECHO_WARNING else config.ghost_warning if state == State.GHOST_WARNING else config.memory_replay_seconds if state == State.ECHO_ACTIVE else config.ghost_travel_seconds
		var first := 40 if state in [State.ECHO_WARNING, State.GHOST_WARNING] else 44
		_set_strip_frame(first + mini(3, int(action_elapsed / duration * 4.0)))
		if state == State.STAGGER:
			body_sprite.modulate = Color("fff2a6")
	elif state == State.RECOVER and attack in [Attack.SWEEP, Attack.DASH]:
		_set_strip_frame(24 + mini(1, int(action_elapsed / maxf(timer + action_elapsed, 0.01) * 2.0)))
	elif state == State.TRANSITION:
		_set_strip_frame(0)
		body_sprite.modulate = Color("c880bd") if phase == 2 else Color("ff9abb")
	elif absf(velocity.x) > 8.0:
		# The first row is the authored eight-frame walk cycle. Advance from movement time,
		# so a brief stop never leaves the sprite permanently on a single pose.
		walk_frame = int(walk_clock * 10.0) % 8
		_set_frame(walk_frame, 0)
	else:
		_set_frame(0, 1 if phase >= 2 else 0)

func _set_frame(index: int, row: int = 0) -> void:
	body_sprite.region_rect = Rect2(index * 140, row * 93, 140, 93)

func _set_strip_frame(index: int) -> void:
	_set_frame(index % 8, index / 8)

func _on_damage(_amount: int, _at: Vector2) -> void:
	flash_left = 0.1

func _on_death() -> void:
	if is_instance_valid(mark):
		mark.queue_free()
	if is_instance_valid(ghost):
		ghost.queue_free()
	for hazard: EchoMark in phase_marks + phase_ghosts:
		if is_instance_valid(hazard): hazard.queue_free()
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()
