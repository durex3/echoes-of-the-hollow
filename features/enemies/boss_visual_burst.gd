class_name BossVisualBurst
extends Node2D

var tint := Color("f4d49a")
var radius := 24.0
var duration := 0.24
var age := 0.0
var ring_count := 2
var rays := 8

func configure(next_tint: Color, next_radius: float, next_duration := 0.24, next_rings := 2, next_rays := 8) -> void:
	tint = next_tint
	radius = next_radius
	duration = next_duration
	ring_count = next_rings
	rays = next_rays
	queue_redraw()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 12

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(age / maxf(duration, 0.01), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var alpha := (1.0 - progress) * 0.8
	for index in range(ring_count):
		var ring_progress := clampf(eased + float(index) * 0.16, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * (0.35 + ring_progress * 0.85), 0.0, TAU, 24, Color(tint, alpha * (1.0 - float(index) * 0.22)), 2.0)
	for index in range(rays):
		var angle := TAU * float(index) / float(rays)
		var inner := radius * (0.18 + progress * 0.2)
		var outer := radius * (0.62 + eased * 0.72)
		draw_line(Vector2.from_angle(angle) * inner, Vector2.from_angle(angle) * outer, Color(tint, alpha * 0.7), 2.0)
