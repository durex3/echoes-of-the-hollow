class_name SteamConfig
extends Resource
## Read-only tuning. Each vent owns its phase clock.
@export_range(0.5, 10.0) var rest_seconds := 2.4
@export_range(0.5, 5.0) var warning_seconds := 1.0
@export_range(0.2, 5.0) var active_seconds := 1.0
@export_range(1, 3) var damage := 1
@export var plume_size := Vector2(64, 80)
