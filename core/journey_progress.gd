class_name JourneyProgress
extends RefCounted
## Pure guidance derived from existing progress; no second quest save state.

static func objective(abilities: Array[String], flags: Array[String], visited: Array[String]) -> String:
	if "cistern_restored" in flags and "furnace_keeper_defeated" in flags and "bell_court_restored" not in flags:
		if "wall_echo" not in abilities:
			return "Learn the wall echo in Echo Cloister"
		if "east_weight_restored" not in flags or "west_weight_restored" not in flags:
			return "Restore both bell weights / Return to the upper atrium"
		if "bell_court_restored" not in flags:
			return "Cross the Confluence Bridge / Face the Bell Warden"
	if "bell_court_restored" in flags:
		return "Bell Court restored / Explore all three chapters"
	if "cistern_restored" in flags:
		if "furnace_keeper_defeated" not in flags:
			return "Cistern restored / Face the Furnace Keeper"
		return "Cistern restored / Both chapters open to explore"
	if "furnace_keeper_defeated" in flags:
		return "Keeper defeated / Enter the right-hand door"
	if "journey_restored" in flags:
		if "ember_quay" not in visited:
			return "Chapter II / Beyond the heart chamber"
		if "flow_seal" not in flags:
			return "Claim the flow seal / Beyond Valve Gallery"
		if "pressure_seal" not in flags:
			return "Claim the pressure seal / Below Cistern Archive"
		return "Two valves ready / Return to Ember Quay, take the rightmost gold door"
	if "warden_defeated" in flags:
		return "Warden defeated / Enter the central door"
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
