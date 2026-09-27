class_name WallEcho
extends Node
## Collision-derived wall contact and per-flight use belong to this player instance.

signal jumped(surface_id: StringName)

@export var config: WallEchoConfig = preload("res://features/player/wall_echo_config.tres")
var surface_id: StringName = &""
var last_used_surface: StringName = &""
var normal_x := 0.0
var steering_left := 0.0
var sliding := false
## Presentation state only; these never alter steering, collision or ability budgets.
var pose_left := 0.0
var launch_direction := 1.0
var contact_left := 0.0
var contact_x := 0.0
var arrival_left := 0.0

func advance(delta: float, body: CharacterBody2D, enabled: bool) -> void:
	pose_left = maxf(0,pose_left-delta)
	steering_left = maxf(0.0, steering_left - delta)
	contact_left = maxf(0,contact_left-delta)
	arrival_left = maxf(0,arrival_left-delta)
	sliding = false
	if body.is_on_floor():
		interrupt()
		last_used_surface = &""
	if not enabled:
		interrupt()
		return
	if body.is_on_floor() or not body.is_on_wall():
		if contact_left<=0 or absf(body.global_position.x-contact_x)>24:
			surface_id = &""
			normal_x = 0.0
		return
	for index: int in range(body.get_slide_collision_count()):
		var contact := body.get_slide_collision(index)
		var surface := contact.get_collider() as WallEchoSurface
		if surface != null and absf(contact.get_normal().x) > 0.9:
			surface_id = surface.echo_id()
			normal_x = signf(contact.get_normal().x)
			contact_left = config.contact_grace_seconds
			contact_x = body.global_position.x
			if steering_left>0 and surface_id!=last_used_surface:
				steering_left = 0.0
				arrival_left = config.arrival_pause_seconds
			return
	# Contact with an ordinary wall must never inherit another wall's entitlement.
	surface_id = &""
	normal_x = 0.0
	contact_left = 0.0

func approaching_surface(body: CharacterBody2D) -> bool:
	if body.is_on_floor() or absf(body.velocity.x)<1:
		return false
	var from := body.global_position+Vector2(0,-16)
	var reach := body.velocity.x*config.jump_buffer_seconds+signf(body.velocity.x)*10
	var ray := PhysicsRayQueryParameters2D.create(from,from+Vector2(reach,0),1)
	var result := body.get_world_2d().direct_space_state.intersect_ray(ray)
	if result.is_empty():
		return false
	var surface := result.collider as WallEchoSurface
	return surface!=null and surface.echo_id()!=last_used_surface

func can_jump() -> bool:
	return not surface_id.is_empty() and surface_id != last_used_surface

func launch(body: CharacterBody2D, upward_velocity: float) -> bool:
	if not can_jump():
		return false
	last_used_surface = surface_id
	body.velocity = Vector2(normal_x * config.outward_speed, upward_velocity)
	steering_left = config.steering_lock_seconds
	contact_left = 0.0
	arrival_left = 0.0
	pose_left = config.push_pose_seconds
	launch_direction = normal_x
	jumped.emit(surface_id)
	surface_id = &""
	return true

func limit_slide(body: CharacterBody2D, direction: float) -> void:
	if body.is_on_wall() and not surface_id.is_empty() and (direction * normal_x < 0.0 or arrival_left>0) and body.velocity.y > 0.0:
		body.velocity.y = minf(body.velocity.y, config.slide_speed)
		sliding = true

func interrupt() -> void:
	pose_left = 0.0
	contact_left = 0.0
	arrival_left = 0.0
	# Damage/menu transitions clear contact/control, not the spent wall entitlement.
	surface_id = &""
	normal_x = 0.0
	steering_left = 0.0
	sliding = false

func reset() -> void:
	interrupt()
	last_used_surface = &""
