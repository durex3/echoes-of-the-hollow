class_name SwordCourtConfig
extends Resource
## Immutable timing, art, collision and authored arena coordinates.
@export var summon_seconds := 1.5
@export var summon_frame_seconds := 0.8
@export var summon_stagger := 0.075
@export var lock_seconds := 0.55
@export var royal_lock_seconds := 0.7
@export var pair_stagger := 0.12
@export var round_gap := 0.18
@export var cooldown_seconds := 10.0
@export var ordinary_attacks_between := 2
@export var sword_speed := 360.0
@export var royal_speed := 400.0
@export var turn_speed := 2.2
@export var royal_turn_speed := 1.8
@export var flight_lifetime := 2.2
@export var impact_seconds := 0.18
@export var fade_seconds := 0.3
@export var damage := 1
@export var sword_scale := 0.7142857
@export var royal_scale := 1.4285714
@export var blade_size := Vector2(5, 44)
@export var impact_tip_offset := 22.0
@export var aim_offset := Vector2(0,-22)
@export var crown_positions := PackedVector2Array([Vector2(120,360),Vector2(186,344),Vector2(252,330),Vector2(320,334),Vector2(388,330),Vector2(454,344),Vector2(520,360)])
