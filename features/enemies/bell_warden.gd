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
const DecisionScript = preload("res://features/enemies/bell_warden_decision.gd")
const StateMachineScript = preload("res://features/enemies/boss_state_machine.gd")
const AttackStateScript = preload("res://features/enemies/boss_attack_state.gd")

var decision: RefCounted = DecisionScript.new()
var state_machine: RefCounted = StateMachineScript.new()
var attack_states := {
	Attack.SWEEP: AttackStateScript.new("sweep", 0.24, 0.16, 0.76, 0.16),
	Attack.DASH: AttackStateScript.new("dash", 0.28, 0.34, 0.76, 4.0),
	Attack.DROP: AttackStateScript.new("drop", 1.5, 0.24, 1.2, 8.0),
}
var target: Player
var state := State.DORMANT
var attack := Attack.SWEEP
var phase := 1
var facing := -1.0
var timer := 0.0
var attack_count := 0
var regular_attacks := 0
var dash_cooldown := 0.0
var finisher_used := false
var contact_refresh := 0.0
var flash_left := 0.0
var walk_clock := 0.0
var action_elapsed := 0.0

func _ready() -> void:
	state_machine.setup(self)
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))
	attack_box.end_swing()
	contact_box.end_swing()
	_set_frame(0)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		attack_box.end_swing()
		contact_box.end_swing()
		velocity = Vector2.ZERO
		return
	timer = maxf(0.0, timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	contact_refresh = maxf(0.0, contact_refresh - delta)
	flash_left = maxf(0.0, flash_left - delta)
	action_elapsed += delta
	state_machine.tick(delta)
	walk_clock += delta
	velocity.y = minf(velocity.y + 1600.0 * delta, 950.0)
	match state:
		State.DORMANT:
			if target.global_position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO:
			if timer <= 0.0: _enter(State.CHASE)
		State.CHASE:
			facing = signf(target.global_position.x - global_position.x)
			if is_zero_approx(facing): facing = -1.0
			var distance := absf(target.global_position.x - global_position.x)
			if timer <= 0.0 and distance <= 260.0:
				_start_attack()
			else:
				var direction := facing if distance > config.sweep_range else -facing
				velocity.x = move_toward(velocity.x, direction * config.move_speed, 1400.0 * delta)
			if contact_refresh <= 0.0:
				contact_box.begin_swing()
				contact_refresh = 0.42
		State.WINDUP:
			if timer <= 0.0: _enter(State.STRIKE)
		State.STRIKE:
			if attack == Attack.DASH: velocity.x = facing * config.dash_speed
			if timer <= 0.0 or (attack == Attack.DASH and (is_on_wall() or global_position.x <= config.arena_min_x or global_position.x >= config.arena_max_x)):
				_enter(State.RECOVER)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, -facing * config.recovery_retreat_speed, 1500.0 * delta)
			if timer <= 0.0: _enter(State.CHASE)
		State.DROP_WARNING:
			if timer <= 0.0: _enter(State.DROP_ACTIVE)
		State.DROP_ACTIVE:
			if timer <= 0.0: _enter(State.RECOVER)
		State.STAGGER:
			if timer <= 0.0: _enter(State.CHASE)
	move_and_slide()
	contact_box.active = state in [State.CHASE, State.WINDUP, State.STRIKE]
	contact_box.damage = 1
	global_position.x = clampf(global_position.x, config.arena_min_x, config.arena_max_x)
	_update_visual()
	combat_effect.configure(int(state), int(attack), facing, 1, timer, _windup(), _active())

func _start_attack() -> void:
	var distance := absf(target.global_position.x - global_position.x)
	var airborne := target.global_position.y < global_position.y - 34.0
	var selected: int = decision.choose_attack(distance, airborne, health.current, config.maximum_health, regular_attacks, dash_cooldown <= 0.0, finisher_used)
	attack = selected as Attack
	state_machine.change(attack_states[attack])
	(attack_states[attack] as BossAttackState).arm()
	attack_count += 1
	if attack == Attack.DROP:
		finisher_used = true
		_enter(State.DROP_WARNING)
		return
	if attack == Attack.DASH:
		dash_cooldown = 4.0
		regular_attacks = 0
	else:
		regular_attacks += 1
	_enter(State.WINDUP)

func _enter(next: State) -> void:
	state = next
	action_elapsed = 0.0
	velocity.x = 0.0
	attack_box.end_swing()
	if next in [State.WINDUP, State.DROP_WARNING]:
		state_machine.change(attack_states[attack])
	match state:
		State.INTRO:
			timer = config.intro_seconds
			cue_changed.emit("缚钟守望者苏醒")
		State.CHASE:
			timer = maxf(timer, config.attack_gap_seconds)
			contact_box.begin_swing()
		State.WINDUP:
			timer = config.sweep_windup if attack == Attack.SWEEP else config.dash_windup
			attack_box.position.x = facing * (34.0 if attack == Attack.SWEEP else 42.0)
			attack_box.damage = config.sweep_damage if attack == Attack.SWEEP else config.dash_damage
			attack_box.begin_swing()
			cue_changed.emit("红色横扫：后撤或绕后" if attack == Attack.SWEEP else "红色突进：跳过或绕后")
		State.STRIKE:
			timer = config.sweep_active if attack == Attack.SWEEP else config.dash_active
			attack_box.active = true
		State.RECOVER:
			timer = config.sweep_recovery if attack == Attack.SWEEP else config.dash_recovery
			contact_box.begin_swing()
			cue_changed.emit("反击窗口")
		State.DROP_WARNING:
			timer = config.cleave_windup
			cue_changed.emit("终结镰斩：跳跃、踏壁或举盾")
			_spawn_drop()
		State.DROP_ACTIVE:
			timer = config.drop_active
		State.STAGGER:
			timer = config.stagger_seconds
			contact_box.end_swing()
		State.DEAD:
			attack_box.end_swing()
			contact_box.end_swing()

func _spawn_drop() -> void:
	var drop := EchoMark.new()
	drop.player = target
	drop.pattern = "drop"
	drop.delay_seconds = config.cleave_windup
	drop.active_seconds = config.drop_active
	drop.radius = config.drop_radius
	drop.damage = config.cleave_damage
	drop.global_position = target.global_position
	get_parent().add_child(drop)
	for direction: float in [-1.0, 1.0]:
		var wave := EchoMark.new()
		wave.player = target
		wave.pattern = "resonance"
		wave.delay_seconds = config.cleave_windup
		wave.active_seconds = 0.55
		wave.travel_seconds = 0.55
		wave.travel_radius = 24.0
		wave.damage = config.cleave_damage
		wave.global_position = target.global_position
		wave.travel_target = Vector2(config.arena_min_x if direction < 0.0 else config.arena_max_x, target.global_position.y)
		get_parent().add_child(wave)

func _windup() -> float:
	return config.cleave_windup if state == State.DROP_WARNING else config.sweep_windup if attack == Attack.SWEEP else config.dash_windup

func _active() -> float:
	return config.drop_active if state == State.DROP_ACTIVE else config.sweep_active if attack == Attack.SWEEP else config.dash_active

func _update_visual() -> void:
	body_sprite.flip_h = facing > 0.0
	body_sprite.position.x = facing * 40.0
	body_sprite.modulate = Color(2.6, 2.6, 2.6) if flash_left > 0.0 and not Session.reduce_flashes else Color.WHITE
	if state == State.WINDUP:
		_set_strip_frame(16 + mini(3, int(action_elapsed / maxf(_windup(), 0.01) * 4.0)))
	elif state == State.STRIKE:
		_set_strip_frame(20 + mini(3, int(action_elapsed / maxf(_active(), 0.01) * 4.0)))
	elif state == State.DROP_WARNING or state == State.DROP_ACTIVE:
		_set_strip_frame(40 + mini(3, int(action_elapsed / maxf(_windup(), 0.01) * 4.0)))
	elif state == State.CHASE and absf(velocity.x) > 2.0:
		_set_frame(int(walk_clock * 14.0) % 8, 0)
	else:
		_set_frame(0, 0)

func _set_frame(index: int, row: int = 0) -> void:
	body_sprite.region_rect = Rect2(index * 140, row * 93, 140, 93)

func _set_strip_frame(index: int) -> void:
	_set_frame(index % 8, index / 8)

func _on_damage(_amount: int, _at: Vector2) -> void:
	flash_left = 0.1

func _on_death() -> void:
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()
