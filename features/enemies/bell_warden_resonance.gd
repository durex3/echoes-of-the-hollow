class_name BellWardenResonance
extends Node2D

const RING := preload("res://assets/effects/bell_resonance_ring.png")

var player: Player
var warning_seconds := 1.2
var active_seconds := 0.26
var damage := 1
var left := 0.0
var right := 576.0
var floor_y := 320.0
var age := 0.0
var hit := false

func configure_layer(start_x: float, end_x: float, height: float) -> void:
	left = start_x
	right = end_x
	floor_y = height

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5

func _physics_process(delta: float) -> void:
	age += delta
	if age >= warning_seconds and age <= warning_seconds + active_seconds and not hit and is_instance_valid(player) and player.state != Player.State.DEAD:
		var hurt := player.get_node("Hurtbox") as Hurtbox
		var center := hurt.hit_position()
		if center.x >= left and center.x <= right and absf(player.global_position.y - floor_y) <= 20.0:
			hit = true
			hurt.resolve_hit(damage, Vector2(center.x, floor_y))
	if age > warning_seconds + active_seconds + 0.12:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var active := age >= warning_seconds
	var progress := clampf(age / maxf(warning_seconds, 0.01), 0.0, 1.0)
	var color := Color("fa80d8") if active else Color("f4d49a")
	var thickness := 9.0 if active else 2.0 + progress * 3.0
	draw_line(Vector2(left, floor_y - 4.0), Vector2(right, floor_y - 4.0), color, thickness)
	var count := maxi(1, int((right - left) / 64.0))
	for index in range(count + 1):
		var x := lerpf(left + 20.0, right - 20.0, float(index) / float(count))
		var radius := 15.0 + progress * 8.0
		draw_arc(Vector2(x, floor_y - 9.0), radius, PI, TAU, 12, color, 2.0)
		if active:
			var frame := mini(15, int((age - warning_seconds) / maxf(active_seconds, 0.01) * 16.0))
			draw_texture_rect_region(RING, Rect2(x - 28.0, floor_y - 39.0, 56.0, 56.0), Rect2(frame * 64.0, 0.0, 64.0, 64.0))
