class_name FurnaceKeeperDecision
extends RefCounted

func choose_attack(distance: float, airborne: bool, attack_count: int, regular_attacks: int, last_attack: int, ready: Dictionary, dash_range: float) -> int:
	# Deterministic opening teaches the five attack families before context takes over.
	if attack_count < 5:
		var lesson: int = [0, 1, 2, 3, 4][attack_count]
		if ready.get(lesson, false):
			return lesson
	# The reference dash follows several ordinary attacks and only starts at
	# mid-range. Its slam is cooldown driven; neither requires a health phase.
	if regular_attacks > 3 and distance >= dash_range * 0.5 and distance <= dash_range and ready.get(0, false):
		return 0
	if distance < 85.0 and ready.get(3, false):
		return 3
	if ready.get(2, false) and attack_count >= 5 and distance >= 120.0:
		return 2
	if airborne and ready.get(4, false) and last_attack != 4:
		return 4
	if distance > 180.0 and ready.get(1, false) and last_attack != 1:
		return 1
	if ready.get(3, false):
		return 3
	if ready.get(1, false):
		return 1
	if ready.get(4, false):
		return 4
	return -1
