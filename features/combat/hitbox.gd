class_name Hitbox
extends Area2D
## One target receives at most one hit per begin_swing(), regardless of frame rate.

signal landed
signal impact(at: Vector2, defeated: bool)
@export var damage := 1
var active := false
var hit_ids: Array[int] = []

func begin_swing() -> void:
	hit_ids.clear()
	active = false

func end_swing() -> void:
	active = false

func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox and area.get_instance_id() not in hit_ids:
			# Start at the body, since the forward attack area can cross a thin wall.
			var origin := Vector2((get_parent() as Node2D).global_position.x, global_position.y)
			var ray := PhysicsRayQueryParameters2D.create(origin, area.hit_position())
			ray.collision_mask = 1
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			var result: Hurtbox.HitResult = area.resolve_hit(damage, global_position)
			if result != Hurtbox.HitResult.IGNORED:
				hit_ids.append(area.get_instance_id())
			if result == Hurtbox.HitResult.DAMAGED:
				landed.emit()
				impact.emit(area.hit_position(), area.health.current == 0)
