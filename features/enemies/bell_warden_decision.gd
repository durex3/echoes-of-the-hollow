class_name BellWardenDecision
extends RefCounted

const SWEEP := 0
const DASH := 1
func choose_attack(distance: float, airborne: bool, regular_attacks: int, dash_ready: bool, sweep_ready: bool) -> int:
	if dash_ready and distance >= 130.0 and distance <= 260.0 and (regular_attacks >= 3 or distance > 220.0 or airborne):
		return DASH
	return SWEEP if sweep_ready else -1
