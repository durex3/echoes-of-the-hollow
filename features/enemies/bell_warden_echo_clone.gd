class_name BellWardenEchoClone
extends Node2D

const SHEET := preload("res://assets/characters/bell_warden_sheet.png")
const SLASH := preload("res://assets/effects/bell_arcane_slash.png")

var player: Player
var facing := -1.0
var delay_seconds := 0.72
var active_seconds := 0.32
var damage := 1
var reach := 94.0
var age := 0.0
var hit := false
var attack_started := false
var sprite: Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.15, 1.15)
	sprite.position = Vector2(facing * 40.0, -49.0)
	sprite.flip_h = facing > 0.0
	sprite.modulate = Color(0.72, 0.86, 1.0, 0.82)
	sprite.region_rect = Rect2(0, 186, 140, 93)
	add_child(sprite)

func _physics_process(delta: float) -> void:
	age += delta
	attack_started = age >= delay_seconds
	if attack_started and age <= delay_seconds + active_seconds and not hit and is_instance_valid(player) and player.state != Player.State.DEAD:
		var hurt := player.get_node("Hurtbox") as Hurtbox
		var center := hurt.hit_position() - global_position
		if center.x * facing >= -12.0 and center.x * facing <= reach and absf(center.y + 28.0) <= 31.0:
			hit = true
			hurt.resolve_hit(damage, global_position + Vector2(facing * 42.0, -28.0))
	if age > delay_seconds + active_seconds + 0.16:
		queue_free()
		return
	var frame := 16 + mini(3, int(age / maxf(delay_seconds, 0.01) * 4.0))
	if attack_started:
		frame = 20 + mini(3, int((age - delay_seconds) / maxf(active_seconds, 0.01) * 4.0))
	if age > delay_seconds + active_seconds:
		frame = 24
	sprite.region_rect = Rect2((frame % 8) * 140, int(frame / 8.0) * 93, 140, 93)
	queue_redraw()

func _draw() -> void:
	if not attack_started:
		var progress := clampf(age / maxf(delay_seconds, 0.01), 0.0, 1.0)
		draw_circle(Vector2(facing * 15.0, -28.0), 2.0 + progress * 3.0, Color(0.76, 0.89, 1.0, 0.5 + progress * 0.4))
		return
	if age > delay_seconds + active_seconds:
		return
	var frame := mini(15, int((age - delay_seconds) / maxf(active_seconds, 0.01) * 16.0))
	var slash_x := 14.0 if facing > 0.0 else -102.0
	draw_texture_rect_region(SLASH, Rect2(slash_x, -74.0, 88.0, 64.0), Rect2(frame * 64.0, 0.0, 64.0, 64.0), Color(0.7, 0.88, 1.0, 0.9))
