class_name InkBolt
extends Node2D
## A room-owned, non-homing projectile with a swept 5px collision radius.
signal impact(at: Vector2, defeated: bool)
@export var config: ScribeConfig
@onready var sweep: ShapeCast2D = $Sweep
var direction := Vector2.LEFT
var source_id := 0
var age := 0.0
var spent := false

func _ready() -> void:
	direction = direction.normalized()
	$Sprite.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if spent:
		return
	age += delta
	if age >= config.bolt_lifetime:
		retire()
		return
	var motion := direction * config.bolt_speed * delta
	# Check initial overlaps as well as the full path; no fast-bolt tunneling.
	sweep.target_position = Vector2.ZERO
	sweep.force_shapecast_update()
	if _resolve_collision():
		return
	sweep.target_position = motion
	sweep.force_shapecast_update()
	if _resolve_collision():
		return
	position += motion
	queue_redraw()

func _resolve_collision() -> bool:
	if not sweep.is_colliding():
		return false
	# Contacts are at the earliest swept impact; solid cover wins ties.
	for i: int in range(sweep.get_collision_count()):
		if not sweep.get_collider(i) is Hurtbox:
			retire()
			return true
	var hurt := sweep.get_collider(0) as Hurtbox
	if hurt and hurt.receive_hit(config.bolt_damage, global_position):
		impact.emit(hurt.hit_position(), hurt.health.current == 0)
	# Invulnerability also consumes the bolt: no delayed damage after overlap.
	retire()
	return true

func retire() -> void:
	spent = true
	set_physics_process(false)
	hide()
	queue_free()

func _draw() -> void:
	draw_line(-direction * 17, -direction * 5, Color("9570cb"), 3)
	draw_circle(Vector2.ZERO, 5, Color("b181ee"))
	draw_circle(Vector2.ZERO, 2, Color("f3dbff"))
