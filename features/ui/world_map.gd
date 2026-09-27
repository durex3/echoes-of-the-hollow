class_name WorldMap
extends Control
## Schematic room graph; diagram coordinates are independent of world geometry.
const ROOMS := {
	"sanctuary": {"title":"ROOT SANCTUARY", "at":Vector2(15,8)},
	"wind_hall": {"title":"WIND GALLERY", "at":Vector2(195,8)},
	"belfry": {"title":"SILENT BELFRY", "at":Vector2(375,8)},
	"forest": {"title":"FORGOTTEN GROVE", "at":Vector2(15,88)},
	"ruins": {"title":"THE ARCHIVE", "at":Vector2(195,88)},
	"training": {"title":"WATCHERS HALL", "at":Vector2(375,88)},
	"scriptorium": {"title":"INK SANCTUM", "at":Vector2(375,168)},
	"atrium": {"title":"ECHO ANTECHAMBER", "at":Vector2(15,168)},
	"heart_chamber": {"title":"HEART CHAMBER", "at":Vector2(195,168)}
}
const LINKS := [["forest","sanctuary"],["sanctuary","wind_hall"],["wind_hall","belfry"],["forest","ruins"],["ruins","training"],["training","scriptorium"],["forest","atrium"],["atrium","heart_chamber"]]
const CHAPTER_TWO := {
	"heart_chamber": {"title":"HEART CHAMBER", "at":Vector2(15,88)},
	"ember_quay": {"title":"EMBER QUAY", "at":Vector2(195,88)},
	"valve_gallery": {"title":"VALVE GALLERY", "at":Vector2(15,8)},
	"sluice_shaft": {"title":"SLUICE SHAFT", "at":Vector2(195,8)},
	"echo_vault": {"title":"ECHO VAULT", "at":Vector2(375,8)},
	"cistern_archive": {"title":"CISTERN ARCHIVE", "at":Vector2(375,88)},
	"pump_chamber": {"title":"LOWER PUMP", "at":Vector2(375,168)},
	"furnace_core": {"title":"FURNACE CORE", "at":Vector2(195,168)}
}
const SECOND_LINKS := [["heart_chamber","ember_quay"],["ember_quay","valve_gallery"],["ember_quay","cistern_archive"],["ember_quay","furnace_core"],["valve_gallery","sluice_shaft"],["sluice_shaft","echo_vault"],["cistern_archive","pump_chamber"],["sluice_shaft","cistern_archive"],["ember_quay","pump_chamber"]]
var chapter := 1
var current_room := "forest"
var door_target := ""
var visited: Array[String] = []
var checkpoint_room := "forest"
var flags: Array[String] = []
var abilities: Array[String] = []

func configure(current: String, explored: Array[String], checkpoint: String, progress: Array[String], unlocked: Array[String]) -> void:
	current_room = current
	chapter = 2 if current in CHAPTER_TWO and current != "heart_chamber" else 1
	visited.assign(explored)
	checkpoint_room = checkpoint
	flags.assign(progress)
	abilities.assign(unlocked)
	queue_redraw()

func revealed(id: String) -> bool:
	if id in visited:
		return true
	if id == "furnace_core" and "ember_quay" in visited and "flow_seal" in flags and "pressure_seal" in flags:
		return true
	if id == door_target:
		return true
	if id == "sanctuary":
		return "forest" in visited and "double_jump" in abilities
	if id in CHAPTER_TWO and id != "heart_chamber" and "journey_restored" not in flags:
		return false
	for pair: Array in LINKS + SECOND_LINKS:
		if id in pair and (pair[0] in visited or pair[1] in visited):
			return true
	return false

func room_label(id: String) -> String:
	return TextCatalog.room_name(id) if id in visited or id == door_target or id == "furnace_core" and revealed(id) else TextCatalog.text("UNEXPLORED")

func mark_summary() -> String:
	var parts: Array[String] = []
	var marks := [["training_cleared", "Watchers seal"], ["scriptorium_cleared", "Ink seal"], ["belfry_cleared", "Wind beacon"]] if chapter == 1 else [["flow_seal", "Flow seal"], ["pressure_seal", "Pressure seal"], ["cistern_restored", "Cistern core"]]
	for item: Array in marks:
		parts.append(("[+] " if item[0] in flags else "[ ] ") + TextCatalog.text(item[1]))
	return "   ".join(parts)

func target_room() -> String:
	if "cistern_restored" in flags:
		return ""
	if "journey_restored" in flags:
		if "ember_quay" not in visited:
			return "heart_chamber"
		if "flow_seal" not in flags:
			return "sluice_shaft" if "valve_gallery" in visited else "valve_gallery"
		if "pressure_seal" not in flags:
			return "pump_chamber" if "cistern_archive" in visited else "cistern_archive"
		return "furnace_core"
	if "warden_defeated" in flags:
		return "heart_chamber"
	if "double_jump" not in abilities:
		return "ruins"
	if "training_cleared" not in flags:
		return "training"
	if "scriptorium_cleared" not in flags:
		return "scriptorium"
	if "dash" not in abilities:
		return "wind_hall"
	if "belfry_cleared" not in flags:
		return "belfry"
	return "forest" if "atrium" not in visited else "heart_chamber"

func gate_requirement(a: String, b: String) -> String:
	# Requirements are only shown for exits whose source room is known.
	if a not in visited:
		return ""
	if a == "sluice_shaft" and b == "cistern_archive" and "flow_seal" not in flags:
		return "Flow seal"
	if a == "ember_quay" and b == "pump_chamber" and "pressure_seal" not in flags:
		return "Pressure seal"
	if b == "ember_quay" and "journey_restored" not in flags:
		return "Final echo"
	if b == "furnace_core" and ("flow_seal" not in flags or "pressure_seal" not in flags):
		return "Two valve seals"
	if b == "sanctuary" and "double_jump" not in abilities:
		return "Double jump"
	if b == "scriptorium" and "training_cleared" not in flags:
		return "Watchers seal"
	if b == "belfry" and "wind_passage_open" not in flags:
		return "Wind dash"
	if b == "atrium":
		for mark: String in ["training_cleared", "scriptorium_cleared", "belfry_cleared"]:
			if mark not in flags:
				return "Three marks"
	return ""

func _draw() -> void:
	var rooms := ROOMS if chapter == 1 else CHAPTER_TWO
	var links := LINKS if chapter == 1 else SECOND_LINKS
	var scale_factor := minf(size.x / 540.0, size.y / 242.0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	var font := get_theme_default_font()
	for pair: Array in links:
		if not revealed(pair[0]) or not revealed(pair[1]):
			continue
		var a: Vector2 = rooms[pair[0]].at + Vector2(75,26)
		var b: Vector2 = rooms[pair[1]].at + Vector2(75,26)
		var selected := current_room in pair and door_target in pair
		var boss_route: bool = chapter == 2 and pair[0] == "ember_quay" and pair[1] == "furnace_core" and target_room() == "furnace_core"
		draw_line(a,b,Color("efce8e") if selected or boss_route else Color("526d64"),3 if selected or boss_route else 2)
		var requirement := gate_requirement(pair[0], pair[1])
		if not requirement.is_empty():
			var center := (a + b) / 2.0
			draw_rect(Rect2(center - Vector2(4,4), Vector2(8,8)), Color("efce8e"))
	if chapter == 1 and "belfry_cleared" in flags and "belfry" in visited and "forest" in visited:
		draw_polyline(PackedVector2Array([Vector2(450,60),Vector2(450,74),Vector2(90,74),Vector2(90,88)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(90,88),Vector2(86,82),Vector2(94,82)]),Color("94e4ce"))
	if chapter == 1 and "training_cleared" in flags and "training" in visited and "forest" in visited:
		draw_polyline(PackedVector2Array([Vector2(450,140),Vector2(450,153),Vector2(90,153),Vector2(90,140)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(90,140),Vector2(86,146),Vector2(94,146)]),Color("94e4ce"))
	if chapter == 1 and "scriptorium_cleared" in flags and "scriptorium" in visited and "ruins" in visited:
		draw_polyline(PackedVector2Array([Vector2(375,194),Vector2(360,194),Vector2(360,148),Vector2(270,148),Vector2(270,140)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(270,140),Vector2(266,146),Vector2(274,146)]),Color("94e4ce"))
	for id: String in rooms:
		if not revealed(id):
			continue
		var at: Vector2 = rooms[id].at
		var tint := Color("efce8e") if id == door_target or id == "furnace_core" and id == target_room() else Color("94e4ce") if id == current_room or id == target_room() else Color("526d64")
		draw_rect(Rect2(at,Vector2(150,52)),Color("10292c") if id in visited else Color("131f28"))
		draw_rect(Rect2(at,Vector2(150,52)),tint,false,2 if id == current_room else 1)
		_draw_label(font, at+Vector2(8,19), room_label(id), 136, 12, Color("e9d4a3"), scale_factor)
		var status := TextCatalog.text("DOOR" if id == door_target else "HERE" if id == current_room else "BOSS" if id == "furnace_core" and id == target_room() else ("VISITED" if id in visited else "?"))
		if id == checkpoint_room:
			status += " / " + TextCatalog.text("SAVE")
		if id == "sanctuary" and "heart_bloom" in flags:
			status += " / " + TextCatalog.text("+HP")
		if id == target_room():
			status = TextCatalog.text("NEXT") + " / " + status
		_draw_label(font, at+Vector2(8,39), status, 136, 11, Color("94e4ce") if id == current_room or id == target_room() else Color("a4b9b2"), scale_factor)
	# Compact legend gives actionable known requirements without naming hidden rooms.
	var locked: Array[String] = []
	for pair: Array in links:
		var requirement := gate_requirement(pair[0], pair[1])
		if not requirement.is_empty() and revealed(pair[1]):
			locked.append(TextCatalog.text(requirement))
	if not locked.is_empty():
		_draw_label(font, Vector2(15,238), TextCatalog.text("Locked: ") + " / ".join(locked), 520, 12, Color("efce8e"), scale_factor)

func _draw_label(font: Font, at: Vector2, value: String, width: float, font_size: int, tint: Color, factor: float) -> void:
	# Geometry scales, text uses integer pixels to keep CJK strokes readable.
	draw_set_transform(Vector2.ZERO)
	draw_string(font, (at * factor).round(), value, HORIZONTAL_ALIGNMENT_LEFT, width * factor, font_size, tint)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
