class_name HealthComponent
extends Node

signal changed(current: int, maximum: int)
signal damaged(amount: int, source: Vector2)
signal died
@export var maximum := 5
@export var invulnerability_seconds := 0.0
var current := 0
var invulnerability_left := 0.0

func _ready() -> void:
	current = maximum

func _physics_process(delta: float) -> void:
	invulnerability_left = maxf(0.0, invulnerability_left - delta)

func take_damage(amount: int, source: Vector2) -> bool:
	if current <= 0 or amount <= 0 or invulnerability_left > 0:
		return false
	current = maxi(0, current - amount)
	invulnerability_left = invulnerability_seconds
	changed.emit(current, maximum)
	damaged.emit(amount, source)
	if current == 0:
		died.emit()
	return true

func restore_full() -> void:
	current = maximum
	invulnerability_left = 0.0
	changed.emit(current, maximum)
