class_name Player
extends CharacterBody2D

signal died
signal impact(at: Vector2, defeated: bool)
signal dash_status_changed(status: String)
enum State { MOVE, ATTACK, HURT, DEAD, DASH }
@export var config: PlayerConfig
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var visual: Node2D = $Visual
@onready var health: HealthComponent = $Health
@onready var attack_box: Hitbox = $AttackBox
@onready var slash: PlayerSlash = $Visual/Slash
@onready var effects: PlayerVisualEffects = $VisualEffects
@onready var steam_ward: SteamWard = $SteamWard
@onready var wall_echo: WallEcho = $WallEcho
var ward_held := false
var state := State.MOVE
var facing := 1.0
var coyote_left := 0.0
var buffer_left := 0.0
var state_left := 0.0
var air_jump_used := false
var attack_elapsed := 0.0
var attack_variant := 0
var next_attack_variant := 0
var attack_buffer_left := 0.0
var attack_phase := AttackProfile.Phase.FINISHED
var input_armed := true
var attack_held := false
var jump_held := false
var dash_held := false
var air_dash_used := false
var dash_left := 0.0
var dash_cooldown_left := 0.0
var last_dash_status := ""

func _ready() -> void:
	($Hurtbox as Hurtbox).damage_guard = steam_ward.absorb
	health.maximum = Session.maximum_health()
	health.restore_full()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	wall_echo.jumped.connect(effects.show_wall_push)
	attack_box.impact.connect(func(at: Vector2, defeated: bool) -> void: impact.emit(at, defeated))

func _physics_process(delta: float) -> void:
	_publish_dash_status()
	if state == State.DEAD:
		return
	wall_echo.advance(delta, self, "wall_echo" in Session.abilities and state == State.MOVE)
	steam_ward.advance(delta)
	# Discrete actions require a fresh press after menus, even if held during resume.
	if not input_armed:
		input_armed = not Input.is_action_pressed("jump") and not Input.is_action_pressed("attack") and not Input.is_action_pressed("dash") and not Input.is_action_pressed("steam_ward")
	var ward_pressed := input_armed and Input.is_action_pressed("steam_ward") and not ward_held
	ward_held = Input.is_action_pressed("steam_ward")
	if ward_pressed and state != State.HURT:
		steam_ward.activate()
	var dash_pressed := input_armed and Input.is_action_pressed("dash") and not dash_held
	dash_held = Input.is_action_pressed("dash")
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	var jump_pressed := input_armed and Input.is_action_pressed("jump") and not jump_held
	var attack_pressed := input_armed and Input.is_action_pressed("attack") and not attack_held
	attack_buffer_left = maxf(0.0, attack_buffer_left - delta)
	if attack_pressed and state == State.ATTACK and attack_phase == AttackProfile.Phase.RECOVERY:
		attack_buffer_left = config.attack_buffer_seconds
	var jump_released := jump_held and not Input.is_action_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	attack_held = Input.is_action_pressed("attack")
	state_left = maxf(0.0, state_left - delta)
	buffer_left = maxf(0.0, buffer_left - delta)
	coyote_left = config.coyote_seconds if is_on_floor() else maxf(0, coyote_left - delta)
	if is_on_floor():
		air_jump_used = false
		if state != State.DASH:
			air_dash_used = false
	if jump_pressed:
		buffer_left = config.buffer_seconds
		if "wall_echo" in Session.abilities and (wall_echo.can_jump() or wall_echo.approaching_surface(self)):
			buffer_left = wall_echo.config.jump_buffer_seconds
	var direction := Input.get_axis("move_left", "move_right")
	if state == State.MOVE and dash_pressed and "dash" in Session.abilities and dash_cooldown_left <= 0 and not air_dash_used:
		if direction != 0:
			facing = signf(direction)
		state = State.DASH
		dash_left = config.dash_seconds
		dash_cooldown_left = config.dash_cooldown
		air_dash_used = true
		buffer_left = 0
		coyote_left = 0
	if state == State.DASH:
		wall_echo.interrupt()
		var step := minf(delta, dash_left)
		velocity = Vector2(facing * config.dash_speed * step / delta, 0)
		move_and_slide()
		dash_left = maxf(0.0, dash_left - delta)
		var blocked := is_on_wall()
		for index: int in range(get_slide_collision_count()):
			var barrier := get_slide_collision(index).get_collider() as WindGate
			if barrier and barrier.breach():
				blocked = false
		if blocked or dash_left <= 0:
			cancel_dash()
		_update_animation()
		return
	if state == State.HURT and state_left <= 0:
		state = State.MOVE
	if state == State.ATTACK:
		attack_elapsed += delta
		attack_phase = config.attack.phase_at(attack_elapsed)
		if attack_phase == AttackProfile.Phase.FINISHED:
			attack_box.end_swing()
			slash.hide()
			state = State.MOVE
	if state != State.HURT:
		if state == State.MOVE and direction != 0:
			facing = signf(direction)
		var target := direction * config.run_speed * (0.35 if state == State.ATTACK else 1.0)
		if wall_echo.arrival_left>0 and state==State.MOVE:
			velocity.x = 0
		elif wall_echo.steering_left > 0:
			velocity.x = wall_echo.launch_direction*wall_echo.config.outward_speed
		else:
			velocity.x = move_toward(velocity.x, target, (config.acceleration if direction else config.friction) * delta)
		if buffer_left > 0:
			if coyote_left > 0:
				_jump(false)
			elif state == State.MOVE and wall_echo.launch(self, config.jump_velocity()):
				# Never refill double jump/dash or cancel an attack through a wall jump.
				buffer_left = 0.0
				coyote_left = 0.0
				facing = signf(velocity.x)
				Audio.play_sound("jump")
			elif Session.abilities.has("double_jump") and not air_jump_used and not (state==State.MOVE and "wall_echo" in Session.abilities and wall_echo.approaching_surface(self)):
				_jump(true)
		if jump_released and velocity.y < 0 and wall_echo.steering_left<=0:
			velocity.y *= 0.45
		if state == State.MOVE and (attack_pressed or attack_buffer_left > 0.0):
			state = State.ATTACK
			attack_buffer_left = 0.0
			attack_variant = next_attack_variant
			next_attack_variant = 1 - next_attack_variant
			attack_elapsed = 0.0
			attack_phase = AttackProfile.Phase.WINDUP
			attack_box.damage = config.attack.damage
			attack_box.begin_swing()
			Audio.play_sound("attack")
	velocity.y = minf(velocity.y + config.gravity() * (config.fall_multiplier if velocity.y > 0 else 1.0) * delta, 950)
	if state == State.MOVE:
		wall_echo.limit_slide(self, direction)
	attack_box.position.x = facing * 30
	attack_box.active = state == State.ATTACK and attack_phase == AttackProfile.Phase.ACTIVE
	move_and_slide()
	_update_animation()
	if global_position.y > 850:
		health.invulnerability_left = 0
		health.take_damage(health.maximum, global_position)

func _jump(air: bool) -> void:
	wall_echo.interrupt()
	velocity.y = config.jump_velocity()
	coyote_left = 0
	buffer_left = 0
	air_jump_used = air
	Audio.play_sound("jump")

func _update_animation() -> void:
	queue_redraw()
	visual.scale.x = facing
	sprite.position = Vector2(0,-40)
	slash.visible = attack_box.active
	if slash.visible:
		slash.present(config.attack.phase_progress(attack_elapsed), attack_variant)
	visual.modulate.a = 0.45 if not Session.reduce_flashes and health.invulnerability_left > 0 and int(health.invulnerability_left * 18) % 2 else 1.0
	match state:
		State.DASH:
			sprite.play("run")
		State.ATTACK:
			# A separate press chooses the other hand; recovery poses join cleanly.
			sprite.play("attack_return" if attack_variant == 1 else "attack")
			sprite.pause()
			match attack_phase:
				AttackProfile.Phase.WINDUP: sprite.frame = 0
				AttackProfile.Phase.ACTIVE: sprite.frame = 1 + mini(2, int(config.attack.phase_progress(attack_elapsed) * 3))
				_: sprite.frame = 4 + mini(1, int(config.attack.phase_progress(attack_elapsed) * 2))
		State.HURT: sprite.play("hurt")
		_:
			if wall_echo.sliding and not is_on_floor():
				visual.scale.x = -wall_echo.normal_x
				sprite.position.x = 2
				sprite.play("wall_slide")
			elif wall_echo.pose_left > 0 and not is_on_floor():
				visual.scale.x = wall_echo.launch_direction
				sprite.play("wall_push")
			elif not is_on_floor():
				sprite.play("jump" if velocity.y < 0 else "fall")
			else:
				sprite.play("run" if absf(velocity.x) > 8 else "idle")

func _on_damaged(_amount: int, origin: Vector2) -> void:
	wall_echo.interrupt()
	effects.clear()
	cancel_dash()
	state = State.HURT
	state_left = 0.24
	cancel_attack()
	velocity = Vector2(180 * (-1 if origin.x > global_position.x else 1), -180)
	Audio.play_sound("hit")

func _on_died() -> void:
	sprite.position = Vector2(0,-40)
	wall_echo.reset()
	effects.clear()
	steam_ward.cancel()
	cancel_dash()
	state = State.DEAD
	cancel_attack()
	slash.hide()
	sprite.play("death")
	died.emit()

func revive(at: Vector2) -> void:
	wall_echo.reset()
	effects.clear()
	attack_variant = 0
	next_attack_variant = 0
	steam_ward.cancel(true)
	global_position = at
	velocity = Vector2.ZERO
	state = State.MOVE
	state_left = 0
	cancel_attack()
	coyote_left = 0
	buffer_left = 0
	air_jump_used = false
	air_dash_used = false
	dash_left = 0
	dash_cooldown_left = 0
	health.maximum = Session.maximum_health()
	health.restore_full()
	visual.modulate = Color.WHITE

func cancel_attack() -> void:
	attack_buffer_left = 0.0
	attack_box.end_swing()
	attack_phase = AttackProfile.Phase.FINISHED
	slash.hide()

func reset_input() -> void:
	wall_echo.interrupt()
	attack_buffer_left = 0.0
	ward_held = Input.is_action_pressed("steam_ward")
	buffer_left = 0
	input_armed = false
	jump_held = Input.is_action_pressed("jump")
	attack_held = Input.is_action_pressed("attack")
	dash_held = Input.is_action_pressed("dash")

func cancel_dash(clear_trails := false) -> void:
	if clear_trails:
		effects.clear()
	dash_left = 0
	queue_redraw()
	if state == State.DASH:
		state = State.MOVE
		velocity.x = facing * config.run_speed

func _publish_dash_status() -> void:
	var value := "Dash ready"
	if "dash" not in Session.abilities:
		value = "Dash locked"
	elif state == State.DASH:
		value = "Dashing"
	elif state != State.MOVE:
		value = "Dash unavailable"
	elif dash_cooldown_left > 0:
		value = "Dash recharging"
	elif air_dash_used:
		value = "Dash: land to recharge"
	if value != last_dash_status:
		last_dash_status = value
		dash_status_changed.emit(value)
