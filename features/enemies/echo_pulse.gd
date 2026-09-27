extends Node2D
## One committed sound blade. Visible concave crescent is also the swept hit shape.
signal impact(at: Vector2, killed: bool)
var config: SkimmerConfig
var direction := Vector2.RIGHT
var hit_ids: Array[int] = []
var elapsed := 0.0
var canceled := false
var strike: BellFrameStrike
var polygon := PackedVector2Array()

func _ready() -> void:
	top_level = true
	z_index = 4
	strike = BellFrameStrike.new()
	add_child(strike)
	strike.hit_ids = hit_ids
	strike.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))
	# Stepped pixel crescent, no outline of a future trajectory.
	for point: Vector2 in [Vector2(-5,-12),Vector2(2,-12),Vector2(2,-9),Vector2(7,-9),Vector2(7,-5),Vector2(11,-5),Vector2(11,5),Vector2(7,5),Vector2(7,9),Vector2(2,9),Vector2(2,12),Vector2(-5,12),Vector2(-5,8),Vector2(0,8),Vector2(0,4),Vector2(4,4),Vector2(4,-4),Vector2(0,-4),Vector2(0,-8),Vector2(-5,-8)]:
		polygon.append((point*config.pulse_radius/12.0).rotated(direction.angle()))

func cancel() -> void:
	canceled = true
	strike.stop()
	hide()
	queue_free()

func _physics_process(delta: float) -> void:
	if canceled:
		return
	elapsed += delta
	if elapsed >= config.pulse_lifetime:
		cancel()
		return
	var step := direction*config.pulse_speed*delta
	var sweeps: Array[PackedVector2Array] = []
	for convex: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(polygon):
		var points := convex.duplicate()
		for point: Vector2 in convex:
			points.append(point+step)
		var hull := Geometry2D.convex_hull(points)
		sweeps.append(hull)
		var shape := ConvexPolygonShape2D.new()
		shape.points = hull
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = global_transform
		query.collision_mask = 1
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			cancel()
			return
	for sweep: PackedVector2Array in sweeps:
		strike.strike(sweep,config.damage)
	position += step
	queue_redraw()

func _draw() -> void:
	if canceled or polygon.is_empty():
		return
	draw_colored_polygon(polygon,Color("e8baaa"))
	var edge := polygon.duplicate()
	edge.append(polygon[0])
	draw_polyline(edge,Color("672d4a"),2)
