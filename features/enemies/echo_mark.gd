class_name EchoMark
extends Node2D

const GHOST_SHEET := preload("res://assets/characters/bell_warden_sheet.png")
const ARCANE_EXPLOSION := preload("res://assets/effects/bell_arcane_explosion.png")
const SPELL_BOLT := preload("res://assets/effects/bell_spell_bolt.png")
@export var delay_seconds := 0.72
@export var active_seconds := 0.28
@export var radius := 34.0
@export var damage := 1
@export var ghost_visual := false
@export var phase_offset := 0.0
@export var crosshair_visual := false
@export var travel_target := Vector2.ZERO
@export var travel_seconds := 0.0
@export var travel_radius := 12.0
var player: Player
var age := 0.0
var triggered := false
var hit := false
var travel_origin := Vector2.ZERO

func dispel() -> void:
	queue_free()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	travel_origin = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	if not triggered and age >= delay_seconds + phase_offset:
		triggered = true
		queue_redraw()
	if triggered and travel_seconds > 0.0:
		var progress := clampf((age - delay_seconds - phase_offset) / travel_seconds, 0.0, 1.0)
		var next_position := travel_origin.lerp(travel_target, progress)
		var motion := next_position - global_position
		if motion.length_squared() > 0.01:
			var shape := CircleShape2D.new()
			shape.radius = travel_radius
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0.0, global_position)
			query.motion = motion
			query.collision_mask = 1
			if get_world_2d().direct_space_state.cast_motion(query)[0] < 1.0:
				queue_free()
				return
			var player_hurt := player.get_node("Hurtbox") as Hurtbox if is_instance_valid(player) else null
			if player_hurt and not hit:
				var closest := Geometry2D.get_closest_point_to_segment(player_hurt.hit_position(), global_position, next_position)
				if closest.distance_to(player_hurt.hit_position()) <= travel_radius + 10.0:
					hit = true
					player_hurt.resolve_hit(damage, closest)
			global_position = next_position
	if triggered and not hit and age <= delay_seconds + phase_offset + active_seconds and is_instance_valid(player) and player.state != Player.State.DEAD:
		if travel_seconds <= 0.0 and player.global_position.distance_to(global_position) <= radius:
			hit = true
			(player.get_node("Hurtbox") as Hurtbox).resolve_hit(damage, global_position)
	if age > delay_seconds + phase_offset + active_seconds + 0.12:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var warning_progress := clampf((age - phase_offset) / maxf(delay_seconds, 0.01), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(age * 12.0)
	var color := Color("fff0bb") if not triggered else Color("ff78dd")
	if travel_seconds > 0.0:
		var ghost_frame := mini(5, int(warning_progress * 6.0)) if not triggered else 6 + mini(6, int((age - delay_seconds - phase_offset) / maxf(travel_seconds, 0.01) * 7.0))
		draw_texture_rect_region(GHOST_SHEET, Rect2(-37, -55, 74, 49), Rect2((ghost_frame % 8) * 140, (6 + ghost_frame / 8) * 93, 140, 93))
		if triggered:
			var bolt_frame := mini(7, int((age - delay_seconds - phase_offset) * 18.0) % 8)
			draw_arc(Vector2.ZERO, travel_radius, 0, TAU, 24, Color("ff78dd"), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0) if travel_target.x < travel_origin.x else Vector2.ONE)
			draw_texture_rect_region(SPELL_BOLT, Rect2(-22, -12, 44, 24), Rect2(bolt_frame * 64, 0, 64, 32))
			draw_set_transform(Vector2.ZERO)
	else:
		draw_arc(Vector2.ZERO, travel_radius + 4.0, 0, TAU, 24, color, 2.0)
		return
	var ground_center := Vector2(0, -5)
	draw_circle(Vector2(0, -3), radius * 0.72, Color(color, 0.25 + pulse * 0.1))
	draw_arc(ground_center, radius, 0.0, TAU, 32, color, 3.0)
	draw_arc(ground_center, radius * (0.45 + warning_progress * 0.4), 0.0, TAU, 24, color, 2.0)
	for index: int in range(4):
		var angle := TAU * float(index) / 4.0 + PI / 4.0
		var point := Vector2.from_angle(angle) * radius
		draw_line(point * 0.76 + ground_center, point * 1.17 + ground_center, color, 3.0)
	var spell_frame := mini(5, int(warning_progress * 6.0))
	if triggered:
		var active_progress := clampf((age - delay_seconds - phase_offset) / maxf(active_seconds, 0.01), 0.0, 1.0)
		spell_frame = 6 + mini(6, int(active_progress * 7.0))
		var blast_frame := mini(15, int(active_progress * 16.0))
		draw_texture_rect_region(ARCANE_EXPLOSION, Rect2(-radius, -radius * 2.0, radius * 2.0, radius * 2.0), Rect2(blast_frame * 64, 0, 64, 64))
	if crosshair_visual:
		draw_line(Vector2(-radius * 0.65, -5), Vector2(radius * 0.65, -5), color, 2.0)
	var column := spell_frame % 8
	var row := 6 + spell_frame / 8
	draw_texture_rect_region(GHOST_SHEET, Rect2(-68, -92, 140, 93), Rect2(column * 140, row * 93, 140, 93))
