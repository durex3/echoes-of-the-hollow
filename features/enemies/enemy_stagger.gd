class_name EnemyStagger
extends Node
## Damage is resolved by Health first. This component only limits FSM interruption.
@export var config: EnemyStaggerConfig = preload("res://features/enemies/enemy_stagger_config.tres")
var quiet_left := 0.0

func _physics_process(delta: float) -> void:
	quiet_left = maxf(0,quiet_left-delta)

func register_hit() -> bool:
	var may_interrupt := quiet_left<=0
	quiet_left = config.reset_gap
	return may_interrupt
