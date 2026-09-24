class_name Hurtbox
extends Area2D

@export var health: HealthComponent

func receive_hit(amount: int, origin: Vector2) -> bool:
	return health != null and health.take_damage(amount, origin)
