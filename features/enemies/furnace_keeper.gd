class_name FurnaceKeeper
extends CharacterBody2D
## Stationary pressure caster: jump a low wave, leave a locked eruption marker.
signal defeated
signal awakened
signal withdrawn
signal phase_changed(phase: int)
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)
const FLAME := preload("res://features/combat/furnace_flame.tscn")
enum State { DORMANT, INTRO, WARNING, CAST, RECOVER, TRANSITION, DEAD }
@export var config: FurnaceConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var flames: Node2D = $Flames
var target: Player
var state := State.DORMANT
var phase := 1
var timer := 0.0
var attack_count := 0
var wave_attack := true
var facing := -1.0
var locked_x := 0.0
var flash_left := 0.0

func _ready() -> void:
	($Hurtbox as Hurtbox).damage_guard = pressure_guard
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	_enter(State.DORMANT)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD or target.position.x < config.retreat_x:
		if state != State.DORMANT:
			reset_encounter()
		return
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	match state:
		State.DORMANT:
			if target.position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO, State.TRANSITION:
			if timer <= 0:
				start_attack()
		State.WARNING:
			if timer <= 0:
				_enter(State.CAST)
		State.CAST:
			if timer <= 0:
				_enter(State.RECOVER)
		State.RECOVER:
			if timer <= 0:
				if phase == 1 and health.current <= config.maximum_health/2 and attack_count >= 2:
					phase = 2
					phase_changed.emit(phase)
					_enter(State.TRANSITION)
				else:
					start_attack()
	velocity = Vector2(0,minf(950,velocity.y+1600*delta))
	move_and_slide()
	sprite.flip_h = facing < 0
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	queue_redraw()

func start_attack() -> void:
	facing = -1 if target.position.x < position.x else 1
	locked_x = clampf(target.position.x,config.arena_min_x+40,config.arena_max_x-40)
	wave_attack = attack_count % 2 == 0
	attack_count += 1
	_enter(State.WARNING)

func _enter(next: State) -> void:
	state = next
	match state:
		State.DORMANT:
			clip("idle")
		State.INTRO, State.TRANSITION:
			timer = config.intro_seconds if state == State.INTRO else config.transition_seconds
			clip("idle")
			cue_changed.emit("Keeper awakens" if state == State.INTRO else "Phase II / Twin eruption marks")
			Audio.play_sound("ability_acquire",0.65,-8)
		State.WARNING:
			timer = config.warning_seconds
			clip("warning",timer)
			cue_changed.emit("LOW FLAME / Jump over" if wave_attack else "ERUPTION / Leave the marked ground")
			Audio.play_sound("jump" if wave_attack else "attack",0.7,-6)
			if not wave_attack:
				spawn_flame(Vector2(locked_x,config.floor_y),false)
				if phase == 2:
					var other_x := locked_x-config.eruption_spacing*facing
					if other_x < config.arena_min_x+40 or other_x > config.arena_max_x-40:
						other_x = locked_x+config.eruption_spacing*facing
					spawn_flame(Vector2(other_x,config.floor_y),false)
		State.CAST:
			timer = config.eruption_seconds
			clip("strike",timer)
			if wave_attack:
				spawn_flame(Vector2(position.x+facing*45,config.floor_y),true)
		State.RECOVER:
			timer = config.recovery_seconds
			clip("recover",timer)
			cue_changed.emit("PRESSURE RELEASE / Strike now")
		State.DEAD:
			clear_flames()
			clip("death",1.0)
	queue_redraw()

func spawn_flame(at: Vector2, is_wave: bool) -> void:
	var flame := FLAME.instantiate() as FurnaceFlame
	flame.config = config
	flame.wave = is_wave
	flame.direction = facing
	flame.position = flames.to_local(at)
	flame.impact.connect(func(where: Vector2, killed: bool) -> void: impact.emit(where,killed))
	flames.add_child(flame)

func clear_flames() -> void:
	for flame: FurnaceFlame in flames.get_children():
		flame.retire()

func reset_encounter() -> void:
	clear_flames()
	phase = 1
	attack_count = 0
	health.restore_full()
	_enter(State.DORMANT)
	withdrawn.emit()

func clip(animation: StringName, duration := 0.0) -> void:
	sprite.stop()
	sprite.speed_scale = 1.0
	if duration > 0:
		sprite.speed_scale = sprite.sprite_frames.get_frame_count(animation)/(sprite.sprite_frames.get_animation_speed(animation)*duration)
	sprite.play(animation)

func _on_damage(_amount: int, _origin: Vector2) -> void:
	flash_left = 0.08
	# Damage never cancels telegraphs, casts or the recovery window.
	if state == State.DORMANT:
		_enter(State.INTRO)
		awakened.emit()

func pressure_guard() -> bool:
	return state != State.RECOVER

func _on_death() -> void:
	_enter(State.DEAD)
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()
	await sprite.animation_finished
	queue_free()

func _draw() -> void:
	if state == State.DEAD:
		return
	# A static pressure seal distinguishes the casting boss without extra collision.
	if state != State.RECOVER:
		draw_arc(Vector2(0,-35),48,0,TAU,24,Color("ff9bcc"),1)
	if state == State.WARNING and wave_attack:
		draw_line(Vector2(facing*24,-4),Vector2(facing*175,-4),Color("efb268"),3)
		draw_line(Vector2(facing*165,-15),Vector2(facing*175,-4),Color("efb268"),3)
