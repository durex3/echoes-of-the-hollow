class_name Player
extends CharacterBody2D

signal died
enum State { MOVE, ATTACK, HURT, DEAD }
@export var config: PlayerConfig
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var visual: Node2D = $Visual
@onready var health: HealthComponent = $Health
@onready var attack_box: Hitbox = $AttackBox
@onready var slash: Node2D = $Visual/Slash
var state := State.MOVE
var facing := 1.0
var coyote_left := 0.0
var buffer_left := 0.0
var state_left := 0.0
var air_jump_used := false

func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	attack_box.landed.connect(func() -> void: Audio.play_sound("hit"))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	state_left = maxf(0.0, state_left - delta)
	buffer_left = maxf(0.0, buffer_left - delta)
	coyote_left = config.coyote_seconds if is_on_floor() else maxf(0, coyote_left - delta)
	if is_on_floor():
		air_jump_used = false
	if Input.is_action_just_pressed("jump"):
		buffer_left = config.buffer_seconds
	var direction := Input.get_axis("move_left", "move_right")
	if state in [State.ATTACK, State.HURT] and state_left <= 0:
		state = State.MOVE
	if state != State.HURT:
		if state == State.MOVE and direction != 0:
			facing = signf(direction)
		var target := direction * config.run_speed * (0.35 if state == State.ATTACK else 1.0)
		velocity.x = move_toward(velocity.x, target, (config.acceleration if direction else config.friction) * delta)
		if buffer_left > 0:
			if coyote_left > 0:
				_jump(false)
			elif Session.abilities.has("double_jump") and not air_jump_used:
				_jump(true)
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= 0.45
		if state == State.MOVE and Input.is_action_just_pressed("attack"):
			state = State.ATTACK
			state_left = config.attack_duration
			attack_box.begin_swing()
			Audio.play_sound("attack")
	velocity.y = minf(velocity.y + config.gravity() * (config.fall_multiplier if velocity.y > 0 else 1.0) * delta, 950)
	attack_box.position.x = facing * 30
	attack_box.active = state == State.ATTACK and state_left < 0.25 and state_left > 0.08
	move_and_slide()
	_update_animation()
	if global_position.y > 850:
		health.invulnerability_left = 0
		health.take_damage(health.maximum, global_position)

func _jump(air: bool) -> void:
	velocity.y = config.jump_velocity()
	coyote_left = 0
	buffer_left = 0
	air_jump_used = air
	Audio.play_sound("jump")

func _update_animation() -> void:
	visual.scale.x = facing
	slash.visible = attack_box.active
	if slash.visible:
		slash.rotation = (0.25 - state_left) * 6.0 - 0.6
	visual.modulate.a = 0.45 if health.invulnerability_left > 0 and int(health.invulnerability_left * 18) % 2 else 1.0
	match state:
		State.ATTACK: sprite.play("attack")
		State.HURT: sprite.play("hurt")
		_:
			if not is_on_floor():
				sprite.play("jump" if velocity.y < 0 else "fall")
			else:
				sprite.play("run" if absf(velocity.x) > 8 else "idle")

func _on_damaged(_amount: int, origin: Vector2) -> void:
	state = State.HURT
	state_left = 0.24
	attack_box.end_swing()
	velocity = Vector2(180 * (-1 if origin.x > global_position.x else 1), -180)
	Audio.play_sound("hit")

func _on_died() -> void:
	state = State.DEAD
	attack_box.end_swing()
	slash.hide()
	sprite.play("death")
	died.emit()

func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	state = State.MOVE
	state_left = 0
	coyote_left = 0
	buffer_left = 0
	air_jump_used = false
	health.restore_full()
	visual.modulate = Color.WHITE
