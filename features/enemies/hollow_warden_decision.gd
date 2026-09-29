class_name HollowWardenDecision
extends RefCounted

func choose_attack(distance: float, airborne: bool, last_attack: int, repeated: int, court_ready: bool, sweep_ready: bool, rush_ready: bool) -> int:
	const SWEEP := 0
	const RUSH := 1
	const CHARGED := 2
	if court_ready:
		return CHARGED
	var scores := {SWEEP: 1.0 if sweep_ready else -INF, RUSH: 1.0 if rush_ready else -INF}
	if distance < 52.0:
		scores[SWEEP] += 2.5
	if distance > 180.0:
		scores[RUSH] += 2.5
	if airborne:
		scores[RUSH] += 0.5
	if scores.has(last_attack):
		scores[last_attack] -= 1.5 + repeated
	var best := -1
	var best_score := -INF
	for candidate in [SWEEP, RUSH]:
		if scores[candidate] > best_score:
			best = candidate
			best_score = scores[candidate]
	return best
