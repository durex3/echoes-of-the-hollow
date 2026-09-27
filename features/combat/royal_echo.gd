class_name RoyalEcho
extends Node2D
## Three grounded fragments from the supplied Earth Wall animation.
signal impact(at: Vector2, defeated: bool)
enum Phase { CHARGING, BURST, FADING }
# Opaque bounds of source frames 3-6 inside the common 18x25 crop.
# All pieces share source pivot (22, 39), at the floor.
const BURST_BOUNDS: Array[Rect2] = [
	Rect2(0, 0, 18, 25), Rect2(0, 1, 18, 24),
	Rect2(0, 1, 18, 24), Rect2(0, 1, 18, 24),
]
const PIECE_SCALES: Array[float] = [1.0, 0.85, 0.85]
const PIECE_OFFSETS: Array[float] = [0.0, -16.0, 16.0]
@export var config: WardenConfig
var width := 120.0
var direction := 1.0
var phase := Phase.CHARGING
var elapsed := 0.0
var art_scale := 1.0
var sprites: Array[AnimatedSprite2D] = []
var hitboxes: Array[Hitbox] = []
var collisions: Array[CollisionShape2D] = []
@onready var hitbox: Hitbox = $Hitbox
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Hitbox/Shape

func _ready() -> void:
	top_level = true
	art_scale = minf(width / 47.3, config.echo_height / 25.0)
	sprites.append(sprite)
	hitboxes.append(hitbox)
	collisions.append(collision)
	for index: int in range(1, 3):
		var fragment := sprite.duplicate() as AnimatedSprite2D
		add_child(fragment)
		sprites.append(fragment)
		var box := hitbox.duplicate() as Hitbox
		add_child(box)
		hitboxes.append(box)
		collisions.append(box.get_node("Shape") as CollisionShape2D)
	for index: int in range(3):
		collisions[index].shape = RectangleShape2D.new()
		var piece_scale := art_scale * PIECE_SCALES[index]
		sprites[index].scale = Vector2.ONE * piece_scale
		sprites[index].position = Vector2(PIECE_OFFSETS[index] * art_scale * direction, -12.5 * piece_scale)
		sprites[index].flip_h = direction < 0.0
		hitboxes[index].damage = config.echo_damage
		# Reference the same array: a ward or hit consumes this entire eruption.
		hitboxes[index].hit_ids = hitbox.hit_ids
		hitboxes[index].impact.connect(func(at: Vector2, defeated: bool) -> void: impact.emit(at, defeated))
	_sync_pose()

func _physics_process(delta: float) -> void:
	elapsed += delta
	match phase:
		Phase.CHARGING:
			if elapsed >= config.echo_delay:
				phase = Phase.BURST
				elapsed = 0.0
				for box: Hitbox in hitboxes:
					box.begin_swing()
					box.active = true
				Audio.play_sound("attack", 0.6, -7.0)
		Phase.BURST:
			if elapsed >= config.echo_active_seconds:
				for box: Hitbox in hitboxes:
					box.end_swing()
				phase = Phase.FADING
				elapsed = 0.0
		Phase.FADING:
			if elapsed >= config.echo_fade_seconds:
				retire()
				return
	_sync_pose()

func _sync_pose() -> void:
	# One physics clock drives both the atlas pose and active damage dimensions.
	# AnimatedSprite remains stopped; no second render-clock animation can drift.
	var clip: StringName = &"charge" if phase == Phase.CHARGING else &"burst" if phase == Phase.BURST else &"settle"
	var duration := config.echo_delay if phase == Phase.CHARGING else config.echo_active_seconds if phase == Phase.BURST else config.echo_fade_seconds
	var count := sprite.sprite_frames.get_frame_count(clip)
	var frame := mini(count - 1, int(elapsed / maxf(duration, 0.01) * count))
	var bounds := BURST_BOUNDS[frame] if phase == Phase.BURST else BURST_BOUNDS[0]
	for index: int in range(3):
		sprites[index].animation = clip
		sprites[index].frame = frame
		var piece_scale := art_scale * PIECE_SCALES[index]
		(collisions[index].shape as RectangleShape2D).size = bounds.size * piece_scale
		var center := bounds.get_center() - Vector2(9, 25)
		center.x *= direction
		hitboxes[index].position = center * piece_scale + Vector2(PIECE_OFFSETS[index] * art_scale * direction, 0)

func retire() -> void:
	for box: Hitbox in hitboxes:
		box.end_swing()
		box.set_physics_process(false)
	set_physics_process(false)
	hide()
	queue_free()
