class_name BossAttackState
extends Node

var host: Node
var machine: Variant
var name_id := ""
var windup := 0.0
var active := 0.0
var recovery := 0.0
var cooldown := 0.0
var cooldown_left := 0.0
var elapsed := 0.0

func _init(id := "", windup_seconds := 0.0, active_seconds := 0.0, recovery_seconds := 0.0, cooldown_seconds := 0.0) -> void:
	name_id = id
	windup = windup_seconds
	active = active_seconds
	recovery = recovery_seconds
	cooldown = cooldown_seconds

func ready() -> bool:
	return cooldown_left <= 0.0

func setup(next_host: Node, next_machine: Variant) -> void:
	host = next_host
	machine = next_machine

func tick(delta: float) -> void:
	elapsed += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)

func arm() -> void:
	cooldown_left = cooldown
	elapsed = 0.0

func enter() -> void:
	elapsed = 0.0

func exit() -> void:
	pass
