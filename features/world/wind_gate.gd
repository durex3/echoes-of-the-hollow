class_name WindGate
extends StaticBody2D
## Solid to normal movement; only a colliding dash can break the seal.
signal breached(stable_id: String)
@export var stable_id := "wind_passage_open"
var opened := false

func breach() -> bool:
	if opened:
		return true
	set_open(true)
	breached.emit(stable_id)
	return true

func set_open(value: bool) -> void:
	opened = value
	$CollisionShape2D.set_deferred("disabled", value)
	queue_redraw()

func _draw() -> void:
	if opened:
		draw_line(Vector2(-20,-2),Vector2(20,-2),Color("94e4ce"),3)
		return
	draw_rect(Rect2(-12,-480,24,480),Color(0.25,0.75,0.7,0.25))
	for y: int in range(-472,-8,32):
		draw_polyline(PackedVector2Array([Vector2(-9,y-7),Vector2(0,y),Vector2(-9,y+7)]),Color("94e4ce"),2)
		draw_polyline(PackedVector2Array([Vector2(2,y-7),Vector2(11,y),Vector2(2,y+7)]),Color("e9d4a3"),1)
