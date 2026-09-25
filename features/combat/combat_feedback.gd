extends Node2D

const IMPACT := preload("res://features/combat/impact_effect.gd")
@export var camera: Camera2D
var trauma := 0.0
var clock := 0.0
var impacts := 0

func show_impact(at: Vector2, defeated: bool, with_audio := true) -> void:
	impacts += 1
	var effect := Node2D.new()
	effect.set_script(IMPACT)
	effect.strong = defeated
	add_child(effect)
	effect.global_position = at
	trauma = minf(trauma + (0.6 if defeated else 0.32), 0.8)
	if with_audio:
		Audio.play_sound("slime_death" if defeated else "hit")

func _process(delta: float) -> void:
	clock += delta * 45
	trauma = maxf(0, trauma - delta * 3.5)
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO if Session.reduce_shake else Vector2(sin(clock), sin(clock * 1.7)) * 3 * trauma * trauma

func clear() -> void:
	trauma = 0
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
	for child: Node in get_children():
		child.queue_free()
