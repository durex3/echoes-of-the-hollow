class_name FurnaceKeeper
extends CharacterBody2D
signal defeated
signal awakened
signal withdrawn
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)
const FLAME := preload("res://features/combat/furnace_flame.tscn")
const BURST := preload("res://features/enemies/boss_visual_burst.gd")
enum State { DORMANT, INTRO, WARNING, CAST, RECOVER, DEAD, TAKEOFF, LANDING, IMPACT, APPROACH }
enum Attack { DASH, HOP, SLAM, MELEE, COMBO }
@export var config: FurnaceConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var flames: Node2D = $Flames
@onready var dash_hitbox: Hitbox = $DashHitbox
@onready var contact_box: Hitbox = $ContactBox
const FurnaceKeeperDecisionScript = preload("res://features/enemies/furnace_keeper_decision.gd")
var decision: RefCounted = FurnaceKeeperDecisionScript.new()
@onready var state_machine: BossStateMachine = $BossStateMachine
var attack_states := {}
var target: Player
var state := State.DORMANT
var attack := Attack.DASH
var timer := 0.0
var attack_count := 0
var regular_attacks := 0
var facing := -1.0
var flash_left := 0.0
var combo_left := 0
var home_position := Vector2.ZERO
var last_attack := -1

func _ready() -> void:
	attack_states = state_machine.setup(self)
	home_position = position
	flames.top_level = true
	($Hurtbox as Hurtbox).damage_guard = pressure_guard
	dash_hitbox.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	_enter(State.DORMANT)
	contact_box.end_swing()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		if state != State.DORMANT:
			reset_encounter()
		return
	contact_box.active = state not in [State.DORMANT, State.INTRO, State.DEAD]
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	match state:
		State.DORMANT:
			if target.position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO:
			if timer <= 0:
				start_attack()
		State.TAKEOFF, State.WARNING, State.CAST, State.LANDING, State.IMPACT, State.RECOVER, State.APPROACH:
			pass
	var executing_attack := state_machine.current != null
	state_machine.tick(delta)
	if not executing_attack:
		velocity.x = 0.0
		velocity.y = minf(950.0, velocity.y + config.gravity * delta)
	move_and_slide()
	if state == State.CAST and attack == Attack.DASH and (is_on_wall() or position.x < config.arena_min_x or position.x > config.arena_max_x):
		state_machine.current._begin_phase(State.RECOVER)
	sprite.flip_h = facing < 0
	dash_hitbox.position.x = facing*47
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE

func start_attack() -> void:
	if not state_machine.can_decide():
		return
	facing = -1 if target.position.x < position.x else 1
	var distance := absf(target.global_position.x - global_position.x)
	var airborne := target.global_position.y < global_position.y - 24.0 or not target.is_on_floor()
	var ready := {}
	for id: int in attack_states:
		ready[id] = (attack_states[id] as BossAttackState).ready()
	var selected: int = decision.choose_attack(distance, airborne, attack_count, regular_attacks, last_attack, ready, config.dash_range)
	if selected < 0:
		return
	attack = selected as Attack
	last_attack = selected
	attack_count += 1
	regular_attacks = 0 if attack == Attack.DASH else regular_attacks + 1 if attack in [Attack.MELEE, Attack.COMBO] else regular_attacks
	combo_left = config.combo_strikes if attack == Attack.COMBO else 0
	(attack_states[attack] as BossAttackState).arm()
	state_machine.change(attack_states[attack])

func _enter(next: State) -> void:
	if state == State.CAST and attack in [Attack.DASH,Attack.MELEE,Attack.COMBO]:
		dash_hitbox.end_swing()
	state = next
	match state:
		State.DORMANT:
			velocity = Vector2.ZERO
			clip("idle")
		State.INTRO:
			timer = config.intro_seconds
			clip("idle", timer)
			cue_changed.emit("Keeper awakens")
			Audio.play_sound("ability_acquire",0.65,-8)
		State.DEAD:
			clear_flames()
			clip("death",1.0)
	queue_redraw()

func _slam_impact() -> void:
	var center := position.x
	_spawn_burst(Vector2(center, position.y - 22.0), Color("ffb35c"), 54.0, 0.42, 3, 12)
	var burst := spawn_flame(Vector2(center,position.y),false,true,true)
	burst.damage_override = config.slam_damage
	# A shield or hit resolves the whole release once, including its two walls.
	var cast_handled: Array[int] = []
	burst.handled = cast_handled
	for direction: float in [-1.0,1.0]:
		var flame := FLAME.instantiate() as FurnaceFlame
		flame.config = config
		flame.outward = true
		flame.instant = true
		# The central landing is the heavy hit; each readable outward wall is a
		# separate one-point hazard so a jump is still a fair answer.
		flame.damage_override = config.damage
		flame.direction = direction
		flame.handled = cast_handled
		flame.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
		flames.add_child(flame)
		flame.global_position = Vector2(center+direction*35,position.y)
	Audio.play_sound("attack",0.8,-3)

func _spawn_burst(at: Vector2, tint: Color, radius: float, duration: float, rings: int, rays: int) -> void:
	var burst := BURST.new() as BossVisualBurst
	burst.configure(tint, radius, duration, rings, rays)
	get_parent().add_child(burst)
	burst.global_position = at


func spawn_flame(at: Vector2, is_wave: bool, is_tall := false, instant := false) -> FurnaceFlame:
	var flame := FLAME.instantiate() as FurnaceFlame
	flame.config = config
	flame.wave = is_wave
	flame.tall = is_tall
	flame.instant = instant
	flame.direction = facing
	flame.impact.connect(func(where: Vector2, killed: bool) -> void: impact.emit(where,killed))
	flames.add_child(flame)
	flame.global_position = at
	return flame

func clear_flames() -> void:
	for flame: FurnaceFlame in flames.get_children():
		flame.retire()

func reset_encounter() -> void:
	state_machine.finish()
	for attack_state: BossAttackState in state_machine.attacks:
		attack_state.cooldown_left = 0.0
	clear_flames()
	dash_hitbox.end_swing()
	position = home_position
	velocity = Vector2.ZERO
	attack_count = 0
	regular_attacks = 0
	combo_left = 0
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
	if state == State.DORMANT:
		_enter(State.INTRO)
		awakened.emit()

func pressure_guard() -> bool:
	return state in [State.TAKEOFF, State.LANDING, State.IMPACT] or state == State.WARNING and attack == Attack.SLAM

func _on_death() -> void:
	state_machine.finish()
	_enter(State.DEAD)
	contact_box.end_swing()
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()
	await sprite.animation_finished
	queue_free()
