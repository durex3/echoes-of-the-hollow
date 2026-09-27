class_name RoyalSword
extends Node2D
## A source-art sword: harmless summon/aim, swept flight, harmless impact/fade.
signal impact(at: Vector2, defeated: bool)
enum Phase { SUMMON, HOVER, AIM, FLIGHT, IMPACT, FADING, RETIRED }
@export var config: SwordCourtConfig
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sweep: ShapeCast2D = $Sweep
var phase := Phase.SUMMON
var elapsed := 0.0
var summon_delay := 0.0
var royal := false
var art_scale := 1.0
var aim_point := Vector2.ZERO
var direction := Vector2.DOWN
var start_angle := 0.0
var aim_seconds := 0.55
var hit_ids: Array[int] = []
var target: Player

func _ready() -> void:
	art_scale = config.royal_scale if royal else config.sword_scale
	sprite.scale = Vector2.ONE * art_scale
	var shape := RectangleShape2D.new()
	shape.size = config.blade_size * art_scale
	sweep.shape = shape
	sweep.position.y = -4.0 * art_scale
	_sync_pose()

func lock_on(at: Vector2, seconds: float) -> void:
	phase = Phase.AIM
	elapsed = 0.0
	aim_point = at
	direction = (at - global_position).normalized()
	start_angle = rotation
	aim_seconds = seconds

func launch(processed: Array[int]) -> void:
	phase = Phase.FLIGHT
	elapsed = 0.0
	hit_ids = processed
	rotation = direction.angle() + PI / 2.0
	sprite.position = Vector2.ZERO
	_sync_pose()

func dangerous() -> bool:
	return phase == Phase.FLIGHT

func _physics_process(delta: float) -> void:
	elapsed += delta
	match phase:
		Phase.SUMMON:
			if elapsed >= summon_delay + config.summon_frame_seconds:
				phase = Phase.HOVER
				elapsed = 0.0
		Phase.AIM:
			rotation = lerp_angle(start_angle, direction.angle() + PI / 2.0, smoothstep(0.0,0.7,elapsed/aim_seconds))
		Phase.FLIGHT:
			if is_instance_valid(target) and target.state == Player.State.DEAD:
				retire()
				return
			if elapsed >= config.flight_lifetime:
				retire()
				return
			if is_instance_valid(target):
				aim_point = target.global_position + config.aim_offset
				var desired := global_position.direction_to(aim_point)
				var turn := (config.royal_turn_speed if royal else config.turn_speed) * delta
				direction = direction.rotated(clampf(direction.angle_to(desired),-turn,turn)).normalized()
				rotation = direction.angle() + PI / 2.0
			var distance := (config.royal_speed if royal else config.sword_speed) * delta
			sweep.target_position = Vector2.ZERO
			sweep.force_shapecast_update()
			if not _resolve_collision(0.0):
				sweep.target_position = Vector2(0,-distance)
				sweep.force_shapecast_update()
				if not _resolve_collision(distance):
					global_position += direction * distance
		Phase.IMPACT:
			if elapsed >= config.impact_seconds:
				phase = Phase.FADING
				elapsed = 0.0
		Phase.FADING:
			if elapsed >= config.fade_seconds:
				retire()
				return
	_sync_pose()

func _resolve_collision(distance: float) -> bool:
	if not sweep.is_colliding():
		return false
	global_position += direction * distance * sweep.get_closest_collision_safe_fraction()
	var hurt: Hurtbox
	var blocked_by_world := false
	var contact_point := global_position
	for index: int in range(sweep.get_collision_count()):
		var collider := sweep.get_collider(index)
		if collider is Hurtbox:
			hurt = collider
		else:
			blocked_by_world = true
			contact_point = sweep.get_collision_point(index)
	if not blocked_by_world and is_instance_valid(hurt) and hurt.get_instance_id() not in hit_ids:
		var result: Hurtbox.HitResult = hurt.resolve_hit(config.damage,global_position)
		# Damage can synchronously end the encounter and retire every sword.
		if phase == Phase.RETIRED:
			return true
		if result != Hurtbox.HitResult.IGNORED:
			hit_ids.append(hurt.get_instance_id())
		if result == Hurtbox.HitResult.DAMAGED:
			impact.emit(hurt.hit_position(),hurt.health.current == 0)
	phase = Phase.IMPACT
	elapsed = 0.0
	# Settled source cells face right; preserve the incoming blade direction.
	rotation = direction.angle()
	if blocked_by_world:
		global_position = contact_point - direction * config.impact_tip_offset * art_scale
	Audio.play_sound("attack",0.7 if royal else 1.2,-8.0 if royal else -16.0)
	return true

func _sync_pose() -> void:
	visible = elapsed >= summon_delay if phase == Phase.SUMMON else phase != Phase.RETIRED
	var clip: StringName = &"hover"
	var progress := 0.0
	if phase == Phase.SUMMON:
		clip = &"summon"
		progress = maxf(0.0,elapsed-summon_delay)/config.summon_frame_seconds
	elif phase == Phase.FLIGHT:
		clip = &"fly"
	elif phase == Phase.IMPACT:
		clip = &"impact"
		progress = elapsed/config.impact_seconds
	elif phase == Phase.FADING:
		clip = &"fade"
		progress = elapsed/config.fade_seconds
	else:
		progress = fmod(elapsed,0.5)/0.5
	sprite.animation = clip
	sprite.frame = mini(sprite.sprite_frames.get_frame_count(clip)-1,int(clampf(progress,0,1)*sprite.sprite_frames.get_frame_count(clip)))
	sprite.offset = -Vector2(77,94) if phase in [Phase.IMPACT,Phase.FADING] else -Vector2(24,43)
	var brightness := 1.0
	if phase == Phase.AIM:
		brightness = 1.3 if Session.reduce_flashes else 1.2 + 0.55 * clampf(elapsed/aim_seconds,0,1)
	sprite.modulate = Color(brightness,brightness,brightness,0.75 if phase == Phase.HOVER else 1.0)

func retire() -> void:
	phase = Phase.RETIRED
	hide()
	set_physics_process(false)
	queue_free()
