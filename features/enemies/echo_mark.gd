class_name EchoMark
extends Node2D

const GHOST_SHEET := preload("res://assets/characters/bell_warden_sheet.png")
const ARCANE_EXPLOSION := preload("res://assets/effects/bell_arcane_explosion.png")
const SPELL_BOLT := preload("res://assets/effects/bell_spell_bolt.png")
const RESONANCE_RING := preload("res://assets/effects/bell_resonance_ring.png")
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
@export_enum("target", "resonance", "drop", "memory") var pattern := "target"
@export var replay_delay := 0.62
var player: Player
var age := 0.0
var triggered := false
var hit := false
var travel_origin := Vector2.ZERO
var memory_recorded := false

func dispel() -> void:
	queue_free()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	travel_origin = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	if pattern == "memory":
		if not memory_recorded and age >= delay_seconds + phase_offset and is_instance_valid(player):
			global_position = player.global_position
			memory_recorded = true
			queue_redraw()
		if memory_recorded and not triggered and age >= delay_seconds + phase_offset + replay_delay:
			triggered = true
			queue_redraw()
	elif not triggered and age >= delay_seconds + phase_offset:
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
	var lifetime := delay_seconds + phase_offset + active_seconds + 0.12
	if pattern == "memory":
		lifetime = delay_seconds + phase_offset + replay_delay + active_seconds + 0.12
	if age > lifetime:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if pattern == "memory":
		_draw_memory()
		return
	if pattern == "resonance":
		_draw_resonance()
		return
	if pattern == "drop":
		_draw_drop()
		return
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
		if ghost_visual:
			var ghost_frame := mini(7, int(warning_progress * 8.0)) if not triggered else 8 + mini(7, int((age - delay_seconds - phase_offset) / maxf(active_seconds, 0.01) * 8.0))
			draw_texture_rect_region(GHOST_SHEET, Rect2(-49, -61, 98, 65), Rect2((ghost_frame % 8) * 140, (6 + ghost_frame / 8) * 93, 140, 93))
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 24, color, 2.0)
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

func _draw_resonance() -> void:
	var warning_progress := clampf((age - phase_offset) / maxf(delay_seconds, 0.01), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(age * 14.0)
	var color := Color("ffe7a1") if not triggered else Color("f16cff")
	var width := 30.0 + pulse * 5.0 if not triggered else 52.0
	var height := 7.0 if not triggered else 15.0
	draw_rect(Rect2(-width, -height, width * 2.0, height * 2.0), Color(color, 0.18 if not triggered else 0.4), true)
	draw_line(Vector2(-width, 0), Vector2(width, 0), color, 2.0)
	draw_line(Vector2(-width * 0.7, -height), Vector2(width * 0.7, -height), color, 2.0)
	if triggered:
		var frame := mini(15, int((age - delay_seconds - phase_offset) / maxf(active_seconds, 0.01) * 16.0))
		draw_texture_rect_region(RESONANCE_RING, Rect2(-46, -46, 92, 92), Rect2(frame * 64, 0, 64, 64))

func _draw_memory() -> void:
	var record_progress := clampf((age - phase_offset) / maxf(delay_seconds + 0.01, 0.01), 0.0, 1.0)
	var color := Color("ffe7a1") if not memory_recorded else Color("bf8cff")
	if not memory_recorded:
		draw_arc(Vector2.ZERO, 22.0 + record_progress * 12.0, 0.0, TAU, 24, color, 2.0)
		draw_line(Vector2(-12, -2), Vector2(12, -2), color, 2.0)
		return
	var ghost_frame := mini(7, int((age - phase_offset) * 12.0) % 8)
	draw_texture_rect_region(GHOST_SHEET, Rect2(-43, -57, 86, 57), Rect2((ghost_frame % 8) * 140, (6 + ghost_frame / 8) * 93, 140, 93))
	# A readable player-shaped memory silhouette makes the recorded position clear at native scale.
	var memory_color := Color(0.75, 0.55, 1.0, 0.72)
	draw_circle(Vector2(0, -48), 5.0, memory_color)
	draw_line(Vector2(0, -42), Vector2(0, -23), memory_color, 3.0)
	draw_line(Vector2(0, -36), Vector2(-8, -29), memory_color, 2.0)
	draw_line(Vector2(0, -36), Vector2(8, -29), memory_color, 2.0)
	draw_line(Vector2(0, -23), Vector2(-7, -12), memory_color, 2.0)
	draw_line(Vector2(0, -23), Vector2(7, -12), memory_color, 2.0)
	var replay_progress := clampf((age - delay_seconds - phase_offset - replay_delay) / maxf(active_seconds, 0.01), 0.0, 1.0)
	if not triggered:
		draw_arc(Vector2.ZERO, 27.0 + sin(age * 12.0) * 3.0, 0.0, TAU, 24, Color("e7b6ff"), 2.0)
	else:
		var frame := mini(15, int(replay_progress * 16.0))
		draw_texture_rect_region(ARCANE_EXPLOSION, Rect2(-42, -84, 84, 84), Rect2(frame * 64, 0, 64, 64))
		draw_arc(Vector2.ZERO, 34.0 + (1.0 - replay_progress) * 18.0, 0.0, TAU, 28, Color(1.0, 0.8, 0.98, 0.72 * (1.0 - replay_progress)), 3.0)

func _draw_drop() -> void:
	var warning_progress := clampf((age - phase_offset) / maxf(delay_seconds, 0.01), 0.0, 1.0)
	var color := Color("ffe3a8") if not triggered else Color("ff72d9")
	var bell_y := -184.0 + warning_progress * 110.0 if not triggered else -68.0 + minf(1.0, (age - delay_seconds - phase_offset) / 0.07) * 68.0
	_draw_bell(Vector2(0, bell_y), color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0)
	draw_line(Vector2(-radius, -3), Vector2(radius, -3), color, 2.0)
	if triggered:
		var blast := clampf((age - delay_seconds - phase_offset) / maxf(active_seconds, 0.01), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color("ff78dd", 0.28))
		draw_circle(Vector2.ZERO, radius, Color("fff0cb"), false, 4.0)
		var frame := mini(15, int(blast * 16.0))
		draw_texture_rect_region(ARCANE_EXPLOSION, Rect2(-radius, -radius * 2.0, radius * 2.0, radius * 2.0), Rect2(frame * 64, 0, 64, 64))

func _draw_bell(at: Vector2, color: Color) -> void:
	var outline := PackedVector2Array([Vector2(-31, 0), Vector2(-31, -7), Vector2(-25, -7), Vector2(-25, -31), Vector2(-19, -31), Vector2(-19, -43), Vector2(-9, -49), Vector2(9, -49), Vector2(19, -43), Vector2(19, -31), Vector2(25, -31), Vector2(25, -7), Vector2(31, -7), Vector2(31, 0)])
	for index: int in range(outline.size()):
		outline[index] += at
	draw_colored_polygon(outline, Color("35283e"))
	draw_polyline(outline, color, 3.0)
	draw_rect(Rect2(at + Vector2(-22, -12), Vector2(44, 5)), Color("8b6d87"))
	draw_rect(Rect2(at + Vector2(-18, -38), Vector2(6, 25)), Color("b59aad"))
	draw_rect(Rect2(at + Vector2(13, -38), Vector2(5, 25)), Color("7a5d89"))
	draw_rect(Rect2(at + Vector2(-4, 1), Vector2(8, 12)), color)
	draw_polyline(PackedVector2Array([at + Vector2(8, -47), at + Vector2(1, -28), at + Vector2(10, -14), at + Vector2(4, -1)]), Color("ff9be8"), 3.0)
