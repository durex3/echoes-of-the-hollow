@tool
extends Node2D

@export var room_width := 1152.0
@export var room_height := 384.0

func _draw() -> void:
	draw_rect(Rect2(0, 0, room_width, room_height), Color("182731"))
	draw_rect(Rect2(0, 64, room_width, 224), Color("263b46"))
	for x: float in [112.0, 368.0, 624.0, 880.0, 1088.0]:
		draw_line(Vector2(x, 64), Vector2(x, 288), Color("38525a"), 3.0)
		draw_circle(Vector2(x, 132), 42.0, Color(0.32, 0.76, 0.74, 0.06))
		draw_arc(Vector2(x, 132), 42.0, 0.0, TAU, 32, Color(0.47, 0.83, 0.78, 0.24), 2.0)
	draw_line(Vector2(32, 304), Vector2(room_width - 32, 304), Color("6e8790"), 3.0)
