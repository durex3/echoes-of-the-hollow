class_name LivingArmor
extends CharacterBody2D

signal defeated
signal impact(at: Vector2, killed: bool)
enum State { PATROL, CHASE, WINDUP, STRIKE, RECOVER, HURT, DEAD }
@export var config: ArmorConfig
@export var patrol_distance := 85.0
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var edge: RayCast2D = $Edge
var target: Player
var state := State.PATROL
var facing := -1.0
var home_x := 0.0
var timer := 0.0
var flash_left := 0.0

func _ready() -> void:
	home_x = position.x
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	attack_box.damage = config.attack.damage
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))

func can_see_target() -> bool:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		return false
	var offset := target.global_position - global_position
	if offset.length() > config.detection_range or absf(offset.y) > 55:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-25), target.global_position + Vector2(0,-25))
	ray.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	timer = maxf(0, timer - delta)
	flash_left = maxf(0, flash_left - delta)
	velocity.y = minf(velocity.y + 1600 * delta, 950)
	match state:
		State.PATROL:
			if can_see_target():
				_enter(State.CHASE)
			elif absf(position.x-home_x) >= patrol_distance:
				facing = signf(home_x-position.x)
			_walk(config.patrol_speed)
		State.CHASE:
			if not can_see_target():
				_enter(State.PATROL)
			else:
				facing = -1.0 if target.global_position.x < global_position.x else 1.0
				if absf(target.global_position.x-global_position.x) <= config.attack_range:
					_enter(State.WINDUP)
				else:
					_walk(config.chase_speed)
		State.WINDUP:
			velocity.x = 0
			if timer <= 0:
				_enter(State.STRIKE)
		State.STRIKE:
			velocity.x = 0
			if timer <= 0:
				_enter(State.RECOVER)
		State.RECOVER:
			velocity.x = 0
			if timer <= 0:
				_enter(State.PATROL)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0, delta * 650)
			if timer <= 0:
				_enter(State.RECOVER)
	move_and_slide()
	# Source armor faces left; body/attack direction stays independent of artwork.
	sprite.flip_h = facing > 0
	sprite.modulate = Color(2.8,2.8,2.8) if flash_left > 0 and not Session.reduce_flashes else Color(1.65,1.65,1.8)
	queue_redraw()

func _walk(speed: float) -> void:
	edge.position.x = facing * 19
	edge.force_raycast_update()
	if is_on_floor() and (not edge.is_colliding() or is_on_wall()):
		velocity.x = 0
		if state == State.PATROL:
			facing *= -1
		return
	velocity.x = facing * speed

func _enter(next: State) -> void:
	state = next
	attack_box.end_swing()
	match state:
		State.PATROL, State.CHASE:
			sprite.speed_scale = 1
			sprite.play("walk")
		State.WINDUP:
			velocity.x = 0
			timer = config.attack.windup
			_play_clip("windup", timer)
			attack_box.position.x = facing * 34
			attack_box.begin_swing()
		State.STRIKE:
			timer = config.attack.active_seconds
			attack_box.active = true
			_play_clip("strike", timer)
			Audio.play_sound("attack")
		State.RECOVER:
			timer = config.attack.recovery
			_play_clip("recover", timer)
		State.HURT:
			timer = 0.18
			_play_clip("recover", timer)
		State.DEAD:
			velocity = Vector2.ZERO
			sprite.modulate = Color(1.65,1.65,1.8)
			_play_clip("death")

func _play_clip(animation: StringName, duration := 0.0) -> void:
	sprite.stop()
	sprite.speed_scale = 1.0
	if duration > 0:
		var frames := sprite.sprite_frames
		sprite.speed_scale = frames.get_frame_count(animation) / (frames.get_animation_speed(animation) * duration)
	sprite.play(animation)

func _on_damage(_amount: int, at: Vector2) -> void:
	flash_left = 0.08
	# Telegraphs remain readable; recovery is the safe interruption opportunity.
	if state in [State.PATROL, State.CHASE, State.RECOVER, State.HURT]:
		_enter(State.HURT)
		velocity.x = 115 * (-1 if at.x > global_position.x else 1)

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
		draw_line(Vector2(-3,-63), Vector2(0,-72), Color("f5c773"), 3)
		draw_circle(Vector2(0,-58), 2, Color("f5c773"))
		draw_line(Vector2(facing*10,-3), Vector2(facing*65,-3), Color(1,0.7,0.3,0.7), 2)
	elif state == State.STRIKE:
		var start := -1.0 if facing > 0 else PI - 1.0
		draw_arc(Vector2(0,-24), 51, start, start+2.0, 16, Color("e9d5bc"), 3)
	if health.current < health.maximum:
		draw_rect(Rect2(-16,-51,32,3), Color("28383e"))
		draw_rect(Rect2(-16,-51,32.0*health.current/health.maximum,3), Color("e0b975"))
