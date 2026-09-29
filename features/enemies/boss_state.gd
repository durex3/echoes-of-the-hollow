class_name BossState
extends Node

var host: Node
var machine: BossStateMachine

func setup(next_host: Node, next_machine: BossStateMachine) -> void:
	host = next_host
	machine = next_machine

func enter() -> void:
	pass

func re_enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
