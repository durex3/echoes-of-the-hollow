class_name WardenConfig
extends Resource

@export var maximum_health := 14
@export var chase_speed := 120.0
@export var attack_range := 82.0
@export var activation_x := 205.0
@export var intro_seconds := 1.2
@export var sweep: AttackProfile
@export var rush: AttackProfile
@export var charged: AttackProfile
@export var rush_speed := 380.0
@export var attack_gap_seconds := 0.08
@export var stuck_escape_seconds := 0.28
@export var court: SwordCourtConfig = preload("res://features/combat/sword_court_config.tres")

@export_group("Retired King's Echo asset preview")
@export var echo_delay := 0.72
@export var echo_active_seconds := 0.22
@export var echo_fade_seconds := 0.18
@export var echo_width := 120.0
@export var echo_height := 48.0
@export var echo_offset := 30.0
@export var echo_damage := 1
@export var echo_step_speed := 100.0
@export var echo_cooldown := 7.0
