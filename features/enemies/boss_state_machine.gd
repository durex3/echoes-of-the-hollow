class_name BossStateMachine
extends RefCounted

var current: BossAttackState
var previous: BossAttackState
var host: Node

func setup(next_host: Node) -> void:
	host = next_host

func change(next: BossAttackState) -> void:
	if next == null or next == current:
		return
	if current:
		current.exit()
	previous = current
	current = next
	current.setup(host, self)
	current.enter()

func tick(delta: float) -> void:
	if current:
		current.tick(delta)

func can_decide() -> bool:
	return current == null or current.ready()
