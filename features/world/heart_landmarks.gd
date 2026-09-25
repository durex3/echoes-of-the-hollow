@tool
extends Node2D

func _draw() -> void:
	draw_rect(Rect2(0,480,640,96),Color("24333d"))
	for x: int in [32,192,352,512,608]:
		draw_rect(Rect2(x,120,16,360),Color("34464d"))
		draw_rect(Rect2(x-6,180,28,10),Color("718278"))
	draw_arc(Vector2(320,315),112,PI,TAU,48,Color("69796f"),6)
	draw_line(Vector2(208,315),Vector2(208,480),Color("69796f"),6)
	draw_line(Vector2(432,315),Vector2(432,480),Color("69796f"),6)
	for x: int in [288,320,352]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,266),Vector2(x+6,280),Vector2(x,294),Vector2(x-6,280)]),Color("d6ba7e"))
