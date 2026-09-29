class_name FurnaceKeeper
extends CharacterBody2D
signal defeated
signal awakened
signal withdrawn
signal phase_changed(phase: int)
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)
const FLAME := preload("res://features/combat/furnace_flame.tscn")
enum State { DORMANT, INTRO, WARNING, CAST, RECOVER, TRANSITION, DEAD, TAKEOFF, LANDING, IMPACT, APPROACH }
enum Attack { DASH, HOP, SLAM, MELEE, COMBO }
@export var config: FurnaceConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var flames: Node2D = $Flames
@onready var dash_hitbox: Hitbox = $DashHitbox
@onready var contact_box: Hitbox = $ContactBox
const FurnaceKeeperDecisionScript = preload("res://features/enemies/furnace_keeper_decision.gd")
const StateMachineScript = preload("res://features/enemies/boss_state_machine.gd")
const AttackStateScript = preload("res://features/enemies/boss_attack_state.gd")
var decision: RefCounted = FurnaceKeeperDecisionScript.new()
var state_machine: RefCounted = StateMachineScript.new()
var attack_states := {
	Attack.DASH: AttackStateScript.new("dash", 0.7, 0.35, 1.0, 1.5),
	Attack.HOP: AttackStateScript.new("hop", 0.55, 0.25, 0.9, 1.5),
	Attack.SLAM: AttackStateScript.new("slam", 2.2, 0.3, 1.8, 5.0),
	Attack.MELEE: AttackStateScript.new("melee", 0.45, 0.35, 0.85, 1.0),
	Attack.COMBO: AttackStateScript.new("combo", 0.8, 0.4, 1.8, 4.0),
}
var target: Player
var state := State.DORMANT
var attack := Attack.DASH
var phase := 1
var timer := 0.0
var attack_count := 0
var facing := -1.0
var flash_left := 0.0
var combo_left := 0
var home_position := Vector2.ZERO
var last_attack := -1

func _ready() -> void:
	state_machine.setup(self)
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
	contact_box.active = state not in [State.DORMANT, State.INTRO, State.TRANSITION, State.DEAD]
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	state_machine.tick(delta)
	match state:
		State.DORMANT:
			if target.position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO, State.TRANSITION:
			if timer <= 0:
				start_attack()
		State.TAKEOFF:
			if position.y <= home_position.y-config.flight_height+0.1 or is_on_ceiling():
				_enter(State.WARNING)
		State.WARNING:
			if timer <= 0:
				_enter(State.CAST)
		State.CAST:
			if attack in [Attack.DASH,Attack.MELEE,Attack.COMBO] and timer <= 0:
				if attack == Attack.COMBO and combo_left > 1:
					combo_left -= 1
					facing = -1 if target.position.x < position.x else 1
					_enter(State.WARNING)
				else:
					_enter(State.RECOVER)
			elif attack == Attack.HOP and is_on_floor() and velocity.y >= 0:
				_enter(State.RECOVER)
		State.LANDING:
			if is_on_floor():
				_slam_impact()
				_enter(State.IMPACT)
		State.IMPACT:
			if timer <= 0:
				_enter(State.RECOVER)
		State.RECOVER:
			if timer <= 0:
				if phase == 1 and health.current <= config.maximum_health/2 and attack_count >= 3:
					phase = 2
					phase_changed.emit(phase)
					_enter(State.TRANSITION)
				else:
					start_attack()
		State.APPROACH:
			facing = -1 if target.position.x < position.x else 1
			if absf(target.position.x-position.x) <= config.melee_range or timer <= 0:
				_enter(State.WARNING)
	velocity.x = 0
	if state == State.TAKEOFF:
		var distance := maxf(0,position.y-(home_position.y-config.flight_height))
		velocity.y = -minf(config.ascent_speed,distance/delta)
		velocity.x = (config.slam_x-position.x)/maxf(distance/config.ascent_speed,delta)
	elif state == State.WARNING and attack == Attack.SLAM:
		velocity.y = 0
	elif state == State.LANDING:
		velocity.y = config.slam_speed
	elif state == State.CAST and attack == Attack.DASH:
		velocity.x = facing*config.dash_speed
		velocity.y = minf(950,velocity.y+config.gravity*delta)
	elif state == State.APPROACH:
		velocity.x = facing*config.approach_speed
		velocity.y = minf(950,velocity.y+config.gravity*delta)
	elif state == State.CAST and attack == Attack.COMBO:
		velocity.x = facing*config.combo_speed
		velocity.y = minf(950,velocity.y+config.gravity*delta)
	elif state == State.CAST and attack == Attack.HOP:
		velocity.x = facing*config.hop_speed
		velocity.y = minf(950,velocity.y+config.gravity*delta)
	else:
		velocity.y = minf(950,velocity.y+config.gravity*delta)
	move_and_slide()
	if state == State.CAST and attack == Attack.DASH and (is_on_wall() or position.x < config.arena_min_x or position.x > config.arena_max_x):
		_enter(State.RECOVER)
	sprite.flip_h = facing < 0
	dash_hitbox.position.x = facing*47
	sprite.modulate = Color(2,2,2) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE

func start_attack() -> void:
	facing = -1 if target.position.x < position.x else 1
	var distance := absf(target.global_position.x - global_position.x)
	var airborne := target.global_position.y < global_position.y - 24.0 or not target.is_on_floor()
	var selected: int = decision.choose_attack(distance, airborne, attack_count, last_attack, true)
	attack = selected as Attack
	state_machine.change(attack_states[attack])
	(attack_states[attack] as BossAttackState).arm()
	last_attack = selected
	attack_count += 1
	combo_left = config.combo_strikes if attack == Attack.COMBO else 0
	_enter(State.TAKEOFF if attack == Attack.SLAM else State.APPROACH if attack == Attack.MELEE else State.WARNING)

func _enter(next: State) -> void:
	if next in [State.WARNING, State.TAKEOFF, State.APPROACH]:
		state_machine.change(attack_states[attack])
	if state == State.CAST and attack in [Attack.DASH,Attack.MELEE,Attack.COMBO]:
		dash_hitbox.end_swing()
	state = next
	match state:
		State.DORMANT:
			velocity = Vector2.ZERO
			clip("idle")
		State.INTRO, State.TRANSITION:
			timer = config.intro_seconds if state == State.INTRO else config.transition_seconds
			clip("idle" if state == State.INTRO else "transition",timer)
			cue_changed.emit("Keeper awakens" if state == State.INTRO else "Phase II / Faster pressure")
			Audio.play_sound("ability_acquire",0.65,-8)
		State.TAKEOFF:
			clip("takeoff",config.flight_height/config.ascent_speed)
			cue_changed.emit("TAKEOFF / Watch the landing line")
		State.APPROACH:
			timer = config.approach_seconds
			clip("idle")
			cue_changed.emit("APPROACH / Watch the sword")
		State.WARNING:
			if attack == Attack.SLAM:
				timer = config.hover_seconds
				clip("eruption_warning",timer)
				cue_changed.emit("HIGH SLAM / Leave the landing line")
			elif attack == Attack.MELEE:
				timer = config.melee_warning
				clip("wave_warning",timer)
				cue_changed.emit("MELEE / Step back or jump")
			elif attack == Attack.COMBO:
				timer = config.combo_charge if combo_left == config.combo_strikes else config.combo_gap
				clip("wave_warning",timer)
				cue_changed.emit("CHARGED COMBO / Three strikes, then recovery")
				Audio.play_sound("attack",0.6,-6)
			else:
				timer = config.dash_warning_seconds if attack == Attack.DASH else config.hop_warning_seconds
				clip("wave_warning" if attack == Attack.DASH else "takeoff",timer)
				cue_changed.emit("DASH SLASH / Jump or move behind" if attack == Attack.DASH else "SHORT HOP / Watch the landing")
			Audio.play_sound("attack",0.7,-6)
		State.CAST:
			if attack in [Attack.DASH,Attack.MELEE,Attack.COMBO]:
				timer = config.dash_seconds if attack == Attack.DASH else config.melee_seconds if attack == Attack.MELEE else config.combo_seconds
				clip("wave_cast",timer)
				dash_hitbox.begin_swing()
				dash_hitbox.active = true
			elif attack == Attack.HOP:
				velocity.y = config.hop_velocity
				clip("takeoff")
			else:
				_enter(State.LANDING)
		State.LANDING:
			velocity.y = config.slam_speed
			clip("eruption_cast")
			cue_changed.emit("SLAM / Jump above the flame walls")
		State.IMPACT:
			timer = config.impact_seconds
			velocity = Vector2.ZERO
			clip("eruption_cast",timer)
			cue_changed.emit("SLAM IMPACT / Flames spread outward")
		State.RECOVER:
			timer = config.recovery_seconds if phase == 1 else config.phase_two_recovery
			if attack == Attack.MELEE:
				timer = config.melee_recovery
			clip("eruption_recover" if attack == Attack.SLAM else "wave_recover",timer)
			cue_changed.emit("PRESSURE RELEASE / Strike now")
		State.DEAD:
			clear_flames()
			clip("death",1.0)
	queue_redraw()

func _slam_impact() -> void:
	var center := position.x
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
	clear_flames()
	dash_hitbox.end_swing()
	position = home_position
	velocity = Vector2.ZERO
	phase = 1
	attack_count = 0
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
	return state != State.RECOVER

func _on_death() -> void:
	_enter(State.DEAD)
	contact_box.end_swing()
	$Hurtbox.set_deferred("monitorable",false)
	defeated.emit()
	await sprite.animation_finished
	queue_free()
