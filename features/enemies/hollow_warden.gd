class_name HollowWarden
extends CharacterBody2D

signal defeated
signal awakened
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)
const COURT := preload("res://features/combat/sword_court.tscn")
enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, RECOVER, DEAD, SWORD_COURT }
enum Attack { SWEEP, RUSH, CHARGED }
@export var config: WardenConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var charged_box: Hitbox = $ChargedBox
@onready var contact_box: Hitbox = $ContactBox
const HollowWardenDecisionScript = preload("res://features/enemies/hollow_warden_decision.gd")
var decision: RefCounted = HollowWardenDecisionScript.new()
@onready var state_machine: BossStateMachine = $BossStateMachine
var attack_states := {}
var target: Player
var state := State.DORMANT
var facing := -1.0
var timer := 0.0
var flash_left := 0.0
var rush_attack := false
var attack := Attack.SWEEP
var attack_count := 0
var active_profile: AttackProfile
var last_attack := -1
var repeated_attack_count := 0
var attack_cooldown := 0.0
var stuck_left := 0.0
var recoil_left := 0.0
var recoil_direction := 0.0
var court_cooldown_left := 0.0
var court_introduced := false
var ordinary_attacks_since_court := 0
var sword_court: SwordCourt

func _ready() -> void:
	attack_states = state_machine.setup(self)
	($Hurtbox as Hurtbox).damage_guard = summon_guard
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damage)
	health.died.connect(_on_death)
	attack_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	charged_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	_play_clip("idle")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	stuck_left = maxf(0.0, stuck_left - delta)
	court_cooldown_left = maxf(0.0, court_cooldown_left - delta)
	recoil_left = maxf(0.0, recoil_left - delta)
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		state_machine.finish()
		attack_box.end_swing()
		charged_box.end_swing()
		contact_box.end_swing()
		clear_court()
		velocity = Vector2.ZERO
		return
	timer = maxf(0,timer-delta)
	flash_left = maxf(0,flash_left-delta)
	_update_contact_damage()
	velocity.x = 0
	velocity.y = minf(velocity.y+1600*delta,950)
	var executing_attack := state_machine.current != null
	state_machine.tick(delta)
	match state:
		State.DORMANT:
			if target.position.x >= config.activation_x:
				_enter(State.INTRO)
				awakened.emit()
		State.INTRO:
			if timer <= 0:
				_enter(State.CHASE)
		State.CHASE:
			if executing_attack:
				move_and_slide()
				return
			facing = -1.0 if target.global_position.x < global_position.x else 1.0
			var distance := absf(target.global_position.x-global_position.x)
			var court_ready := not is_instance_valid(sword_court) and (not court_introduced or court_cooldown_left <= 0.0 and ordinary_attacks_since_court >= config.court.ordinary_attacks_between)
			var attack_ready := attack_cooldown <= 0.0 and (court_ready or distance <= config.attack_range + 18.0)
			if attack_ready:
				_start_attack()
			elif is_on_wall() and distance > config.attack_range:
				stuck_left = config.stuck_escape_seconds
				facing = -facing
				velocity.x = facing * config.chase_speed
			elif stuck_left > 0.0:
				velocity.x = facing * config.chase_speed
			else:
				velocity.x = facing * config.chase_speed
		State.WINDUP, State.STRIKE, State.SWORD_COURT, State.RECOVER:
			pass
	move_and_slide()
	if state_machine.current:
		(state_machine.current as HollowWardenAttackState).after_move()
	sprite.flip_h = facing < 0
	if recoil_left > 0.0:
		sprite.position.x = recoil_direction * 4.0 * recoil_left / 0.08
	else:
		sprite.position.x = 0.0
	if flash_left > 0 and not Session.reduce_flashes:
		sprite.modulate = Color(2.8,2.8,2.8)
	elif state == State.SWORD_COURT and is_instance_valid(sword_court):
		var pulse := 0.0 if Session.reduce_flashes else 0.15 + 0.15 * sin(sword_court.elapsed * 12.0)
		sprite.modulate = Color(1.3 + pulse,0.95,0.7)
	else:
		sprite.modulate = Color.WHITE
	queue_redraw()

func _start_attack() -> void:
	if not state_machine.can_decide():
		return
	var selected := _choose_attack()
	if selected < 0:
		return
	attack_cooldown = config.attack_gap_seconds
	attack = selected as Attack
	rush_attack = attack == Attack.RUSH
	if int(attack) == last_attack:
		repeated_attack_count += 1
	else:
		repeated_attack_count = 0
	last_attack = int(attack)
	attack_count += 1
	active_profile = config.charged if attack == Attack.CHARGED else config.rush if rush_attack else config.sweep
	(attack_states[attack] as BossAttackState).arm()
	state_machine.change(attack_states[attack])
	if attack == Attack.CHARGED:
		court_introduced = true
		ordinary_attacks_since_court = 0
	else:
		ordinary_attacks_since_court += 1

func _choose_attack() -> int:
	# Teach sweep and rush before the sword court joins the ordinary attack loop.
	if attack_count == 0 and (attack_states[Attack.SWEEP] as BossAttackState).ready():
		return Attack.SWEEP
	if attack_count == 1 and (attack_states[Attack.RUSH] as BossAttackState).ready():
		return Attack.RUSH
	if not court_introduced and (attack_states[Attack.CHARGED] as BossAttackState).ready():
		return Attack.CHARGED
	var distance := absf(target.global_position.x - global_position.x)
	var player_airborne := target.global_position.y < global_position.y - 24.0 or not target.is_on_floor()
	var court_ready := not is_instance_valid(sword_court) and court_cooldown_left <= 0.0 and ordinary_attacks_since_court >= config.court.ordinary_attacks_between and (attack_states[Attack.CHARGED] as BossAttackState).ready()
	return decision.choose_attack(distance, player_airborne, last_attack, repeated_attack_count, court_ready, (attack_states[Attack.SWEEP] as BossAttackState).ready(), (attack_states[Attack.RUSH] as BossAttackState).ready())

func _enter(next: State) -> void:
	state = next
	if next in [State.CHASE, State.DEAD]:
		state_machine.finish()
	attack_box.end_swing()
	charged_box.end_swing()
	if next not in [State.CHASE, State.WINDUP, State.STRIKE, State.SWORD_COURT, State.RECOVER]:
		contact_box.end_swing()
	velocity.x = 0
	match state:
		State.INTRO:
			timer = config.intro_seconds
			attack_cooldown = maxf(attack_cooldown, timer)
			_play_clip("idle")
			cue_changed.emit("Warden awakens")
			Audio.play_sound("ability_acquire", 0.65, -8.0)
		State.CHASE:
			attack_cooldown = maxf(attack_cooldown, config.attack_gap_seconds)
			_play_clip("walk")
			cue_changed.emit("")
		State.DEAD:
			clear_court()
			velocity = Vector2.ZERO
			_play_clip("death")

func _spawn_court() -> void:
	clear_court()
	sword_court = COURT.instantiate() as SwordCourt
	sword_court.config = config.court
	sword_court.target = target
	sword_court.position = Vector2.ZERO
	sword_court.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	sword_court.summon_finished.connect(_on_summon_finished)
	sword_court.cast_finished.connect(_on_court_finished)
	add_child(sword_court)
	sword_court.global_position = Vector2.ZERO
	if is_instance_valid(target) and not target.died.is_connected(clear_court):
		target.died.connect(clear_court)

func summon_guard() -> bool:
	return state == State.SWORD_COURT

func _on_summon_finished() -> void:
	if state == State.SWORD_COURT:
		_enter(State.CHASE)
		attack_cooldown = 0.0
		cue_changed.emit("HUNTING SWORDS / Keep moving and watch the king")

func _on_court_finished() -> void:
	sword_court = null
	court_cooldown_left = config.court.cooldown_seconds

func clear_court() -> void:
	if is_instance_valid(sword_court):
		sword_court.retire()
	sword_court = null

func _play_clip(animation: StringName, duration := 0.0) -> void:
	sprite.stop()
	sprite.speed_scale = 1.0
	if duration > 0:
		var frames := sprite.sprite_frames
		sprite.speed_scale = frames.get_frame_count(animation)/(frames.get_animation_speed(animation)*duration)
	sprite.play(animation)

func _on_damage(_amount: int, _at: Vector2) -> void:
	flash_left = 0.08
	recoil_left = 0.08
	recoil_direction = -1.0 if _at.x > global_position.x else 1.0
	Audio.play_sound("hit", 0.75, -5.0)
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

func _update_contact_damage() -> void:
	var enabled := state in [State.CHASE, State.WINDUP, State.STRIKE, State.SWORD_COURT, State.RECOVER]
	if not enabled:
		contact_box.end_swing()
		return
	if contact_box.get_overlapping_areas().is_empty():
		# A new touch starts a fresh hit window; HealthComponent still supplies
		# the short invulnerability period while the player remains pressed in.
		contact_box.begin_swing()
		contact_box.active = true
	elif not contact_box.active:
		contact_box.active = true
