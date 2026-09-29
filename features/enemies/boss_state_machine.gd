class_name BossStateMachine
extends Node

var current: BossAttackState
var previous: BossAttackState
var host: Node
var attacks: Array[BossAttackState] = []

func setup(next_host: Node) -> Dictionary:
	host = next_host
	attacks.clear()
	var indexed := {}
	for attack: BossAttackState in get_children():
		attacks.append(attack)
		attack.setup(host, self)
		assert(not indexed.has(attack.attack_id), "Duplicate Boss attack ID")
		indexed[attack.attack_id] = attack
	return indexed

func change(next: BossAttackState) -> void:
	if next == null or next == current:
		return
	if current:
		current.exit()
	previous = current
	current = next
	current.enter()

func tick(delta: float) -> void:
	for attack: BossAttackState in attacks:
		attack.tick_cooldown(delta)
	if current:
		current.physics_update(delta)

func can_decide() -> bool:
	return current == null

func finish() -> void:
	if current:
		current.exit()
		previous = current
		current = null
