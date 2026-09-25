@tool
extends Node2D
## Authored visual rhythm; no physics geometry.
@export var room_width := 1280.0

func _draw() -> void:
	for x: int in range(96, int(room_width), 224):
		draw_rect(Rect2(x, 180, 80, 260), Color("172e35"))
		draw_rect(Rect2(x + 7, 188, 66, 242), Color("13222c"))
		draw_line(Vector2(x + 16, 222), Vector2(x + 64, 222), Color("ad794e"), 3)
		draw_circle(Vector2(x + 40, 236), 4, Color("e6a35c"))
		draw_line(Vector2(x + 40, 242), Vector2(x + 40, 430), Color("694e40"), 5)
	draw_rect(Rect2(0, 532, room_width, 44), Color("1d4147"))
	for x: int in range(8, int(room_width), 48):
		draw_line(Vector2(x, 544), Vector2(x + 22, 544), Color("4a777b"), 2)
