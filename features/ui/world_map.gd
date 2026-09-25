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
	"scriptorium": {"title":"INK SANCTUM", "at":Vector2(375,168)}
}
const LINKS := [["forest","sanctuary"],["sanctuary","wind_hall"],["wind_hall","belfry"],["forest","ruins"],["ruins","training"],["training","scriptorium"]]
var current_room := "forest"
var visited: Array[String] = []
var checkpoint_room := "forest"
var flags: Array[String] = []
var abilities: Array[String] = []

func configure(current: String, explored: Array[String], checkpoint: String, progress: Array[String], unlocked: Array[String]) -> void:
	current_room = current
	visited.assign(explored)
	checkpoint_room = checkpoint
	flags.assign(progress)
	abilities.assign(unlocked)
	queue_redraw()

func revealed(id: String) -> bool:
	if id in visited:
		return true
	if id == "sanctuary":
		return "forest" in visited and "double_jump" in abilities
	for pair: Array in LINKS:
		if id in pair and (pair[0] in visited or pair[1] in visited):
			return true
	return false

func room_label(id: String) -> String:
	return ROOMS[id].title if id in visited else "UNEXPLORED"

func _draw() -> void:
	var scale_factor := minf(size.x / 540.0, size.y / 226.0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_factor)
	var font := get_theme_default_font()
	for pair: Array in LINKS:
		if not revealed(pair[0]) or not revealed(pair[1]):
			continue
		var a: Vector2 = ROOMS[pair[0]].at + Vector2(75,26)
		var b: Vector2 = ROOMS[pair[1]].at + Vector2(75,26)
		draw_line(a,b,Color("526d64"),2)
	if "belfry_cleared" in flags and "belfry" in visited and "forest" in visited:
		draw_polyline(PackedVector2Array([Vector2(450,60),Vector2(450,74),Vector2(90,74),Vector2(90,88)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(90,88),Vector2(86,82),Vector2(94,82)]),Color("94e4ce"))
	if "training_cleared" in flags and "training" in visited and "forest" in visited:
		draw_polyline(PackedVector2Array([Vector2(450,140),Vector2(450,153),Vector2(90,153),Vector2(90,140)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(90,140),Vector2(86,146),Vector2(94,146)]),Color("94e4ce"))
	if "scriptorium_cleared" in flags and "scriptorium" in visited and "ruins" in visited:
		draw_polyline(PackedVector2Array([Vector2(375,194),Vector2(270,194),Vector2(270,140)]),Color("94e4ce"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(270,140),Vector2(266,146),Vector2(274,146)]),Color("94e4ce"))
	for id: String in ROOMS:
		if not revealed(id):
			continue
		var at: Vector2 = ROOMS[id].at
		var tint := Color("94e4ce") if id == current_room else Color("526d64")
		draw_rect(Rect2(at,Vector2(150,52)),Color("10292c") if id in visited else Color("131f28"))
		draw_rect(Rect2(at,Vector2(150,52)),tint,false,2 if id == current_room else 1)
		draw_string(font,at+Vector2(8,19),room_label(id),HORIZONTAL_ALIGNMENT_LEFT,136,12,Color("e9d4a3"))
		var status := "HERE" if id == current_room else ("VISITED" if id in visited else "?")
		if id == checkpoint_room:
			status += " / SAVE"
		if id == "sanctuary" and "heart_bloom" in flags:
			status += " / +HP"
		draw_string(font,at+Vector2(8,39),status,HORIZONTAL_ALIGNMENT_LEFT,136,11,tint)
