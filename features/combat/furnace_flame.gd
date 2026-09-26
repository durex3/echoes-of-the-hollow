class_name FurnaceFlame
extends Area2D
## Source-pack flame art; each cast handles each target once, including blocks.
signal impact(at: Vector2, killed: bool)
@export var config: FurnaceConfig
@export var wave := false
var direction := -1.0
var warning_left := 0.0
var active_left := 0.0
var elapsed := 0.0
var handled: Array[int] = []
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	warning_left = 0.0 if wave else config.eruption_warning
	active_left = config.wave_seconds if wave else config.eruption_seconds
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26,38) if wave else Vector2(66,88)
	$Shape.shape = shape
	$Shape.position.y = -shape.size.y/2
	sprite.scale = Vector2(0.4,0.4) if wave else Vector2(0.7,0.7)
	sprite.position.y = -25.6 if wave else -44.8
	sprite.flip_h = wave and direction > 0
	sprite.region_rect = Rect2(128,0,128,128) if wave else Rect2(0,0,128,128)
	sprite.visible = warning_left <= 0

func _physics_process(delta: float) -> void:
	if warning_left > 0:
		warning_left = maxf(0,warning_left-delta)
		sprite.visible = warning_left <= 0
		queue_redraw()
		return
	active_left -= delta
	elapsed += delta
	if active_left <= 0:
		retire()
		return
	if wave:
		var motion := Vector2(direction*config.wave_speed*delta,0)
		var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-18),global_position+motion+Vector2(0,-18),1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			retire()
			return
		position += motion
	if global_position.x < config.arena_min_x or global_position.x > config.arena_max_x:
		retire()
		return
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox and area.get_instance_id() not in handled:
			var result: Hurtbox.HitResult = area.resolve_hit(config.damage,global_position)
			handled.append(area.get_instance_id())
			if result == Hurtbox.HitResult.DAMAGED:
				impact.emit(area.hit_position(),area.health.current == 0)
			if wave:
				retire()
				return
	var frame := 1+int(elapsed*12)%3 if wave else mini(4,int(elapsed/config.eruption_seconds*5))
	sprite.region_rect = Rect2(frame*128,0,128,128)
	queue_redraw()

func retire() -> void:
	set_physics_process(false)
	hide()
	queue_free()

func _draw() -> void:
	if warning_left > 0:
		draw_rect(Rect2(-33,-88,66,88),Color(1,0.45,0.65,0.10))
		draw_line(Vector2(-33,-3),Vector2(33,-3),Color("ff9bcc"),4)
		draw_line(Vector2(0,-12),Vector2(0,-36),Color("ff9bcc"),2)
