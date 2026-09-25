class_name JourneyProgress
extends RefCounted
## Pure guidance derived from existing progress; no second quest save state.

static func objective(abilities: Array[String], flags: Array[String], visited: Array[String]) -> String:
	if "cistern_restored" in flags:
		return "Cistern restored / Both chapters open to explore"
	if "journey_restored" in flags:
		if "ember_quay" not in visited:
			return "Chapter II / Beyond the heart chamber"
		if "flow_seal" not in flags:
			return "Claim the flow seal / Beyond Valve Gallery"
		if "pressure_seal" not in flags:
			return "Claim the pressure seal / Below Cistern Archive"
		return "Two valves ready / Enter the furnace core"
	if "warden_defeated" in flags:
		return "Warden defeated / Restore the final echo"
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
	return "Antechamber reached / Face the Hollow Warden"
