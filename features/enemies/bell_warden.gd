class_name BellWarden
extends CharacterBody2D

signal defeated
signal awakened
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)

enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, ECHO_WARNING, ECHO_ACTIVE, RECOVER, DEAD, GHOST_WARNING, GHOST_ACTIVE }
enum Attack { SWEEP, DASH, ECHO }

@export var config: BellWardenConfig
@onready var health: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var contact_box: Hitbox = $ContactBox
var target: Player
var state := State.DORMANT
var attack := Attack.SWEEP
var attack_count := 0
var facing := -1.0
var timer := 0.0
var flash_left := 0.0
var mark: EchoMark
var phase := 1
var last_attack := -1
var last_mark_position := Vector2.ZERO
var ghost: EchoMark
var ghost_combo_pending := false

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
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		attack_box.end_swing()
		contact_box.end_swing()
		velocity = Vector2.ZERO
		return
	timer = maxf(0.0, timer - delta)
	flash_left = maxf(0.0, flash_left - delta)
	velocity.y = minf(velocity.y + 1600.0 * delta, 950.0)
	match state:
		State.DORMANT:
			if target.global_position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO:
			if timer <= 0.0:
				_enter(State.CHASE)
		State.CHASE:
			facing = signf(target.global_position.x - global_position.x)
			if timer > 0.0:
				pass
			elif absf(target.global_position.x - global_position.x) <= config.sweep_range:
				_start_attack()
			else:
				velocity.x = facing * config.move_speed
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
			if timer <= 0.0:
				_enter(State.RECOVER)
		State.GHOST_WARNING:
			if timer <= 0.0:
				_enter(State.GHOST_ACTIVE)
		State.GHOST_ACTIVE:
			if timer <= 0.0:
				_enter(State.RECOVER)
		State.RECOVER:
			if timer <= 0.0:
				if phase == 1 and health.current <= config.phase_two_threshold:
					phase = 2
				if phase == 2 and health.current <= config.phase_three_threshold:
					phase = 3
				_enter(State.CHASE)
	move_and_slide()
	contact_box.active = state in [State.CHASE, State.WINDUP, State.STRIKE, State.ECHO_WARNING, State.ECHO_ACTIVE, State.RECOVER]
	global_position.x = clampf(global_position.x, config.arena_min_x, config.arena_max_x)
	_update_visual()

func _start_attack() -> void:
	if phase >= 2 and attack_count > 0 and attack_count % 2 == 0:
		ghost_combo_pending = phase == 3
		_enter(State.GHOST_WARNING)
		attack_count += 1
		return
	attack = Attack.SWEEP if ghost_combo_pending or attack_count == 0 else Attack.DASH if attack_count == 1 else Attack.ECHO if attack_count % 3 == 2 else Attack.SWEEP
	ghost_combo_pending = false
	if int(attack) == last_attack:
		attack = Attack.DASH if attack == Attack.SWEEP else Attack.SWEEP
	last_attack = int(attack)
	attack_count += 1
	_enter(State.ECHO_WARNING if attack == Attack.ECHO else State.WINDUP)

func _enter(next: State) -> void:
	state = next
	velocity.x = 0.0
	attack_box.end_swing()
	if next in [State.DORMANT, State.INTRO, State.DEAD]:
		contact_box.end_swing()
	match state:
		State.INTRO:
			timer = config.intro_seconds
			cue_changed.emit("缚钟守望者苏醒")
		State.CHASE:
			timer = maxf(timer, config.attack_gap_seconds)
			contact_box.begin_swing()
		State.WINDUP:
			timer = config.sweep_windup if attack == Attack.SWEEP else config.dash_windup
			attack_box.position.x = facing * (44.0 if attack == Attack.SWEEP else 52.0)
			attack_box.damage = 1
			attack_box.begin_swing()
			contact_box.hit_ids = attack_box.hit_ids
			cue_changed.emit("镰刀横扫 / 后撤或绕到身后" if attack == Attack.SWEEP else "锁向镰突 / 跳过或绕后")
		State.STRIKE:
			timer = config.sweep_active if attack == Attack.SWEEP else config.dash_active
			contact_box.hit_ids = attack_box.hit_ids
			attack_box.active = true
			_clear_ghost_on_scythe()
		State.ECHO_WARNING:
			timer = config.echo_windup
			cue_changed.emit("回声标记 / 离开脚下印记")
			_spawn_mark()
		State.ECHO_ACTIVE:
			timer = config.echo_active
			cue_changed.emit("幽魂波 / 离开标记范围")
		State.GHOST_WARNING:
			timer = config.ghost_warning
			cue_changed.emit("定点幽魂 / 离开回声旧位")
			_spawn_ghost()
		State.GHOST_ACTIVE:
			timer = config.ghost_active
		State.RECOVER:
			timer = config.ghost_recovery if phase == 2 and is_instance_valid(ghost) else config.sweep_recovery if attack == Attack.SWEEP else config.dash_recovery if attack == Attack.DASH else config.echo_recovery
			contact_box.begin_swing()
			cue_changed.emit("反击窗口")
		State.DEAD:
			attack_box.end_swing()
			contact_box.end_swing()
			_set_frame(4)

func _spawn_mark() -> void:
	if is_instance_valid(mark):
		mark.queue_free()
	mark = EchoMark.new()
	mark.player = target
	mark.delay_seconds = config.echo_windup + config.echo_delay
	mark.active_seconds = config.echo_active
	mark.radius = config.echo_radius
	mark.damage = config.echo_damage
	last_mark_position = target.global_position
	mark.global_position = last_mark_position
	get_parent().add_child(mark)

func _spawn_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = EchoMark.new()
	ghost.player = target
	ghost.delay_seconds = config.ghost_warning + (config.ghost_active + config.ghost_recovery + config.attack_gap_seconds + config.sweep_windup + 0.2 if phase == 3 else 0.0)
	ghost.active_seconds = config.ghost_active
	ghost.radius = config.ghost_radius
	ghost.damage = config.echo_damage
	ghost.ghost_visual = true
	ghost.global_position = last_mark_position if last_mark_position != Vector2.ZERO else target.global_position
	get_parent().add_child(ghost)

func _clear_ghost_on_scythe() -> void:
	if not is_instance_valid(ghost):
		return
	var toward := (ghost.global_position.x - global_position.x) * facing
	if toward >= -12.0 and toward <= 112.0 and absf(ghost.global_position.y - global_position.y) <= 58.0:
		ghost.dispel()

func _update_visual() -> void:
	body_sprite.flip_h = facing < 0.0
	body_sprite.modulate = Color(2.6, 2.6, 2.6) if flash_left > 0.0 and not Session.reduce_flashes else Color.WHITE
	if state == State.WINDUP:
		_set_frame(3, 2)
	elif state == State.STRIKE:
		_set_frame(4, 2)
	elif state in [State.ECHO_WARNING, State.ECHO_ACTIVE, State.GHOST_WARNING, State.GHOST_ACTIVE]:
		_set_frame(0, 5)
	else:
		_set_frame(0, 0)

func _set_frame(index: int, row: int = 0) -> void:
	body_sprite.region_rect = Rect2(index * 140, row * 93, 140, 93)

func _on_damage(_amount: int, _at: Vector2) -> void:
	flash_left = 0.1

func _on_death() -> void:
	if is_instance_valid(mark):
		mark.queue_free()
	if is_instance_valid(ghost):
		ghost.queue_free()
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()
