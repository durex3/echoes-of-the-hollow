class_name SaveRepository
extends RefCounted
## Plain-data persistence. The caller decides when a checkpoint is committed.

const VERSION := 2
const ROOMS := ["forest", "ruins", "training", "scriptorium", "sanctuary", "wind_hall", "belfry", "atrium"]

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != VERSION:
		return false
	if data.get("checkpoint_room") not in ROOMS:
		return false
	var allowed_spawns: Array = ["checkpoint", "rest"] if data.checkpoint_room in ["training", "scriptorium"] else ["checkpoint"]
	if data.get("checkpoint_spawn") not in allowed_spawns:
		return false
	if not data.get("abilities") is Array or not data.get("visited") is Array:
		return false
	if not data.get("completed") is bool:
		return false
	if not data.get("flags") is Array:
		return false
	for flag: Variant in data.flags:
		if flag not in ["training_cleared", "scriptorium_cleared", "heart_bloom", "wind_passage_open", "belfry_cleared"]:
			return false
	for ability: Variant in data.abilities:
		if ability not in ["double_jump", "dash"]:
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
	return migrated

static func _parse(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data
