class_name BellFrameStrike
extends Node2D
## Synchronous shape query: the displayed source frame and damage use one clock.
## Shared with the body contact box for the lifetime of a single committed attack.
signal impact(at: Vector2, killed: bool)
var hit_ids: Array[int] = []
var active := false
var last_polygon := PackedVector2Array()

func begin() -> void:
	hit_ids = []
	stop()

func stop() -> void:
	active = false
	last_polygon = PackedVector2Array()

func strike(polygon: PackedVector2Array, damage: int) -> void:
	if polygon.size() < 3:
		stop()
		return
	last_polygon = polygon
	active = true
	# Preserve the empty inner curve of a crescent; a convex hull would add damage.
	for convex: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(polygon):
		_query_convex(convex, damage)

func _query_convex(polygon: PackedVector2Array, damage: int) -> void:
	var shape := ConvexPolygonShape2D.new()
	shape.points = polygon
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		var hurt := result.collider as Hurtbox
		if not hurt or hurt.get_instance_id() in hit_ids:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-18), hurt.hit_position(), 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var outcome := hurt.resolve_hit(damage, global_position)
		if outcome != Hurtbox.HitResult.IGNORED:
			hit_ids.append(hurt.get_instance_id())
		if outcome == Hurtbox.HitResult.DAMAGED:
			impact.emit(hurt.hit_position(), hurt.health.current <= 0)
