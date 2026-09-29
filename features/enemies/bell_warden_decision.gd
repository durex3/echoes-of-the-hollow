class_name BellWardenDecision
extends RefCounted

const SWEEP := 0
const DASH := 1
const ECHO := 2
const RESONANCE := 3
func choose_attack(distance: float, airborne: bool, regular_attacks: int, dash_ready: bool, sweep_ready: bool, echo_ready := false, resonance_ready := false, standing := false, last_attack := -1) -> int:
	if regular_attacks >= 2 and last_attack != ECHO and echo_ready and standing and distance >= 85.0 and distance <= 250.0:
		return ECHO
	if regular_attacks >= 1 and last_attack != RESONANCE and resonance_ready and standing and distance >= 100.0 and distance <= 250.0:
		return RESONANCE
	if dash_ready and distance >= 130.0 and distance <= 260.0 and (regular_attacks >= 3 or distance > 220.0 or airborne):
		return DASH
	return SWEEP if sweep_ready else -1
