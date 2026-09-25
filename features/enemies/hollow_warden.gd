class_name HollowWarden
extends CharacterBody2D

signal defeated
signal awakened
signal phase_changed(phase: int)
signal impact(at: Vector2, killed: bool)
enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, RECOVER, TRANSITION, DEAD }
@export var config: WardenConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
var target: Player
var state := State.DORMANT
var phase := 1
var facing := -1.0
var timer := 0.0
var flash_left := 0.0
var rush_attack := false
var attack_count := 0
var active_profile: AttackProfile

func _ready() -> void:
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	_play_clip("idle")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		attack_box.end_swing()
		velocity = Vector2.ZERO
		return
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	velocity.x = 0
	velocity.y = minf(velocity.y+1600*delta,950)
	match state:
		State.DORMANT:
			if target.position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO, State.TRANSITION:
			if timer <= 0:
				_enter(State.CHASE)
		State.CHASE:
			facing = -1.0 if target.global_position.x < global_position.x else 1.0
			if absf(target.global_position.x-global_position.x) <= config.attack_range or attack_count % 2 == 1:
				_start_attack()
			else:
				velocity.x = facing*(config.phase_two_speed if phase == 2 else config.chase_speed)
		State.WINDUP:
			if timer <= 0:
				_enter(State.STRIKE)
		State.STRIKE:
			if timer <= 0:
				_enter(State.RECOVER)
			elif rush_attack:
				velocity.x = facing*config.rush_speed
		State.RECOVER:
			if timer <= 0:
				if phase == 1 and health.current <= config.maximum_health/2:
					phase = 2
					phase_changed.emit(phase)
					_enter(State.TRANSITION)
				else:
					_enter(State.CHASE)
	move_and_slide()
	if state == State.STRIKE and rush_attack and is_on_wall():
		_enter(State.RECOVER)
	sprite.flip_h = facing > 0
	sprite.modulate = Color(2.8,2.8,2.8) if flash_left > 0 and not Session.reduce_flashes else Color(1.9,1.65,1.25)
	queue_redraw()

func _start_attack() -> void:
	rush_attack = attack_count % 2 == 1
	attack_count += 1
	active_profile = config.rush if rush_attack else config.sweep
	_enter(State.WINDUP)

func _enter(next: State) -> void:
	state = next
	attack_box.end_swing()
	velocity.x = 0
	match state:
		State.INTRO, State.TRANSITION:
			timer = config.intro_seconds if state == State.INTRO else config.transition_seconds
			_play_clip("idle")
		State.CHASE:
			_play_clip("walk")
		State.WINDUP:
			timer = active_profile.windup
			attack_box.position.x = facing*44
			attack_box.damage = active_profile.damage
			attack_box.begin_swing()
			_play_clip("windup",timer)
		State.STRIKE:
			timer = active_profile.active_seconds
			attack_box.active = true
			_play_clip("strike",timer)
			Audio.play_sound("attack")
		State.RECOVER:
			timer = active_profile.recovery*(config.phase_two_recovery_scale if phase == 2 else 1.0)
			_play_clip("recover",timer)
		State.DEAD:
			velocity = Vector2.ZERO
			_play_clip("death")

func _play_clip(animation: StringName, duration := 0.0) -> void:
	sprite.stop()
	sprite.speed_scale = 1.0
	if duration > 0:
		var frames := sprite.sprite_frames
		sprite.speed_scale = frames.get_frame_count(animation)/(frames.get_animation_speed(animation)*duration)
	sprite.play(animation)

func _on_damage(_amount: int, _at: Vector2) -> void:
	flash_left = 0.08
	# Hits never shorten warnings or erase recovery; no stun-lock loop.
	if state == State.DORMANT:
		_enter(State.INTRO)
		awakened.emit()

func _on_death() -> void:
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()
	queue_redraw()
	await sprite.animation_finished
	queue_free()

func _draw() -> void:
	if state == State.DEAD:
		return
	if state in [State.INTRO,State.TRANSITION]:
		draw_arc(Vector2(0,-42),50,PI,TAU,32,Color("94e4ce"),2)
	if state == State.WINDUP:
		var tint := Color("94e4ce") if rush_attack else Color("f5c773")
		var reach := config.rush_speed*config.rush.active_seconds+80 if rush_attack else 80.0
		draw_line(Vector2(facing*12,-4),Vector2(facing*reach,-4),tint,3)
		if rush_attack:
			draw_line(Vector2(facing*(reach-12),-14),Vector2(facing*reach,-4),tint,3)
		else:
			draw_arc(Vector2(0,-28),70,-1 if facing>0 else PI-1,1 if facing>0 else PI+1,24,tint,2)
	elif state == State.STRIKE:
		draw_arc(Vector2(0,-28),70,-1 if facing>0 else PI-1,1 if facing>0 else PI+1,24,Color("e9d5bc"),3)
