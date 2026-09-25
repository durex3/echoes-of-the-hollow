class_name AttackProfile
extends Resource
## One timeline drives both collision and animation. Shared profiles are immutable.

enum Phase { WINDUP, ACTIVE, RECOVERY, FINISHED }
@export_range(0.01, 2.0) var windup := 0.08
@export_range(0.01, 2.0) var active_seconds := 0.13
@export_range(0.01, 2.0) var recovery := 0.15
@export var damage := 1

func duration() -> float:
	return windup + active_seconds + recovery

func phase_at(elapsed: float) -> Phase:
	if elapsed < windup:
		return Phase.WINDUP
	if elapsed < windup + active_seconds:
		return Phase.ACTIVE
	if elapsed < duration():
		return Phase.RECOVERY
	return Phase.FINISHED

func phase_progress(elapsed: float) -> float:
	match phase_at(elapsed):
		Phase.WINDUP: return clampf(elapsed / windup, 0, 1)
		Phase.ACTIVE: return clampf((elapsed - windup) / active_seconds, 0, 1)
		_: return clampf((elapsed - windup - active_seconds) / recovery, 0, 1)
