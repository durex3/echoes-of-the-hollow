class_name BossAttackState
extends BossState
@export var attack_id := 0
@export var name_id := ""
var windup := 0.0
var active := 0.0
var recovery := 0.0
@export var cooldown := 0.0
var cooldown_left := 0.0
var elapsed := 0.0
var running := false

func _init(id := "", windup_seconds := 0.0, active_seconds := 0.0, recovery_seconds := 0.0, cooldown_seconds := 0.0) -> void:
	name_id = id
	windup = windup_seconds
	active = active_seconds
	recovery = recovery_seconds
	cooldown = cooldown_seconds

func ready() -> bool:
	return not running and cooldown_left <= 0.0

func tick_cooldown(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)

func physics_update(delta: float) -> void:
	elapsed += delta

func arm() -> void:
	cooldown_left = cooldown
	elapsed = 0.0

func enter() -> void:
	running = true
	elapsed = 0.0

func exit() -> void:
	running = false
