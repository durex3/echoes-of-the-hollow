class_name Hurtbox
extends Area2D

@export var health: HealthComponent
enum HitResult { IGNORED, DAMAGED, BLOCKED }
# Optional defense supplied by the owning character; enemies leave it empty.
var damage_guard: Callable

func hit_position() -> Vector2:
	var shape := get_node_or_null("Shape") as CollisionShape2D
	return shape.global_position if shape else global_position

func receive_hit(amount: int, origin: Vector2) -> bool:
	return resolve_hit(amount, origin) == HitResult.DAMAGED

func resolve_hit(amount: int, origin: Vector2) -> HitResult:
	if health == null or health.current <= 0 or amount <= 0 or health.invulnerability_left > 0:
		return HitResult.IGNORED
	if damage_guard.is_valid() and damage_guard.call():
		return HitResult.BLOCKED
	return HitResult.DAMAGED if health.take_damage(amount, origin) else HitResult.IGNORED
