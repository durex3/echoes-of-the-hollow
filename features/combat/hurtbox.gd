class_name Hurtbox
extends Area2D

@export var health: HealthComponent

func hit_position() -> Vector2:
	var shape := get_node_or_null("Shape") as CollisionShape2D
	return shape.global_position if shape else global_position

func receive_hit(amount: int, origin: Vector2) -> bool:
	return health != null and health.take_damage(amount, origin)
