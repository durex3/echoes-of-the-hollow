class_name BellWardenEffect
extends Node2D

const ARCANE_SLASH := preload("res://assets/effects/bell_arcane_slash.png")
const ARCANE_IMPACT := preload("res://assets/effects/bell_arcane_impact.png")

## Visuals follow the boss state; collision and damage stay on its hitboxes.
var state := 0
var attack := 0
var facing := -1.0
var phase := 1
var timer := 0.0
var windup := 1.0
var active := 0.0

func configure(next_state: int, next_attack: int, next_facing: float, next_phase: int, next_timer: float, next_windup: float, next_active: float) -> void:
	state = next_state
	attack = next_attack
	facing = next_facing
	phase = next_phase
	timer = next_timer
	windup = maxf(next_windup, 0.01)
	active = next_active
	queue_redraw()

func _draw() -> void:
	if state == 3: # WINDUP
		var p := clampf(1.0 - timer / windup, 0.0, 1.0)
		var glow := Color("f8c879") if attack == 0 else Color("ff739a")
		draw_arc(Vector2(facing * 11.0, -9), 18.0 + p * 4.0, -2.2, 1.1, 16, glow, 2.0 + p * 2.0)
		draw_circle(Vector2(facing * 16.0, -12), 3.0 + p * 3.0, glow)
	elif state == 4: # STRIKE
		var progress := clampf(1.0 - timer / maxf(active, 0.01), 0.0, 1.0)
		var frame := mini(15, int(progress * 16.0))
		var destination := Rect2(12, -43, 64, 64) if facing > 0 else Rect2(-76, -43, 64, 64)
		draw_texture_rect_region(ARCANE_SLASH, destination, Rect2(frame * 64, 0, 64, 64))
		if frame < 8:
			var impact_rect := Rect2(38, -33, 38, 38) if facing > 0 else Rect2(-76, -33, 38, 38)
			draw_texture_rect_region(ARCANE_IMPACT, impact_rect, Rect2(frame * 64, 0, 64, 64))
