@tool
extends Node2D
## Background masonry and landmark silhouettes; no collision or gameplay state.
@export var belfry := false

func _draw() -> void:
	var width := 1280 if belfry else 960
	draw_rect(Rect2(0,480,width,96),Color("24333d"))
	if belfry:
		for x: int in [320,800]:
			draw_rect(Rect2(x,416,64,64),Color("30404a"))
		draw_line(Vector2(1110,0),Vector2(1110,300),Color("52616b"),4)
		draw_colored_polygon(PackedVector2Array([Vector2(1093,297),Vector2(1127,297),Vector2(1136,348),Vector2(1084,348)]),Color("4d6268"))
		draw_line(Vector2(1080,348),Vector2(1140,348),Color("829183"),5)
		draw_circle(Vector2(1110,358),5,Color("b4a985"))
	else:
		for x: int in [320,510,710]:
			draw_line(Vector2(x,218),Vector2(x,277),Color("52616b"),2)
			draw_colored_polygon(PackedVector2Array([Vector2(x,265),Vector2(x+34,279),Vector2(x,293)]),Color("426963"))
