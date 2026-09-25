extends Node
## Initial authored geometry only. Do not rerun over an edited room.

func _ready() -> void:
	if ResourceLoader.exists("res://features/world/rooms/scriptorium.tscn"):
		push_error("Scriptorium already exists; edit its native scene.")
		get_tree().quit(1)
		return
	var room := (load("res://features/world/rooms/training.tscn") as PackedScene).instantiate() as GameRoom
	room.name = "Scriptorium"
	room.room_id = "scriptorium"
	room.display_name = "04 / THE INK SANCTUM"
	room.bounds.size.x = 1600
	room.get_node("Backdrop").room_width = 1600.0
	room.get_node("Bounds/Right").position.x = 1616
	for group: String in ["Spawns", "Enemies", "Interactions"]:
		for child: Node in room.get_node(group).get_children():
			child.free()
	var terrain := room.get_node("Terrain") as TileMapLayer
	terrain.clear()
	(room.get_node("Details") as TileMapLayer).clear()
	for y: int in range(15,18):
		for x: int in range(50):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
	# Three 64px cover blocks; middle checkpoint has cover on both sides.
	for x: int in [10,11,21,22,25,26]:
		for y: int in [13,14]:
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==13 else 7))
		(room.get_node("Details") as TileMapLayer).set_cell(Vector2i(x,14),0,Vector2i(12,8))
	spawn(room,"entry",Vector2(110,480))
	spawn(room,"checkpoint",Vector2(160,480))
	spawn(room,"rest",Vector2(775,480))
	spawn(room,"east",Vector2(1450,480))
	point(room,"WestDoor","exit",Vector2(48,480),"E / RETURN TO WATCHERS HALL").target_room = "training"
	room.get_node("Interactions/WestDoor").target_spawn = "scribe_return"
	checkpoint(room,"Shrine",Vector2(160,480),"checkpoint")
	point(room,"Lesson","sign",Vector2(245,480),"Violet charge: jump the bolt. Cover blocks ink.")
	checkpoint(room,"Rest",Vector2(775,480),"rest")
	enemy(room,"ScribeSolo","doom_scribe",Vector2(610,480))
	enemy(room,"ArmorMixed","living_armor",Vector2(1100,480))
	room.get_node("Enemies/ArmorMixed").patrol_distance = 45.0
	enemy(room,"ScribeMixed","doom_scribe",Vector2(1370,480))
	point(room,"Seal","reward",Vector2(1470,480),"E / CLAIM THE INK SEAL").stable_id = "scriptorium_cleared"
	var exit := point(room,"EastDoor","exit",Vector2(1540,480),"E / RETURN TO THE ARCHIVE")
	exit.target_room = "ruins"
	exit.target_spawn = "training_return"
	exit.required_flag = "scriptorium_cleared"
	var packed := PackedScene.new()
	var result := packed.pack(room)
	if result == OK:
		result = ResourceSaver.save(packed,"res://features/world/rooms/scriptorium.tscn")
	room.free()
	print("SCRIPTORIUM_CREATED" if result == OK else "SCRIPTORIUM_FAILED")
	get_tree().quit(0 if result == OK else 1)

func spawn(room: Node, id: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = id
	marker.position = at
	room.get_node("Spawns").add_child(marker)
	marker.owner = room

func point(room: Node, id: String, kind: String, at: Vector2, prompt: String) -> WorldInteraction:
	var result := WorldInteraction.new()
	result.name = id
	result.kind = kind
	result.position = at
	result.prompt = prompt
	room.get_node("Interactions").add_child(result)
	result.owner = room
	return result

func checkpoint(room: Node, id: String, at: Vector2, marker: String) -> void:
	var shrine := point(room,id,"checkpoint",at,"E / RECOVER & SAVE")
	shrine.checkpoint_spawn = marker
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.position.y = -20
	sprite.scale = Vector2(0.5,0.5)
	sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	shrine.add_child(sprite)
	sprite.owner = room

func enemy(room: Node, id: String, scene: String, at: Vector2) -> void:
	var instance := (load("res://features/enemies/" + scene + ".tscn") as PackedScene).instantiate() as Node2D
	instance.name = id
	instance.position = at
	room.get_node("Enemies").add_child(instance)
	instance.owner = room
