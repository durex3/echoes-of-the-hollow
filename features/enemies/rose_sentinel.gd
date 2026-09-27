class_name RoseSentinel
extends CharacterBody2D
## Retreat establishes spacing; a fixed warning precedes a short ground slash.
signal defeated
signal impact(at: Vector2, killed: bool)
enum State { IDLE, APPROACH, RETREAT, WARNING, STRIKE, RECOVER, DEAD }
@export var config: RoseConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var edge: RayCast2D = $Edge
var target: Player
var state := State.IDLE
var facing := -1.0
var timer := 0.0
var flash_left := 0.0

func _ready() -> void:
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	attack_box.damage = config.damage
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	_enter(State.IDLE)

func can_see_target() -> bool:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		return false
	var offset := target.global_position-global_position
	if offset.length() > config.detection_range or absf(offset.y) > 55:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-24),target.global_position+Vector2(0,-24),1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	if state == State.DEAD:
		if timer <= 0:
			queue_free()
		return
	velocity = Vector2(0,minf(950,velocity.y+config.gravity*delta))
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		if state != State.IDLE:
			_enter(State.IDLE)
	match state:
		State.IDLE:
			if is_on_floor() and can_see_target():
				_enter(State.APPROACH)
		State.APPROACH:
			if not can_see_target():
				_enter(State.IDLE)
			else:
				facing = -1.0 if target.global_position.x < global_position.x else 1.0
				if absf(target.global_position.x-global_position.x) <= config.attack_range:
					_enter(State.RETREAT)
				else:
					_walk(facing,config.approach_speed)
		State.RETREAT:
			_walk(-facing,config.retreat_speed)
			if timer <= 0:
				_enter(State.WARNING)
		State.WARNING:
			if timer <= 0:
				_enter(State.STRIKE)
		State.STRIKE:
			if timer <= 0 or not _walk(facing,config.strike_speed):
				_enter(State.RECOVER)
		State.RECOVER:
			if timer <= 0:
				_enter(State.IDLE)
	move_and_slide()
	sprite.flip_h = facing < 0
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	queue_redraw()

func _walk(direction: float, speed: float) -> bool:
	edge.position.x = direction*24
	edge.force_raycast_update()
	if not edge.is_colliding():
		return false
	velocity.x = direction*speed
	# test_move uses the new direction, so a wall behind cannot block retreat.
	if test_move(transform,Vector2(direction*5,0)):
		velocity.x = 0
		return false
	return true

func _enter(next: State) -> void:
	state = next
	attack_box.end_swing()
	velocity.x = 0
	match state:
		State.IDLE:
			_clip("idle")
		State.APPROACH:
			_clip("step")
		State.RETREAT:
			timer = config.retreat_seconds
			_clip("step")
		State.WARNING:
			timer = config.warning_seconds
			_clip("warning",timer)
		State.STRIKE:
			timer = config.strike_seconds
			attack_box.position.x = facing*29
			attack_box.begin_swing()
			attack_box.active = true
			_clip("strike",timer)
			Audio.play_sound("attack",0.9,-3)
		State.RECOVER:
			timer = config.recovery_seconds
			_clip("recover",timer)
		State.DEAD:
			timer = 1.0
			_clip("death",timer)
	queue_redraw()

func _clip(animation: StringName, duration := 0.0) -> void:
	sprite.stop()
	sprite.offset.x = config.stride_sprite_offset if animation == &"step" else 0.0
	sprite.speed_scale = 1.0
	if duration > 0:
		sprite.speed_scale = sprite.sprite_frames.get_frame_count(animation)/(sprite.sprite_frames.get_animation_speed(animation)*duration)
	sprite.play(animation)

func _on_damaged(_amount: int, _at: Vector2) -> void:
	flash_left = 0.08
	if health.current > 0:
		_enter(State.RECOVER)
		_clip("hurt",timer)

func _on_died() -> void:
	_enter(State.DEAD)
	$ContactBox.end_swing()
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()

func _draw() -> void:
	if state == State.DEAD:
		return
	if state == State.WARNING:
		draw_line(Vector2(0,-101),Vector2(0,-91),Color("f1c47b"),3)
		draw_circle(Vector2(0,-86),2,Color("f1c47b"))
	if health.current < health.maximum:
		draw_rect(Rect2(-16,-67,32,3),Color("28383e"))
		draw_rect(Rect2(-16,-67,32.0*health.current/health.maximum,3),Color("f1c47b"))
