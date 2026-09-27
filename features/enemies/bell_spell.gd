extends Node2D
## Caster-owned, world-space spells. Hurt/death/room unload cancel them immediately.
signal impact(at: Vector2, killed: bool)
const WAVE_ART := preload("res://assets/characters/invoker_attack2.png")
const PILLAR_ART := preload("res://assets/characters/invoker_attack1.png")
var config: InvokerConfig
var variant := 0
var facing := 1.0
var locked_position := Vector2.ZERO
var hit_ids: Array[int] = []
var warning_seconds := 0.85
var elapsed := 0.0
var released := false
var canceled := false
var polygon := PackedVector2Array()
var strike: BellFrameStrike

func _ready() -> void:
	top_level = true
	z_index = 4
	var caster := get_parent() as Node2D
	global_position = caster.global_position + Vector2(facing*22,-36)
	if variant == 1:
		var ray := PhysicsRayQueryParameters2D.create(locked_position+Vector2(0,-8),locked_position+Vector2(0,96),1)
		var floor_hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if floor_hit.is_empty():
			cancel()
			return
		global_position = floor_hit.position
		warning_seconds = maxf(warning_seconds,config.pillar_warning)
	strike = BellFrameStrike.new()
	add_child(strike)
	strike.hit_ids = hit_ids
	strike.impact.connect(func(at: Vector2, killed: bool) -> void: impact.emit(at,killed))

func cancel() -> void:
	canceled = true
	if is_instance_valid(strike):
		strike.stop()
	hide()
	queue_free()

func _physics_process(delta: float) -> void:
	if canceled:
		return
	elapsed += delta
	released = elapsed >= warning_seconds
	strike.stop()
	polygon = PackedVector2Array()
	if released:
		var age := elapsed-warning_seconds
		if variant == 0:
			if age > config.wave_lifetime:
				cancel()
				return
			var step := facing*config.wave_speed*delta
			# Sweep the solid moving core, with the same one-hit list as caster contact.
			for point: Vector2 in config.curling_shapes[1]:
				var local := (point-Vector2(207,131))*config.wave_scale
				local.x *= facing
				polygon.append(local)
			# Sweep each convex portion, retaining the empty crescent centre.
			for convex: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(polygon):
				var sweep := convex.duplicate()
				for point: Vector2 in convex:
					sweep.append(point+Vector2(step,0))
				var hull := Geometry2D.convex_hull(sweep)
				var shape := ConvexPolygonShape2D.new()
				shape.points = hull
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = shape
				query.transform = global_transform
				query.collision_mask = 1
				if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
					cancel()
					return
			# Resolve hits only after EVERY convex portion has cleared world collision.
			for convex: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(polygon):
				var sweep := convex.duplicate()
				for point: Vector2 in convex:
					sweep.append(point+Vector2(step,0))
				strike.strike(Geometry2D.convex_hull(sweep),config.damage)
			position.x += step
		else:
			if age > config.pillar_active:
				cancel()
				return
			for point: Vector2 in config.rising_shapes[1]:
				var local := (point-Vector2(214,145))*Vector2(config.pillar_half_width/24.0,config.pillar_height/83.0)
				local.x *= facing
				polygon.append(local)
			strike.strike(polygon,config.damage)
	queue_redraw()

func _draw() -> void:
	if canceled:
		return
	if not released:
		# A localized charging seal, never a future trajectory or attack-area outline.
		var charge := clampf(elapsed/warning_seconds,0,1)
		var color := Color("bc89d8").lerp(Color("ebcda1"),charge)
		if variant == 0:
			draw_rect(Rect2(-4,-4,8,8),color)
			draw_rect(Rect2(-8,-1,16,2),color)
		else:
			draw_rect(Rect2(-10,-3,20,3),Color("734c96"))
			for x: int in [-7,0,7]:
				draw_rect(Rect2(x,-5-6*charge,2,4+6*charge),color)
		return
	if polygon.is_empty():
		return
	# Crop only the actual magic from the accepted CC0 source. No placeholder boxes.
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	if variant == 0:
		var size := config.wave_scale
		draw_texture_rect_region(WAVE_ART,Rect2(Vector2(-47,-51)*size,Vector2(80,100)*size),Rect2(1410,80,80,100))
	else:
		var size := Vector2(config.pillar_half_width/24.0,config.pillar_height/83.0)
		draw_texture_rect_region(PILLAR_ART,Rect2(Vector2(-38,-97)*size,Vector2(64,97)*size),Rect2(1176,48,64,97))
