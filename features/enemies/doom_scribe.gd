class_name DoomScribe
extends CharacterBody2D

signal cast_requested(at: Vector2, direction: Vector2, settings: ScribeConfig)
signal defeated
enum State { IDLE, WINDUP, RELEASE, RECOVER, HURT, DEAD }
@export var config: ScribeConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
var target: Player
var state := State.IDLE
var timer := 0.0
var flash_left := 0.0
var facing := -1.0
var locked_direction := Vector2.LEFT
var casts := 0

func _ready() -> void:
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	_enter(State.IDLE)

func cast_origin() -> Vector2:
	# Start inside the body: a forward offset must never spawn beyond a thin wall.
	return global_position + Vector2(0, -28)

func can_see_target() -> bool:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		return false
	var aim := target.global_position + Vector2(0,-24)
	if cast_origin().distance_to(aim) > config.detection_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(cast_origin(), aim, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	timer = maxf(0, timer - delta)
	flash_left = maxf(0, flash_left - delta)
	velocity.y = minf(velocity.y + 1600 * delta, 950)
	velocity.x = move_toward(velocity.x, 0, 650 * delta)
	match state:
		State.IDLE:
			if can_see_target():
				locked_direction = (target.global_position + Vector2(0,-24) - cast_origin()).normalized()
				facing = -1.0 if locked_direction.x < 0 else 1.0
				_enter(State.WINDUP)
		State.WINDUP:
			if not is_instance_valid(target) or target.state == Player.State.DEAD:
				_enter(State.RECOVER)
			elif timer <= 0:
				_enter(State.RELEASE)
				casts += 1
				cast_requested.emit(cast_origin(), locked_direction, config)
				Audio.play_sound("attack")
		State.RELEASE:
			if timer <= 0:
				_enter(State.RECOVER)
		State.RECOVER:
			if timer <= 0:
				_enter(State.IDLE)
		State.HURT:
			if timer <= 0:
				_enter(State.RECOVER)
	move_and_slide()
	sprite.flip_h = facing < 0
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	queue_redraw()

func _enter(next: State) -> void:
	state = next
	sprite.speed_scale = 1
	match state:
		State.IDLE: sprite.play("idle")
		State.WINDUP:
			timer = config.windup_seconds
			sprite.play("cast")
			sprite.speed_scale = 4.0 / (8.0 * maxf(timer,0.01))
		State.RELEASE:
			timer = config.release_seconds
			sprite.play("release")
		State.RECOVER:
			timer = config.recovery_seconds
			sprite.play("idle")
		State.HURT:
			timer = 0.22
			sprite.play("hurt")
		State.DEAD:
			velocity = Vector2.ZERO
			sprite.modulate = Color.WHITE
			sprite.play("death")

func _on_damage(_amount: int, source: Vector2) -> void:
	flash_left = 0.08
	_enter(State.HURT)
	velocity.x = 90 * (-1 if source.x > global_position.x else 1)

func _on_death() -> void:
	_enter(State.DEAD)
	$ContactBox.end_swing()
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()
	queue_redraw()
	await sprite.animation_finished
	queue_free()

func _draw() -> void:
	if state == State.DEAD:
		return
	if state == State.WINDUP:
		var origin := Vector2(0,-28)
		var charge := 1.0 - timer / maxf(config.windup_seconds,0.01)
		var ink := Color("cfa8ff")
		draw_arc(origin, 12 + charge * 5, 0, TAU * charge, 24, ink, 2)
		for i: int in range(3):
			var start := origin + locked_direction * (24 + i * 14)
			draw_line(start, start + locked_direction * 7, Color(ink,0.65), 1)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-66),Vector2(4,-61),Vector2(0,-56),Vector2(-4,-61)]), ink)
	if health.current < health.maximum:
		draw_rect(Rect2(-15,-51,30,3), Color("28383e"))
		draw_rect(Rect2(-15,-51,30.0*health.current/health.maximum,3), Color("cfa8ff"))
