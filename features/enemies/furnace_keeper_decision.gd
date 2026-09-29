class_name FurnaceKeeperDecision
extends RefCounted

func choose_attack(distance: float, airborne: bool, attack_count: int, last_attack: int, combo_available: bool) -> int:
	# Deterministic opening teaches the five attack families before context takes over.
	if attack_count < 5:
		return [0, 1, 2, 3, 4][attack_count]
	var scores := {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0}
	if distance < 70.0:
		scores[3] += 2.0
		scores[0] += 0.5
	if distance > 220.0:
		scores[0] += 2.0
		scores[1] += 1.0
	if airborne:
		scores[2] += 2.0
		scores[4] += 1.0
	if not combo_available:
		scores[4] = -INF
	if last_attack >= 0:
		scores[last_attack] -= 1.5
	var best := 0
	var best_score := -INF
	for candidate in scores:
		if scores[candidate] > best_score:
			best = candidate
			best_score = scores[candidate]
	return best
