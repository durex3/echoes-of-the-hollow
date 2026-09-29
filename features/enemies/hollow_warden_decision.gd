class_name HollowWardenDecision
extends RefCounted

func choose_attack(distance: float, airborne: bool, last_attack: int, repeated: int, court_ready: bool) -> int:
	const SWEEP := 0
	const RUSH := 1
	const CHARGED := 2
	if court_ready:
		return CHARGED
	var scores := {SWEEP: 1.0, RUSH: 1.0, CHARGED: 0.75}
	if distance < 52.0:
		scores[SWEEP] += 2.5
	if distance > 180.0:
		scores[RUSH] += 2.5
	if airborne:
		scores[CHARGED] += 2.0
	if last_attack >= 0:
		scores[last_attack] -= 1.5 + repeated
	var best := SWEEP
	var best_score := -INF
	for candidate in [SWEEP, RUSH, CHARGED]:
		if scores[candidate] > best_score:
			best = candidate
			best_score = scores[candidate]
	return best
