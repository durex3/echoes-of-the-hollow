class_name EchoMark
extends Node2D

const GHOST_SHEET := preload("res://assets/characters/bell_warden_sheet.png")
@export var delay_seconds := 0.72
@export var active_seconds := 0.28
@export var radius := 34.0
@export var damage := 1
@export var ghost_visual := false
var player: Player
var age := 0.0
var triggered := false
var hit := false

func dispel() -> void:
	queue_free()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	if not triggered and age >= delay_seconds:
		triggered = true
		queue_redraw()
	if triggered and not hit and age <= delay_seconds + active_seconds and is_instance_valid(player) and player.state != Player.State.DEAD:
		if player.global_position.distance_to(global_position) <= radius:
			hit = true
			(player.get_node("Hurtbox") as Hurtbox).resolve_hit(damage, global_position)
	if age > delay_seconds + active_seconds + 0.12:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color("d5a4ff", 0.72 if triggered else 0.4)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, color, 3.0)
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 20, Color(color, 0.34), 2.0)
	if triggered:
		draw_line(Vector2(-radius, 0), Vector2(radius, 0), Color("f2ddff", 0.85), 2.0)
		draw_line(Vector2(0, -radius), Vector2(0, radius), Color("f2ddff", 0.85), 2.0)
	if ghost_visual:
		var frame := 7 if triggered else 0
		draw_texture_rect_region(GHOST_SHEET, Rect2(-42, -78, 84, 56), Rect2(frame * 140, 6 * 93, 140, 93))
