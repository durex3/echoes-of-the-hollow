class_name InvokerConfig
extends Resource

@export var maximum_health := 4
@export var sprite_scale := 1.0
@export var damage := 1
@export var move_speed := 65.0
@export var gravity := 1300.0
@export var detection_range := 220.0
@export var cast_distance := 76.0
## The rising arc has an inner gap; curling's final sweep covers sword distance.
@export var rising_minimum := 52.0
@export var ranged_minimum := 110.0
@export var ranged_cooldown := 3.8
@export var preferred_distance := 148.0
@export var retreat_trigger := 88.0
@export var retreat_speed := 105.0
@export var retreat_seconds := 0.42
@export var retreat_cooldown := 3.0
@export var stationary_speed := 40.0
@export var search_seconds := 0.65
@export var leash_distance := 240.0
@export var wave_speed := 180.0
@export var wave_scale := 5.0/7.0
@export var wave_lifetime := 1.65
@export var pillar_warning := 1.05
@export var pillar_active := 0.38
@export var pillar_height := 83.0*5.0/7.0
@export var pillar_half_width := 24.0*5.0/7.0
@export var hit_flash_seconds := 0.10
@export var rising_warning := 0.85
@export var rising_active := 0.32
@export var rising_recovery := 1.10
@export var curling_warning := 1.05
@export var curling_active := 0.30
@export var curling_recovery := 1.25
@export var hurt_seconds := 0.18
@export var death_seconds := 0.8
## Conservative solid effect polygons in the original 250px source frame.
## Transparent canvas, decorative staff and scattered fading pixels are excluded.
@export var rising_shapes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(183,127),Vector2(204,108),Vector2(218,100),Vector2(210,123),Vector2(190,143)]),
	PackedVector2Array([Vector2(205,62),Vector2(225,64),Vector2(231,100),Vector2(209,137),Vector2(190,143),Vector2(209,103)]),
	PackedVector2Array([Vector2(216,69),Vector2(225,79),Vector2(224,99),Vector2(218,111),Vector2(219,91)]),
	# Frame 6 is disconnected dissipating wisps, so it has no attack polygon.
	PackedVector2Array()
]
@export var curling_shapes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(180,58),Vector2(218,76),Vector2(235,112),Vector2(229,139),Vector2(211,138),Vector2(208,104)]),
	PackedVector2Array([Vector2(219,87),Vector2(230,105),Vector2(220,147),Vector2(192,171),Vector2(178,163),Vector2(201,131)]),
	PackedVector2Array([Vector2(164,147),Vector2(186,160),Vector2(219,148),Vector2(212,163),Vector2(181,177),Vector2(160,164)])
]
