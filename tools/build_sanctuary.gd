extends Node
## Create a small optional traversal room once; subsequent edits stay native.

func _ready() -> void:
	if ResourceLoader.exists("res://features/world/rooms/sanctuary.tscn"):
		push_error("Sanctuary exists; edit its native scene.")
		get_tree().quit(1)
		return
	var room := (load("res://features/world/rooms/forest.tscn") as PackedScene).instantiate() as GameRoom
	room.name = "Sanctuary"
	room.room_id = "sanctuary"
	room.display_name = "05 / ROOT SANCTUARY"
	room.bounds.size.x = 960
	room.get_node("Backdrop").room_width = 960.0
	room.get_node("Bounds/Right").position.x = 976
	for group: String in ["Spawns","Enemies","Interactions"]:
		for child: Node in room.get_node(group).get_children():
			child.free()
	var terrain := room.get_node("Terrain") as TileMapLayer
	terrain.clear()
	(room.get_node("Details") as TileMapLayer).clear()
	for y: int in range(15,18):
		for x: int in range(30):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,0 if y==15 else 1))
	# Three steps, each 64px higher, with forgiving widths and safe ground below.
	for step: int in range(3):
		var start := 8 + step*6
		var top := 13-step*2
		for x: int in range(start,start+4):
			terrain.set_cell(Vector2i(x,top),0,Vector2i(1+x%3,0))
	spawn(room,"entry",Vector2(110,480))
	spawn(room,"checkpoint",Vector2(165,480))
	var door := point(room,"Return","exit",Vector2(48,480),"E / RETURN TO THE HIGH GROVE")
	door.target_room = "forest"
	door.target_spawn = "sanctuary_return"
	var shrine := point(room,"Shrine","checkpoint",Vector2(165,480),"E / SAVE PROGRESS")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.position.y = -20
	sprite.scale = Vector2(0.5,0.5)
	sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	shrine.add_child(sprite)
	sprite.owner = room
	point(room,"Hint","sign",Vector2(215,480),"Above the roots, a heart still blooms.")
	point(room,"HeartBloom","upgrade",Vector2(705,288),"E / CLAIM HEART BLOOM / +1 MAX VITALITY").stable_id = "heart_bloom"
	var packed := PackedScene.new()
	var result := packed.pack(room)
	if result == OK:
		result = ResourceSaver.save(packed,"res://features/world/rooms/sanctuary.tscn")
	room.free()
	print("SANCTUARY_CREATED" if result == OK else "SANCTUARY_FAILED")
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
