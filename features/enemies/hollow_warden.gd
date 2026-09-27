class_name HollowWarden
extends CharacterBody2D

signal defeated
signal awakened
signal phase_changed(phase: int)
signal cue_changed(message: String)
signal impact(at: Vector2, killed: bool)
const COURT := preload("res://features/combat/sword_court.tscn")
enum State { DORMANT, INTRO, CHASE, WINDUP, STRIKE, RECOVER, TRANSITION, DEAD, SWORD_COURT }
enum Attack { SWEEP, RUSH, CHARGED }
@export var config: WardenConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_box: Hitbox = $AttackBox
@onready var charged_box: Hitbox = $ChargedBox
@onready var contact_box: Hitbox = $ContactBox
var target: Player
var state := State.DORMANT
var phase := 1
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
			var distance := absf(target.global_position.x-global_position.x)
			var court_ready := phase == 2 and not is_instance_valid(sword_court) and (not court_introduced or court_cooldown_left <= 0.0 and ordinary_attacks_since_court >= config.court.ordinary_attacks_between)
			var attack_ready := attack_cooldown <= 0.0 and (court_ready or distance <= config.attack_range + (42.0 if phase == 2 else 18.0))
			if attack_ready:
				_start_attack()
			elif is_on_wall() and distance > config.attack_range:
				stuck_left = config.stuck_escape_seconds
				facing = -facing
				velocity.x = facing * (config.phase_two_speed if phase == 2 else config.chase_speed)
			elif stuck_left > 0.0:
				velocity.x = facing * (config.phase_two_speed if phase == 2 else config.chase_speed)
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
		State.SWORD_COURT:
			pass # Only the summon locks the body; the independent swords continue later.
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
	sprite.flip_h = facing < 0
	if recoil_left > 0.0:
		sprite.position.x = recoil_direction * 4.0 * recoil_left / 0.08
	else:
		sprite.position.x = 0.0
	if flash_left > 0 and not Session.reduce_flashes:
		sprite.modulate = Color(2.8,2.8,2.8)
	elif state == State.TRANSITION:
		var transition_pulse := 0.0 if Session.reduce_flashes else 0.22 + 0.18 * sin(timer * 15.0)
		sprite.modulate = Color(1.25 + transition_pulse,0.42,0.42)
	elif state == State.SWORD_COURT and is_instance_valid(sword_court):
		var pulse := 0.0 if Session.reduce_flashes else 0.15 + 0.15 * sin(sword_court.elapsed * 12.0)
		sprite.modulate = Color(1.3 + pulse,0.95,0.7)
	else:
		sprite.modulate = Color.WHITE
	queue_redraw()

func _start_attack() -> void:
	attack_cooldown = config.attack_gap_seconds
	attack = _choose_attack()
	rush_attack = attack == Attack.RUSH
	if int(attack) == last_attack:
		repeated_attack_count += 1
	else:
		repeated_attack_count = 0
	last_attack = int(attack)
	attack_count += 1
	active_profile = config.charged if attack == Attack.CHARGED else config.rush if rush_attack else config.sweep
	if attack == Attack.CHARGED:
		court_introduced = true
		ordinary_attacks_since_court = 0
		_enter(State.SWORD_COURT)
	else:
		ordinary_attacks_since_court += 1
		_enter(State.WINDUP)

func _choose_attack() -> Attack:
	# Keep the opening readable: teach sweep, then rush, then reveal the phase-two
	# sword court. Once those lessons are complete, choose by player context.
	if phase == 1 and attack_count == 0:
		return Attack.SWEEP
	if phase == 1 and attack_count == 1:
		return Attack.RUSH
	if phase == 2 and not court_introduced:
		return Attack.CHARGED
	var distance := absf(target.global_position.x - global_position.x)
	var player_airborne := target.global_position.y < global_position.y - 24.0 or not target.is_on_floor()
	var score := {Attack.SWEEP: 1.0, Attack.RUSH: 1.0, Attack.CHARGED: 1.5}
	if distance < 52.0:
		score[Attack.SWEEP] += 2.5
		score[Attack.RUSH] -= 0.5
	if distance > config.attack_range + 90.0:
		score[Attack.RUSH] += 2.5
		score[Attack.CHARGED] += 0.75
	if player_airborne:
		score[Attack.CHARGED] += 2.0
		score[Attack.SWEEP] += 0.5
	if target.velocity.x != 0.0 and signf(target.velocity.x) != signf(global_position.x - target.global_position.x):
		score[Attack.RUSH] += 0.75
	if last_attack >= 0:
		score[last_attack as Attack] -= 1.5 + repeated_attack_count * 1.0
	# Deterministic tie break keeps tests and replays stable without a fixed cycle.
	var best := Attack.SWEEP
	var best_score := -INF
	for candidate: Attack in [Attack.SWEEP, Attack.RUSH, Attack.CHARGED]:
		if candidate == Attack.CHARGED and (is_instance_valid(sword_court) or phase < 2 or court_cooldown_left > 0.0 or ordinary_attacks_since_court < config.court.ordinary_attacks_between):
			continue
		if score[candidate] > best_score:
			best = candidate
			best_score = score[candidate]
	return best

func _enter(next: State) -> void:
	state = next
	attack_box.end_swing()
	charged_box.end_swing()
	if next not in [State.CHASE, State.WINDUP, State.STRIKE, State.SWORD_COURT, State.RECOVER]:
		contact_box.end_swing()
	velocity.x = 0
	match state:
		State.INTRO, State.TRANSITION:
			timer = config.intro_seconds if state == State.INTRO else config.transition_seconds
			attack_cooldown = maxf(attack_cooldown, timer)
			_play_clip("idle")
			cue_changed.emit("Warden awakens" if state == State.INTRO else "Phase II / Faster pursuit")
			Audio.play_sound("ability_acquire", 0.65, -8.0)
		State.CHASE:
			attack_cooldown = maxf(attack_cooldown, config.attack_gap_seconds)
			_play_clip("walk")
			cue_changed.emit("")
		State.WINDUP:
			timer = active_profile.windup
			attack_box.position.x = facing * 44
			attack_box.damage = active_profile.damage
			attack_box.begin_swing()
			_play_clip("rush_windup" if rush_attack else "windup",timer)
			cue_changed.emit("RUSH / Jump over" if rush_attack else "SWEEP / Step back or behind")
			Audio.play_sound("jump" if rush_attack else "attack", 0.7, -7.0)
		State.STRIKE:
			timer = active_profile.active_seconds
			attack_box.active = true
			_play_clip("rush_strike" if rush_attack else "strike",timer)
			Audio.play_sound("attack")
		State.SWORD_COURT:
			timer = config.court.summon_seconds
			_play_clip("charged_windup",timer)
			_spawn_court()
			cue_changed.emit("SWORD COURT / Invulnerable while summoning")
			Audio.play_sound("ability_acquire",0.6,-5.0)
		State.RECOVER:
			timer = active_profile.recovery*(config.phase_two_recovery_scale if phase == 2 else 1.0)
			_play_clip("rush_recover" if rush_attack else "recover",timer)
			cue_changed.emit("RECOVERY / Strike now")
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
	if state == State.TRANSITION:
		var pulse := 0.0 if Session.reduce_flashes else 0.3 + 0.15 * sin(timer * 12.0)
		draw_arc(Vector2(0,-44),44 + pulse * 8.0,0,TAU,32,Color(0.95,0.25,0.35,0.7),3)

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
