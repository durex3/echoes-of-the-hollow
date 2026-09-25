class_name WingedChest
extends CharacterBody2D
## Wing-assisted short pounce: warning locks direction, miss exposes recovery.
signal defeated
signal impact(at: Vector2, killed: bool)
enum State { IDLE, WARNING, LUNGE, RECOVER, DEAD }
@export var config: ChestConfig
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
	var offset := target.global_position - global_position
	if offset.length() > config.detection_range or absf(offset.y) > 48:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-20),target.global_position+Vector2(0,-20),1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	if state == State.DEAD:
		sprite.modulate.a = timer / config.death_seconds
		if timer <= 0:
			queue_free()
		return
	if state in [State.WARNING, State.LUNGE] and (not is_instance_valid(target) or target.state == Player.State.DEAD):
		_enter(State.RECOVER)
	velocity.y = minf(950,velocity.y + config.gravity * delta)
	velocity.x = 0
	match state:
		State.IDLE:
			if is_on_floor() and can_see_target():
				facing = -1.0 if target.global_position.x < global_position.x else 1.0
				_enter(State.WARNING)
		State.WARNING:
			if timer <= 0:
				_enter(State.LUNGE)
		State.LUNGE:
			edge.position.x = facing * 28
			edge.force_raycast_update()
			if timer <= 0 or is_on_wall() or not edge.is_colliding():
				_enter(State.RECOVER)
			else:
				velocity.x = facing * config.lunge_speed
		State.RECOVER:
			if timer <= 0 and is_on_floor():
				_enter(State.IDLE)
	move_and_slide()
	# Source is nearly frontal; mirror wings only, never alter collision origins.
	sprite.flip_h = facing > 0
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	queue_redraw()

func _enter(next: State) -> void:
	state = next
	attack_box.end_swing()
	sprite.stop()
	match state:
		State.IDLE:
			sprite.play("idle")
		State.WARNING:
			timer = config.warning_seconds
			sprite.play("warning")
		State.LUNGE:
			timer = config.lunge_seconds
			velocity.y = -config.hop_speed
			attack_box.position.x = facing * 12
			attack_box.begin_swing()
			attack_box.active = true
			sprite.play("bite")
			Audio.play_sound("attack",1.15,-4)
		State.RECOVER:
			timer = config.recovery_seconds
			sprite.play("recover")
		State.DEAD:
			timer = config.death_seconds
			velocity = Vector2.ZERO
			sprite.play("recover")
	queue_redraw()

func _on_damaged(_amount: int, _source: Vector2) -> void:
	flash_left = 0.08
	# Sword interrupts a pounce; no contact damage persists after interruption.
	if health.current > 0:
		_enter(State.RECOVER)

func _on_died() -> void:
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()

func _draw() -> void:
	if state == State.DEAD:
		return
	if state == State.WARNING:
		var tint := Color("efb268")
		draw_line(Vector2(0,-54),Vector2(0,-63),tint,3)
		draw_circle(Vector2(0,-49),2,tint)
		draw_line(Vector2(facing*22,-3),Vector2(facing*100,-3),Color(tint,0.65),2)
	if health.current < health.maximum:
		draw_rect(Rect2(-16,-43,32,3),Color("263941"))
		draw_rect(Rect2(-16,-43,32.0*health.current/health.maximum,3),Color("e0b975"))
