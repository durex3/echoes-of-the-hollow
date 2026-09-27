class_name BellSkimmer
extends CharacterBody2D
## Distant screech commits a sound fan; close dives lock an old ground position.
const PULSE := preload("res://features/enemies/echo_pulse.gd")
signal defeated
signal impact(at: Vector2, killed: bool)
enum State { HOVER, WARNING, DIVE, RECOVER, RISE, HURT, FALLING, DEAD, SCREECH_WARNING, SCREECH_ACTIVE, SCREECH_RECOVER, REPOSITION }
@export var config: SkimmerConfig
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var contact_box: Hitbox = $ContactBox
@onready var strike: BellFrameStrike = $Strike
@onready var stagger: EnemyStagger = $Stagger
var target: Player
var state := State.HOVER
var elapsed := 0.0
var facing := 1.0
var hover_y := 0.0
var locked_position := Vector2.ZERO
var dive_velocity := Vector2.ZERO
var dive_duration := 0.45
var shared_contact := false
var flash_left := 0.0
var screech_left := 0.0
var locked_aim := Vector2.RIGHT
var pulses: Array[Node2D] = []
var home := Vector2.ZERO
var reposition_goal := Vector2.ZERO
var reposition_left := 0.0
var consecutive_dives := 0
var recovery_after_hurt := 0.0
var recovery_state := State.RECOVER

func _ready() -> void:
	home = global_position
	hover_y = global_position.y
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	contact_box.damage = config.damage
	strike.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))
	contact_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))

func can_see_target() -> bool:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		return false
	if global_position.distance_to(target.global_position) > config.detection_range:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position + Vector2(0,-18), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	elapsed += delta
	flash_left = maxf(0,flash_left-delta)
	screech_left = maxf(0,screech_left-delta)
	reposition_left = maxf(0,reposition_left-delta)
	queue_redraw()
	strike.stop()
	if shared_contact and state in [State.HOVER, State.RISE, State.REPOSITION] and not _has_pulses() and contact_box.get_overlapping_areas().is_empty():
		contact_box.hit_ids = []
		contact_box.reset_when_empty = true
		shared_contact = false
	if state in [State.WARNING, State.DIVE, State.SCREECH_WARNING, State.SCREECH_ACTIVE, State.SCREECH_RECOVER] and (not is_instance_valid(target) or target.state == Player.State.DEAD):
		_clear_pulses()
		_enter(State.RECOVER)
	velocity = Vector2.ZERO
	match state:
		State.HOVER:
			if can_see_target():
				var offset := target.global_position.x - global_position.x
				facing = -1.0 if offset < 0 else 1.0
				var airborne_close := not target.is_on_floor() and absf(offset)<config.evade_range and absf(target.global_position.y-18-global_position.y)<config.evade_height
				var change_tactic := consecutive_dives>=2 and screech_left<=0 and absf(offset)<config.screech_range_min
				if (airborne_close or change_tactic) and _try_reposition():
					pass
				elif absf(offset)>=config.screech_range_min and screech_left<=0:
					_enter(State.SCREECH_WARNING)
				elif absf(offset) <= config.dive_range and target.is_on_floor() and _flight_clear(target.global_position+Vector2(0,-18)):
					_enter(State.WARNING)
				elif absf(offset)>config.dive_range and _flight_clear(global_position+Vector2(facing*24,0)):
					velocity.x = facing * config.approach_speed
			else:
				# Return only along a clear route; do not pursue through occluders.
				var destination := Vector2(home.x,hover_y)
				if global_position.distance_to(destination)>4 and _flight_clear(destination):
					velocity = (destination-global_position).limit_length(config.approach_speed*delta)/delta
		State.REPOSITION:
			var offset := reposition_goal-global_position
			if elapsed>=config.reposition_seconds or offset.length()<4 or not _flight_clear(reposition_goal):
				_enter(State.HOVER)
			else:
				velocity = offset.limit_length(config.reposition_speed*delta)/delta
		State.WARNING:
			if elapsed >= config.warning_seconds:
				_enter(State.DIVE)
		State.SCREECH_WARNING:
			if elapsed >= config.screech_warning:
				_enter(State.SCREECH_ACTIVE)
		State.SCREECH_ACTIVE:
			if elapsed >= config.screech_release:
				_enter(State.SCREECH_RECOVER)
		State.SCREECH_RECOVER:
			if elapsed >= config.screech_recovery:
				_enter(State.HOVER)
		State.DIVE:
			velocity = dive_velocity * minf(delta, maxf(0,dive_duration-elapsed+delta)) / delta
			if elapsed >= dive_duration or is_on_wall() or is_on_floor():
				consecutive_dives += 1
				_enter(State.RECOVER)
				velocity = Vector2.ZERO
		State.RECOVER:
			if elapsed >= config.recovery_seconds:
				_enter(State.RISE)
		State.RISE:
			var destination := Vector2(global_position.x,hover_y)
			if global_position.y <= hover_y or not _flight_clear(destination):
				_enter(State.HOVER)
			else:
				velocity = (destination-global_position).limit_length(config.approach_speed*delta)/delta
		State.HURT:
			if elapsed >= config.hurt_seconds:
				if recovery_after_hurt>0:
					_enter(recovery_state)
					var duration := config.recovery_seconds if state==State.RECOVER else config.screech_recovery
					elapsed = duration-recovery_after_hurt
				else:
					_enter(State.HOVER)
		State.FALLING:
			velocity.y = minf(600, config.gravity * elapsed)
			if is_on_floor():
				_enter(State.DEAD)
		State.DEAD:
			if elapsed >= config.death_seconds:
				queue_free()
	move_and_slide()
	_present()
	if state == State.DIVE:
		# The visible claw arc (source faces right), not the entire 87px canvas.
		var polygon := PackedVector2Array([Vector2(1,-20),Vector2(19,-18),Vector2(27,-2),Vector2(18,9),Vector2(2,5)])
		for index: int in range(polygon.size()):
			polygon[index].x *= facing
		strike.strike(polygon, config.damage)

func _enter(next: State) -> void:
	state = next
	elapsed = 0
	strike.stop()
	if state == State.WARNING:
		locked_position = target.global_position + Vector2(0,-18)
		var offset := locked_position - global_position
		dive_duration = minf(config.dive_seconds, offset.length()/config.dive_speed)
		dive_velocity = offset.normalized() * config.dive_speed
		strike.begin()
		contact_box.hit_ids = strike.hit_ids
		contact_box.reset_when_empty = false
		shared_contact = true
	if state == State.SCREECH_WARNING:
		consecutive_dives = 0
		_clear_pulses()
		locked_position = target.global_position+Vector2(0,-18)
		locked_aim = (locked_position-(global_position+Vector2(facing*14,-10))).normalized()
		screech_left = config.screech_cooldown
		strike.begin()
		contact_box.hit_ids = strike.hit_ids
		contact_box.reset_when_empty = false
		shared_contact = true
	if state == State.SCREECH_ACTIVE:
		for angle: float in [-config.pulse_spread,0.0,config.pulse_spread]:
			var pulse := Node2D.new()
			pulse.set_script(PULSE)
			pulse.config = config
			pulse.direction = locked_aim.rotated(angle)
			pulse.hit_ids = strike.hit_ids
			add_child(pulse)
			pulse.global_position = global_position+Vector2(facing*14,-10)
			pulse.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
			pulses.append(pulse)
		Audio.play_sound("attack",1.8,-6)
	if state == State.DIVE:
		Audio.play_sound("attack", 1.35, -8)

func _clip(name_text: StringName, first: int, count: int, seconds: float, loop := false) -> void:
	sprite.animation = name_text
	var index := int(elapsed / maxf(seconds,0.01) * count)
	sprite.frame = first + (index % count if loop else mini(index,count-1))

func _present() -> void:
	sprite.stop()
	sprite.modulate = Color(2.4,2.1,2.5) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	sprite.flip_h = facing < 0
	match state:
		State.HOVER, State.RISE, State.REPOSITION: _clip(&"fly",0,11,0.8,true)
		State.WARNING: _clip(&"attack",0,8,config.warning_seconds)
		State.SCREECH_WARNING: _clip(&"attack",0,8,config.screech_warning)
		State.SCREECH_ACTIVE: _clip(&"attack",8,2,config.screech_release)
		State.SCREECH_RECOVER: _clip(&"fly",0,11,config.screech_recovery)
		State.DIVE: _clip(&"attack",8,2,dive_duration)
		State.RECOVER:
			if elapsed < 0.12:
				_clip(&"attack",10,1,0.12)
			else:
				_clip(&"fly",0,11,0.8,true)
		State.HURT: _clip(&"hurt",0,3,config.hurt_seconds)
		State.FALLING:
			if elapsed < 0.24:
				_clip(&"fly_to_fall",0,3,0.24)
			else:
				_clip(&"fall",0,5,0.5,true)
		State.DEAD: _clip(&"death",0,4,config.death_seconds)

func _on_damaged(_amount: int, _source: Vector2) -> void:
	flash_left = config.hit_flash_seconds
	if not stagger.register_hit():
		return
	_clear_pulses()
	if health.current > 0:
		recovery_after_hurt = 0
		if state in [State.RECOVER,State.SCREECH_RECOVER]:
			recovery_state = state
			var duration := config.recovery_seconds if state==State.RECOVER else config.screech_recovery
			recovery_after_hurt = maxf(0,duration-elapsed)
		_enter(State.HURT)

func _on_died() -> void:
	_clear_pulses()
	_enter(State.FALLING)
	contact_box.end_swing()
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()

func _clear_pulses() -> void:
	for pulse: Node2D in pulses:
		if is_instance_valid(pulse):
			pulse.cancel()
	pulses.clear()

func _has_pulses() -> bool:
	for pulse: Node2D in pulses:
		if is_instance_valid(pulse) and not pulse.canceled:
			return true
	return false

func _flight_clear(destination: Vector2) -> bool:
	if absf(destination.x-home.x)>config.leash_distance:
		return false
	# Sweep the actual body, including its shoulder clearance, against world only.
	return not test_move(global_transform,destination-global_position)

func _try_reposition() -> bool:
	if reposition_left>0:
		return false
	# Commit to a short lateral retreat. No tracking, rising kite or warning cancel.
	var side := -facing
	var desired_x := target.global_position.x+side*config.preferred_distance
	var step := clampf(desired_x-global_position.x,-config.reposition_distance,config.reposition_distance)
	var destination := global_position+Vector2(step,0)
	if absf(step)<16 or not _flight_clear(destination):
		return false
	reposition_goal = destination
	reposition_left = config.reposition_cooldown
	_enter(State.REPOSITION)
	return true

func _draw() -> void:
	if state!=State.SCREECH_WARNING:
		return
	var charge := clampf(elapsed/config.screech_warning,0,1)
	var mouth := Vector2(facing*14,-10)
	for index: int in range(3):
		var distance := 9.0+index*5.0-4.0*charge
		var color := Color("e8baaa")
		color.a = 0.45 if Session.reduce_flashes else 0.6+charge*0.4
		draw_rect(Rect2(mouth+Vector2(facing*distance,-4+index*4),Vector2(3,3)),color)
