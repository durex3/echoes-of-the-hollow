class_name RoseConfig
extends Resource
## Immutable tuning for a retreat-and-dash duelist, exclusive to Chapter II.
@export var maximum_health := 3
@export var detection_range := 220.0
@export var approach_speed := 90.0
@export var attack_range := 105.0
@export var retreat_trigger := 72.0
@export var attack_vertical_range := 28.0
@export var leash_distance := 260.0
@export var retreat_speed := 110.0
@export var retreat_seconds := 0.25
@export var warning_seconds := 0.7
@export var strike_seconds := 0.22
@export var strike_speed := 270.0
@export var recovery_seconds := 1.0
@export var hurt_seconds := 0.18
@export var gravity := 1600.0
@export var damage := 1
## The source run sheet places the torso ten pixels ahead of its idle pivot.
@export var stride_sprite_offset := -10.0
