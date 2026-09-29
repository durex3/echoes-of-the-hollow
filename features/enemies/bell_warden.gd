class_name BellWarden
extends CharacterBody2D

signal defeated
signal awakened
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)

enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, RECOVER, DEAD, STAGGER }
enum Attack { SWEEP, DASH, DOUBLE_ECHO, LAYER_RESONANCE }

@export var config: BellWardenConfig
@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var contact_box: Hitbox = $ContactBox
@onready var combat_effect: BellWardenEffect = $CombatEffect
const DecisionScript = preload("res://features/enemies/bell_warden_decision.gd")
var decision: RefCounted = DecisionScript.new()
@onready var state_machine: BossStateMachine = $BossStateMachine
var attack_states := {}
var target: Player
var state := State.DORMANT
var attack := Attack.SWEEP
var facing := -1.0
var timer := 0.0
var attack_count := 0
var regular_attacks := 0
var contact_refresh := 0.0
var flash_left := 0.0
var walk_clock := 0.0
var action_elapsed := 0.0

func _ready() -> void:
	attack_states = state_machine.setup(self)
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
		state_machine.finish()
		attack_box.end_swing()
		contact_box.end_swing()
		velocity = Vector2.ZERO
		return
	timer = maxf(0.0, timer - delta)
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
		State.WINDUP, State.STRIKE, State.RECOVER:
			pass
		State.STAGGER:
			if timer <= 0.0: _enter(State.CHASE)
	move_and_slide()
	contact_box.active = state in [State.CHASE, State.WINDUP, State.STRIKE] and (state == State.CHASE or attack in [Attack.SWEEP, Attack.DASH])
	contact_box.damage = 1
	global_position.x = clampf(global_position.x, config.arena_min_x, config.arena_max_x)
	_update_visual()
	combat_effect.configure(int(state), int(attack), facing, timer, _windup(), _active())

func _start_attack() -> void:
	if not state_machine.can_decide():
		return
	var distance := absf(target.global_position.x - global_position.x)
	var airborne := target.global_position.y < global_position.y - 34.0
	var selected: int = decision.choose_attack(distance, airborne, regular_attacks, (attack_states[Attack.DASH] as BossAttackState).ready(), (attack_states[Attack.SWEEP] as BossAttackState).ready(), (attack_states[Attack.DOUBLE_ECHO] as BossAttackState).ready(), (attack_states[Attack.LAYER_RESONANCE] as BossAttackState).ready(), target.is_on_floor(), int(attack))
	if selected < 0:
		return
	attack = selected as Attack
	(attack_states[attack] as BossAttackState).arm()
	state_machine.change(attack_states[attack])
	attack_count += 1
	if attack != Attack.SWEEP:
		regular_attacks = 0
	else:
		regular_attacks += 1

func _enter(next: State) -> void:
	state = next
	if next in [State.CHASE, State.DEAD]:
		state_machine.finish()
	action_elapsed = 0.0
	velocity.x = 0.0
	attack_box.end_swing()
	match state:
		State.INTRO:
			timer = config.intro_seconds
			cue_changed.emit("缚钟守望者苏醒")
		State.CHASE:
			timer = maxf(timer, config.attack_gap_seconds)
			contact_box.begin_swing()
		State.STAGGER:
			timer = config.stagger_seconds
			contact_box.end_swing()
		State.DEAD:
			attack_box.end_swing()
			contact_box.end_swing()

func _windup() -> float:
	if attack == Attack.DOUBLE_ECHO:
		return config.double_echo_record_gap * 2.0
	if attack == Attack.LAYER_RESONANCE:
		return config.resonance_charge
	return config.sweep_windup if attack == Attack.SWEEP else config.dash_windup

func _active() -> float:
	if attack == Attack.DOUBLE_ECHO:
		return config.double_echo_warning + config.double_echo_record_gap + config.double_echo_active + 0.12
	if attack == Attack.LAYER_RESONANCE:
		return config.resonance_active_seconds
	return config.sweep_active if attack == Attack.SWEEP else config.dash_active

func _update_visual() -> void:
	body_sprite.flip_h = facing > 0.0
	body_sprite.position.x = facing * 40.0
	body_sprite.modulate = Color(2.6, 2.6, 2.6) if flash_left > 0.0 and not Session.reduce_flashes else Color.WHITE
	if attack in [Attack.DOUBLE_ECHO, Attack.LAYER_RESONANCE] and state in [State.WINDUP, State.STRIKE]:
		_set_strip_frame(40 + mini(5, int(action_elapsed * 8.0)))
	elif state == State.WINDUP:
		_set_strip_frame(16 + mini(3, int(action_elapsed / maxf(_windup(), 0.01) * 4.0)))
	elif state == State.STRIKE:
		_set_strip_frame(20 + mini(3, int(action_elapsed / maxf(_active(), 0.01) * 4.0)))
	elif state in [State.CHASE, State.RECOVER] and absf(velocity.x) > 2.0:
		var step := int(walk_clock * 14.0) % 8
		_set_frame(7 - step if velocity.x * facing < 0.0 else step, 1)
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
