class_name BellWardenEffect
extends Node2D

const ARCANE_SLASH := preload("res://assets/effects/bell_arcane_slash.png")
const ARCANE_IMPACT := preload("res://assets/effects/bell_arcane_impact.png")
const GHOST_SHEET := preload("res://assets/characters/bell_warden_sheet.png")

## Visuals follow the boss state; collision and damage stay on its hitboxes.
var state := 0
var attack := 0
var facing := -1.0
var timer := 0.0
var windup := 1.0
var active := 0.0

func configure(next_state: int, next_attack: int, next_facing: float, next_timer: float, next_windup: float, next_active: float) -> void:
	state = next_state
	attack = next_attack
	facing = next_facing
	timer = next_timer
	windup = maxf(next_windup, 0.01)
	active = next_active
	queue_redraw()

func _draw() -> void:
	if state == 3: # WINDUP
		var p := clampf(1.0 - timer / windup, 0.0, 1.0)
		var glow := Color("f8c879") if attack == 0 else Color("ff739a") if attack == 1 else Color("9feafa")
		draw_arc(Vector2(facing * 11.0, -9), 18.0 + p * 4.0, -2.2, 1.1, 16, glow, 2.0 + p * 2.0)
		draw_circle(Vector2(facing * 16.0, -12), 3.0 + p * 3.0, glow)
	elif state == 4: # STRIKE
		if attack >= 2:
			return
		var progress := clampf(1.0 - timer / maxf(active, 0.01), 0.0, 1.0)
		var frame := mini(15, int(progress * 16.0))
		var destination := Rect2(12, -43, 64, 64) if facing > 0 else Rect2(-76, -43, 64, 64)
		draw_texture_rect_region(ARCANE_SLASH, destination, Rect2(frame * 64, 0, 64, 64))
		if attack == 1:
			for trail: int in range(3):
				var trail_alpha := 0.30 - float(trail) * 0.08
				var trail_x := -facing * float(trail + 1) * 26.0
				draw_texture_rect_region(GHOST_SHEET, Rect2(trail_x - 34.0, -78.0, 68.0, 46.0), Rect2(0, 93, 140, 93), Color(0.95, 0.35, 0.65, trail_alpha))
		if frame < 8:
			var impact_rect := Rect2(38, -33, 38, 38) if facing > 0 else Rect2(-76, -33, 38, 38)
			draw_texture_rect_region(ARCANE_IMPACT, impact_rect, Rect2(frame * 64, 0, 64, 64))
