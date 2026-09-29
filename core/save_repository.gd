class_name SaveRepository
extends RefCounted
## Plain-data persistence. The caller decides when a checkpoint is committed.

const VERSION := 2
const ROOMS := ["forest", "ruins", "training", "scriptorium", "sanctuary", "wind_hall", "belfry", "atrium", "heart_chamber", "ember_quay", "valve_gallery", "cistern_archive", "furnace_core", "sluice_shaft", "pump_chamber", "echo_vault", "windworn_steps", "bell_guard_walk", "broken_bell_atrium", "echo_cloister", "hanging_gallery", "bell_weight_chamber", "quiet_reliquary", "confluence_bridge", "terminal_platform"]

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != VERSION:
		return false
	if data.get("checkpoint_room") not in ROOMS:
		return false
	var allowed_spawns: Array = ["checkpoint", "rest"] if data.checkpoint_room in ["training", "scriptorium"] else ["checkpoint"]
	if data.checkpoint_room in ["windworn_steps", "bell_guard_walk", "broken_bell_atrium", "echo_cloister", "hanging_gallery", "bell_weight_chamber", "quiet_reliquary", "confluence_bridge", "terminal_platform"]:
		allowed_spawns = ["entry", "checkpoint", "altar", "upper", "return"]
	if data.get("checkpoint_spawn") not in allowed_spawns:
		return false
	if not data.get("abilities") is Array or not data.get("visited") is Array:
		return false
	if not data.get("completed") is bool:
		return false
	if not data.get("flags") is Array:
		return false
	for flag: Variant in data.flags:
		if flag not in ["training_cleared", "scriptorium_cleared", "heart_bloom", "bell_heart", "wind_passage_open", "belfry_cleared", "warden_defeated", "journey_restored", "flow_seal", "pressure_seal", "cistern_restored", "cistern_heart", "furnace_keeper_defeated", "bell_guard_cleared", "bell_weight_cleared", "hanging_gallery_cleared", "confluence_bridge_cleared", "east_weight_restored", "west_weight_restored", "wall_passage_open", "bell_warden_defeated", "bell_court_restored"]:
			return false
	for ability: Variant in data.abilities:
		if ability not in ["double_jump", "dash", "steam_ward", "wall_echo"]:
			return false
	for room: Variant in data.visited:
		if room not in ROOMS:
			return false
	return true

static func read(path: String) -> Dictionary:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Variant = migrate(_parse(candidate))
		if validate(data):
			return data
	return {}

static func write(path: String, data: Dictionary) -> Error:
	if not validate(data):
		return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	# Keep the last valid save; a corrupt primary must never replace a good backup.
	if FileAccess.file_exists(path):
		var previous: Variant = migrate(_parse(path))
		if validate(previous):
			result = DirAccess.copy_absolute(path, path + ".bak")
			if result != OK:
				return result
	return DirAccess.rename_absolute(path + ".tmp", path)

static func migrate(data: Variant) -> Variant:
	if not data is Dictionary:
		return data
	var migrated: Dictionary = data.duplicate(true)
	if migrated.get("version") == 1:
		migrated.version = VERSION
		migrated.flags = []
	# Older third-chapter saves used the restoration flag for the boss victory.
	# Preserve that victory when loading them under the split boss/ending state.
	if migrated is Dictionary and "bell_court_restored" in migrated.get("flags", []) and "bell_warden_defeated" not in migrated.flags:
		migrated.flags.append("bell_warden_defeated")
	# Additive, idempotent upgrade for validated 0.12 saves. The old mark grants ward only.
	if validate(migrated) and "cistern_heart" in migrated.flags and "steam_ward" not in migrated.abilities:
		migrated.abilities.append("steam_ward")
	return migrated

static func _parse(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data
