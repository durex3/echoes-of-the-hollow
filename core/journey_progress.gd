class_name JourneyProgress
extends RefCounted
## Pure guidance derived from existing progress; no second quest save state.

static func objective(abilities: Array[String], flags: Array[String], visited: Array[String]) -> String:
	if "double_jump" not in abilities:
		return "Find the sky echo / Eastern archive"
	if "training_cleared" not in flags:
		return "Claim the Watchers seal / East of the archive"
	if "scriptorium_cleared" not in flags:
		return "Claim the Ink seal / Through Watchers Hall"
	if "dash" not in abilities:
		return "Find the wind echo / Above the grove"
	if "belfry_cleared" not in flags:
		return "Light the wind beacon / Beyond Wind Gallery"
	if "atrium" not in visited:
		return "Three marks gathered / Grove ground-level gate"
	return "Antechamber reached / Rest before the sealed door"
