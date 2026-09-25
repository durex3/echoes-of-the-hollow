extends Node
## One-time authored room creation. Never overwrites a room edited by hand.

func _ready() -> void:
	if ResourceLoader.exists("res://features/world/rooms/atrium.tscn"):
		push_error("Antechamber exists; edit its native scene.")
		get_tree().quit(1)
		return
	var room := (load("res://features/world/rooms/forest.tscn") as PackedScene).instantiate() as GameRoom
	room.name = "Atrium"
	room.room_id = "atrium"
	room.display_name = "08 / ECHO ANTECHAMBER"
	room.music_track = "dungeon"
	room.bounds.size.x = 960
	room.get_node("Backdrop").room_width = 960.0
	room.get_node("Backdrop").ruins = true
	room.get_node("Bounds/Right").position.x = 976
	for group: String in ["Spawns","Enemies","Interactions"]:
		for child: Node in room.get_node(group).get_children():
			child.free()
	var landmarks := Node2D.new()
	landmarks.name = "Landmarks"
	landmarks.set_script(load("res://features/world/atrium_landmarks.gd"))
	room.add_child(landmarks)
	room.move_child(landmarks,1)
	landmarks.owner = room
	var terrain := room.get_node("Terrain") as TileMapLayer
	terrain.clear()
	(room.get_node("Details") as TileMapLayer).clear()
	for y: int in range(15,18):
		for x: int in range(30):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
	# Previously measured normal jump ~102px. Two 64px rises with 64px gap.
	for x: int in range(13,16):
		terrain.set_cell(Vector2i(x,13),0,Vector2i(1+x%3,6))
	for x: int in range(18,28):
		terrain.set_cell(Vector2i(x,11),0,Vector2i(1+x%3,6))
	spawn(room,"entry",Vector2(110,480))
	spawn(room,"checkpoint",Vector2(240,480))
	var door := point(room,"Return","exit",Vector2(48,480),"E / RETURN TO THE GROVE")
	door.target_room = "forest"
	door.target_spawn = "atrium_return"
	var shrine := point(room,"Shrine","checkpoint",Vector2(240,480),"E / REST & SAVE")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.position.y = -20
	sprite.scale = Vector2(0.5,0.5)
	sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	shrine.add_child(sprite)
	sprite.owner = room
	point(room,"RestHint","sign",Vector2(345,480),"A quiet threshold. Rest here before going onward.")
	point(room,"InnerDoor","sign",Vector2(816,352),"Inner door sealed / The guardian awakens in a future chapter.")
	var packed := PackedScene.new()
	var result := packed.pack(room)
	if result == OK:
		result = ResourceSaver.save(packed,"res://features/world/rooms/atrium.tscn")
	room.free()
	print("ATRIUM_CREATED" if result == OK else "ATRIUM_FAILED")
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
