class_name BellWardenEffect
extends Node2D

const ARCANE_SLASH := preload("res://assets/effects/bell_arcane_slash.png")
const ARCANE_IMPACT := preload("res://assets/effects/bell_arcane_impact.png")
const ARCANE_EXPLOSION := preload("res://assets/effects/bell_arcane_explosion.png")

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
	elif state == 5: # RESONANCE WARNING
		var p := clampf(1.0 - timer / maxf(windup, 0.01), 0.0, 1.0)
		# Memory recording: three beats, then replay. No future danger shape is drawn here.
		var beat_count := 4 if phase == 3 else 3
		for beat: int in range(beat_count):
			var beat_progress := clampf(p * 1.35 - float(beat) * 0.29, 0.0, 1.0)
			var x := (float(beat) - float(beat_count - 1) * 0.5) * 22.0
			draw_circle(Vector2(x, -66), 5.0 + beat_progress * 3.0, Color(1.0, 0.82, 0.45, 0.35 + beat_progress * 0.6), false, 2.0)
			draw_line(Vector2(x, -58), Vector2(x, -43), Color(1.0, 0.82, 0.45, 0.35 + beat_progress * 0.5), 2.0)
		draw_line(Vector2(-34, -39), Vector2(34, -39), Color("8e739f"), 2.0)
	elif state == 6: # RESONANCE ACTIVE
		var replay := clampf(1.0 - timer / maxf(active, 0.01), 0.0, 1.0)
		var frame := mini(15, int(replay * 16.0))
		draw_texture_rect_region(ARCANE_EXPLOSION, Rect2(-42, -84, 84, 84), Rect2(frame * 64, 0, 64, 64))
		var beat_count := 4 if phase == 3 else 3
		for beat: int in range(beat_count):
			var x := (float(beat) - float(beat_count - 1) * 0.5) * 22.0
			var pulse := clampf(replay * float(beat_count) - float(beat), 0.0, 1.0)
			draw_circle(Vector2(x, -66), 7.0 + pulse * 5.0, Color(0.86, 0.58, 1.0, 0.25 + pulse * 0.5), false, 2.0)
	elif state == 12: # FALLING BELL WARNING
		var p := clampf(1.0 - timer / maxf(windup, 0.01), 0.0, 1.0)
		draw_arc(Vector2(0, -46), 18.0 + p * 22.0, PI + 0.2, TAU - 0.2, 24, Color("e8a5ff"), 3.0)
	elif state == 13: # FALLING BELL ACTIVE
		draw_arc(Vector2(0, -46), 42.0, PI + 0.2, TAU - 0.2, 24, Color("ffb8f3"), 3.0)
	elif state == 14: # STAGGER
		for ring: int in range(3):
			draw_arc(Vector2(0, -42), 24.0 + float(ring) * 12.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.45, 0.8 - ring * 0.2), 3.0)
