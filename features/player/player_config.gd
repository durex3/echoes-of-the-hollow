class_name PlayerConfig
extends Resource

@export var run_speed := 230.0
@export var acceleration := 2300.0
@export var friction := 2600.0
@export var jump_height := 102.0
@export var time_to_apex := 0.36
@export var fall_multiplier := 1.65
@export var coyote_seconds := 0.10
@export var buffer_seconds := 0.12
@export var dash_speed := 620.0
@export var dash_seconds := 0.18
@export var dash_cooldown := 0.45
@export var attack: AttackProfile = preload("res://features/player/sword_attack.tres")

func gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)

func jump_velocity() -> float:
	return -2.0 * jump_height / time_to_apex
