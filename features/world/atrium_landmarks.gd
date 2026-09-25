@tool
extends Node2D
## Quiet threshold, masonry and sealed inner door; visuals never move collisions.

func _draw() -> void:
	draw_rect(Rect2(0,480,960,96),Color("24333d"))
	draw_rect(Rect2(416,416,96,64),Color("30404a"))
	draw_rect(Rect2(576,352,320,128),Color("30404a"))
	for x: int in [290,550,910]:
		draw_rect(Rect2(x,190,20,290),Color("34464d"))
		draw_rect(Rect2(x-5,188,30,12),Color("69796f"))
		draw_circle(Vector2(x+10,255),26,Color(0.58,0.89,0.81,0.05))
		draw_circle(Vector2(x+10,255),4,Color("94e4ce"))
	draw_rect(Rect2(777,225,78,127),Color("111d29"))
	draw_arc(Vector2(816,225),39,PI,TAU,32,Color("69796f"),5)
	draw_line(Vector2(777,225),Vector2(777,352),Color("69796f"),5)
	draw_line(Vector2(855,225),Vector2(855,352),Color("69796f"),5)
	for x: int in [797,816,835]:
		draw_line(Vector2(x,226),Vector2(x,350),Color("52616b"),3)
	draw_colored_polygon(PackedVector2Array([Vector2(816,260),Vector2(826,278),Vector2(816,296),Vector2(806,278)]),Color("d6ba7e"))
