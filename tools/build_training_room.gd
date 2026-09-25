extends Node
## One-shot creation of the new room only. Existing rooms are never rebuilt.

func _ready() -> void:
	if ResourceLoader.exists("res://features/world/rooms/training.tscn"):
		push_error("Training room already exists; edit the scene directly.")
		get_tree().quit(1)
		return
	var source := load("res://features/world/rooms/ruins.tscn") as PackedScene
	var room := source.instantiate() as GameRoom
	room.name = "Training"
	room.room_id = "training"
	room.display_name = "03 / THE WATCHERS HALL"
	var tiles := room.get_node("Terrain") as TileMapLayer
	tiles.clear()
	for y: int in range(15,18):
		for x: int in range(40):
			tiles.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
	# Low observation ledge, reachable before double jump.
	for x: int in range(5,9):
		tiles.set_cell(Vector2i(x,13),0,Vector2i(1+x%3,6))
	for enemy: Node in room.get_node("Enemies").get_children():
		enemy.free()
	for x: float in [490.0,920.0]:
		var armor := (load("res://features/enemies/living_armor.tscn") as PackedScene).instantiate()
		room.get_node("Enemies").add_child(armor)
		armor.owner = room
		armor.position = Vector2(x,480)
		armor.patrol_distance = 45.0
		armor.name = "ArmorSolo" if x < 500 else "ArmorMixed"
	var slime := (load("res://features/enemies/slime.tscn") as PackedScene).instantiate()
	room.get_node("Enemies").add_child(slime)
	slime.owner = room
	slime.position = Vector2(1060,480)
	slime.patrol_distance = 38.0
	slime.name = "SlimeMixed"
	room.get_node("Interactions/Echo").free()
	room.get_node("Interactions/TrainingDoor").free()
	var west := room.get_node("Interactions/WestDoor") as WorldInteraction
	west.target_room = "ruins"
	west.target_spawn = "training_return"
	west.prompt = "E / RETURN TO THE ARCHIVE"
	add_point(room,"Observe","sign",Vector2(220,416),"Watch the amber warning. Step back, then strike.")
	add_point(room,"Rest","checkpoint",Vector2(710,480),"E / RECOVER & SAVE").checkpoint_spawn = "rest"
	var rest_spawn := Marker2D.new()
	rest_spawn.name = "rest"
	rest_spawn.position = Vector2(710,480)
	room.get_node("Spawns").add_child(rest_spawn)
	rest_spawn.owner = room
	var shrine := room.get_node("Interactions/Shrine/Sprite").duplicate()
	room.get_node("Interactions/Rest").add_child(shrine)
	shrine.owner = room
	add_point(room,"Seal","reward",Vector2(1130,480),"E / CLAIM THE HALL SEAL").stable_id = "training_cleared"
	var exit := add_point(room,"Shortcut","exit",Vector2(1220,480),"E / FOREST SHORTCUT")
	exit.target_room = "forest"
	exit.target_spawn = "east"
	exit.required_flag = "training_cleared"
	var packed := PackedScene.new()
	var error := packed.pack(room)
	if error == OK:
		error = ResourceSaver.save(packed,"res://features/world/rooms/training.tscn")
	room.free()
	print("TRAINING_ROOM_CREATED" if error == OK else "ROOM_CREATION_FAILED")
	get_tree().quit(0 if error == OK else 1)

func add_point(room: Node, id: String, kind: String, at: Vector2, prompt: String) -> WorldInteraction:
	var point := WorldInteraction.new()
	point.name = id
	point.kind = kind
	point.position = at
	point.prompt = prompt
	room.get_node("Interactions").add_child(point)
	point.owner = room
	return point
