class_name WallEchoConfig
extends Resource
@export var push_pose_seconds := 0.22

@export var outward_speed := 230.0
@export var slide_speed := 80.0
@export_range(0.0, 1.0) var steering_lock_seconds := 0.50
@export var jump_buffer_seconds := 0.18
@export var contact_grace_seconds := 0.14
@export var arrival_pause_seconds := 0.18
