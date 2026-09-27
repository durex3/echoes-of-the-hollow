class_name Slime
extends CharacterBody2D

enum State { PATROL, HURT, DEAD }
@export var patrol_distance := 100.0
@export var speed := 44.0
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $Health
@onready var contact: Hitbox = $Contact
@onready var edge: RayCast2D = $Edge
@onready var stagger: EnemyStagger = $Stagger
var state := State.PATROL
var direction := -1.0
var origin_x := 0.0
var timer := 0.0
var flash_left := 0.0

func _ready() -> void:
	origin_x = position.x
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	contact.begin_swing()
	contact.active = true

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	timer -= delta
	flash_left = maxf(0,flash_left-delta)
	sprite.modulate = Color(2,2,2) if flash_left>0 and not Session.reduce_flashes else Color.WHITE
	velocity.y += 1600 * delta
	if state == State.HURT:
		velocity.x = move_toward(velocity.x, 0, 700 * delta)
		if timer <= 0:
			state = State.PATROL
			sprite.modulate = Color.WHITE
	else:
		# Knockback can leave the patrol interval. Return inward instead of
		# reversing every frame while still outside it.
		if absf(position.x-origin_x)>patrol_distance:
			direction = signf(origin_x-position.x)
		edge.position.x = direction * 20
		edge.force_raycast_update()
		if is_on_floor() and (not edge.is_colliding() or test_move(global_transform,Vector2(direction*speed*delta,0))):
			direction *= -1
			edge.position.x = direction*20
			edge.force_raycast_update()
		velocity.x = direction*speed if edge.is_colliding() and not test_move(global_transform,Vector2(direction*speed*delta,0)) else 0.0
		sprite.flip_h = direction > 0
		sprite.play("idle")
	move_and_slide()

func _on_damaged(_amount: int, source: Vector2) -> void:
	flash_left = 0.08
	if not stagger.register_hit():
		return
	state = State.HURT
	timer = 0.2
	velocity = Vector2(150 * signf(global_position.x - source.x), -130)
	sprite.modulate = Color.WHITE if Session.reduce_flashes else Color(2, 2, 2)

func _on_died() -> void:
	state = State.DEAD
	contact.end_swing()
	$Hurtbox.set_deferred("monitorable", false)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
