class_name Hitbox
extends Area2D
## One target receives at most one hit per begin_swing(), regardless of frame rate.

signal landed
@export var damage := 1
var active := false
var hit_ids: Array[int] = []

func begin_swing() -> void:
	hit_ids.clear()
	active = true

func end_swing() -> void:
	active = false

func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox and area.get_instance_id() not in hit_ids:
			if area.receive_hit(damage, global_position):
				hit_ids.append(area.get_instance_id())
				landed.emit()
