class_name BellInvoker
extends CharacterBody2D
## Close arcs, a travelling toll and a ground seal; all casts are interruptible.
const SPELL := preload("res://features/enemies/bell_spell.gd")
signal defeated
signal impact(at: Vector2, killed: bool)
enum State { IDLE, APPROACH, WARNING, ACTIVE, RECOVER, HURT, DEAD, RETREAT }
@export var config: InvokerConfig
@export_enum("Travelling toll", "Ground seal") var opening_spell := 0
@onready var health: HealthComponent = $Health
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var contact_box: Hitbox = $ContactBox
@onready var strike: BellFrameStrike = $Strike
@onready var edge: RayCast2D = $Edge
@onready var stagger: EnemyStagger = $Stagger
var target: Player
var state := State.IDLE
var elapsed := 0.0
var facing := -1.0
var cast_variant := 0
var next_variant := 0
var shared_contact := false
var ranged_cast := false
var ranged_left := 0.0
var next_spell := 0
var spell: Node2D
var flash_left := 0.0
var home := Vector2.ZERO
var last_seen := Vector2.ZERO
var search_left := 0.0
var retreat_left := 0.0
var retreat_direction := 1.0
var completed_casts := 0
var ranged_casts := 0
var last_spell := -1
var spell_repeats := 0
var recovery_after_hurt := 0.0

func _ready() -> void:
	home = global_position
	sprite.scale = Vector2.ONE*config.sprite_scale
	next_spell = opening_spell
	health.maximum = config.maximum_health
	health.restore_full()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	strike.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))
	contact_box.damage = config.damage
	contact_box.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at, killed))
	_present()

func can_see_target() -> bool:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		return false
	var offset := target.global_position - global_position
	if absf(offset.x) > config.detection_range or absf(offset.y) > 90.0:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-24), target.global_position + Vector2(0,-18), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	elapsed += delta
	ranged_left = maxf(0, ranged_left - delta)
	flash_left = maxf(0, flash_left - delta)
	retreat_left = maxf(0,retreat_left-delta)
	strike.stop()
	if state == State.DEAD:
		_present()
		if elapsed >= config.death_seconds:
			queue_free()
		return
	# No rearming after a blocked cast until recovery and complete separation.
	if shared_contact and state not in [State.WARNING, State.ACTIVE, State.RECOVER] and contact_box.get_overlapping_areas().is_empty():
		contact_box.hit_ids = []
		contact_box.reset_when_empty = true
		shared_contact = false
	if state in [State.WARNING, State.ACTIVE] and (not is_instance_valid(target) or target.state == Player.State.DEAD):
		_cancel_spell()
		_enter(State.RECOVER)
	velocity.y = minf(950.0, velocity.y + config.gravity * delta)
	velocity.x = 0
	match state:
		State.IDLE, State.APPROACH:
			if can_see_target():
				last_seen = target.global_position
				search_left = config.search_seconds
				facing = signf(target.global_position.x - global_position.x)
				if facing == 0:
					facing = 1
				var distance := absf(target.global_position.x-global_position.x)
				var closing := target.velocity.x*facing < -config.stationary_speed
				if completed_casts>0 and distance<config.retreat_trigger and (closing or distance<56) and retreat_left<=0 and _safe_step(-facing):
					retreat_direction = -facing
					_enter(State.RETREAT)
				elif distance >= config.ranged_minimum and ranged_left <= 0 and is_on_floor():
					ranged_cast = true
					_enter(State.WARNING)
				elif distance <= config.cast_distance and is_on_floor():
					ranged_cast = false
					_enter(State.WARNING)
				else:
					# In the ranged band, hold spacing while cooldown runs instead of
					# marching into the sword. Close the narrow gap to a melee cast.
					if distance>config.preferred_distance or distance<config.ranged_minimum:
						_walk_towards(last_seen.x)
					else:
						state = State.IDLE
			else:
				search_left = maxf(0,search_left-delta)
				_walk_towards(last_seen.x if search_left>0 else home.x)
		State.RETREAT:
			if elapsed>=config.retreat_seconds or not _safe_step(retreat_direction):
				_enter(State.IDLE)
			else:
				velocity.x = retreat_direction*config.retreat_speed
		State.WARNING:
			if elapsed >= warning_seconds():
				_enter(State.ACTIVE)
		State.ACTIVE:
			if elapsed >= active_seconds():
				completed_casts += 1
				_enter(State.RECOVER)
		State.RECOVER:
			if elapsed >= recovery_seconds():
				_enter(State.IDLE)
		State.HURT:
			if elapsed >= config.hurt_seconds:
				if recovery_after_hurt>0:
					_enter(State.RECOVER)
					elapsed = recovery_seconds()-recovery_after_hurt
				else:
					_enter(State.IDLE)
	move_and_slide()
	_present()
	if state == State.ACTIVE:
		var shapes := config.rising_shapes if cast_variant == 0 else config.curling_shapes
		var index := mini(int(elapsed / active_seconds() * shapes.size()), shapes.size()-1)
		var polygon := PackedVector2Array()
		for source: Vector2 in shapes[index]:
			var point := (source - Vector2(125,167)) * config.sprite_scale
			point.x *= facing
			polygon.append(point)
		strike.strike(polygon, config.damage)

func warning_seconds() -> float:
	return config.rising_warning if cast_variant == 0 else config.curling_warning

func active_seconds() -> float:
	return config.rising_active if cast_variant == 0 else config.curling_active

func recovery_seconds() -> float:
	return config.rising_recovery if cast_variant == 0 else config.curling_recovery

func _enter(next: State) -> void:
	state = next
	elapsed = 0
	strike.stop()
	if state==State.RETREAT:
		retreat_left = config.retreat_cooldown
	if state == State.WARNING:
		cast_variant = _choose_spell() if ranged_cast else _choose_arc()
		if ranged_cast:
			spell_repeats = spell_repeats+1 if cast_variant==last_spell else 1
			last_spell = cast_variant
			ranged_casts += 1
			next_spell = 1 - next_spell
			ranged_left = config.ranged_cooldown
		else:
			next_variant = 1 - next_variant
		strike.begin()
		contact_box.hit_ids = strike.hit_ids
		contact_box.reset_when_empty = false
		shared_contact = true
		if ranged_cast:
			_cancel_spell()
			spell = Node2D.new()
			spell.set_script(SPELL)
			spell.config = config
			spell.variant = cast_variant
			spell.facing = facing
			spell.locked_position = target.global_position
			spell.hit_ids = strike.hit_ids
			spell.warning_seconds = warning_seconds()
			add_child(spell)
			spell.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	if state == State.ACTIVE:
		Audio.play_sound("attack", 0.8, -6)

func _clip(name_text: StringName, first: int, count: int, seconds: float, loop := false) -> void:
	sprite.animation = name_text
	var index := int(elapsed / seconds * count)
	sprite.frame = first + (index % count if loop else mini(index, count-1))

func _present() -> void:
	sprite.stop()
	sprite.modulate = Color(2.4,2.1,2.5) if flash_left > 0 and not Session.reduce_flashes else Color.WHITE
	sprite.flip_h = facing < 0
	# flip_h mirrors around the fixed feet anchor; offset.x is zero for this pack.
	var cast_name := &"attack1" if cast_variant == 0 else &"attack2"
	match state:
		State.IDLE: _clip(&"idle", 0, 8, 0.8, true)
		State.APPROACH, State.RETREAT: _clip(&"run", 0, 8, 0.8, true)
		State.WARNING: _clip(cast_name, 0, 3 if cast_variant == 0 else 4, warning_seconds())
		State.ACTIVE: _clip(cast_name, 3 if cast_variant == 0 else 4, 4 if cast_variant == 0 else 3, active_seconds())
		State.RECOVER:
			if elapsed < 0.25:
				_clip(cast_name, 7, 1, 0.25)
			else:
				_clip(&"idle", 0, 8, 0.8, true)
		State.HURT: _clip(&"take_hit", 0, 3, config.hurt_seconds)
		State.DEAD: _clip(&"death", 0, 7, config.death_seconds)

func _on_damaged(_amount: int, _source: Vector2) -> void:
	flash_left = config.hit_flash_seconds
	if not stagger.register_hit():
		return
	_cancel_spell()
	if health.current > 0:
		recovery_after_hurt = maxf(0,recovery_seconds()-elapsed) if state==State.RECOVER else 0.0
		_enter(State.HURT)

func _on_died() -> void:
	_cancel_spell()
	_enter(State.DEAD)
	contact_box.end_swing()
	$Hurtbox.set_deferred("monitorable", false)
	defeated.emit()

func _cancel_spell() -> void:
	if is_instance_valid(spell):
		spell.cancel()
	spell = null

func _choose_spell() -> int:
	# Preserve each authored opening lesson. Later choices use observable motion,
	# never buttons, future positions or retargeting during an existing windup.
	if ranged_casts==0:
		return next_spell if target.is_on_floor() else 0
	var choice := 1 if target.is_on_floor() and absf(target.velocity.x)<config.stationary_speed else 0
	if choice==last_spell and spell_repeats>=2 and target.is_on_floor():
		choice = 1-choice
	return choice

func _choose_arc() -> int:
	# Select before committing. Keep the source shapes and full warning intact:
	# the inner sweep reaches close attackers; the outward rising arc does not.
	if is_instance_valid(target) and absf(target.global_position.x-global_position.x)<config.rising_minimum:
		return 1
	return next_variant

func _safe_step(direction: float) -> bool:
	if direction==0 or absf(global_position.x+direction*24-home.x)>config.leash_distance:
		return false
	edge.position.x = direction*24
	edge.force_raycast_update()
	var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-22),global_position+Vector2(direction*34,-22),1)
	return edge.is_colliding() and get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _walk_towards(x: float) -> void:
	var offset := x-global_position.x
	if absf(offset)>8 and _safe_step(signf(offset)):
		state = State.APPROACH
		facing = signf(offset)
		velocity.x = facing*config.move_speed
	else:
		state = State.IDLE
