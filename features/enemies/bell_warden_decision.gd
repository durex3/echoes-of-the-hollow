class_name BellWardenDecision
extends RefCounted

const SWEEP := 0
const DASH := 1
const DROP := 4

func choose_attack(distance: float, airborne: bool, health: int, maximum_health: int, regular_attacks: int, dash_ready: bool, finisher_used: bool) -> int:
	# The Chapter III finisher is intentionally reserved for a later design pass.
	if dash_ready and (regular_attacks >= 3 or distance > 220.0 or airborne):
		return DASH
	return SWEEP
