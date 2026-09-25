extends "res://tools/build_atrium.gd"
## One-time native arena creation, using only the builder's node-authoring helpers.

func _ready() -> void:
	if ResourceLoader.exists("res://features/world/rooms/heart_chamber.tscn"):
		push_error("Heart chamber exists; edit its native scene.")
		get_tree().quit(1)
		return
	var room := (load("res://features/world/rooms/forest.tscn") as PackedScene).instantiate() as GameRoom
	room.name = "HeartChamber"
	room.room_id = "heart_chamber"
	room.display_name = "09 / HEART CHAMBER"
	room.music_track = "dungeon"
	room.bounds.size.x = 640
	room.get_node("Backdrop").room_width = 640.0
	room.get_node("Backdrop").ruins = true
	room.get_node("Bounds/Right").position.x = 656
	for group: String in ["Spawns","Enemies","Interactions"]:
		for child: Node in room.get_node(group).get_children():
			child.free()
	var landmarks := Node2D.new()
	landmarks.name = "Landmarks"
	landmarks.set_script(load("res://features/world/heart_landmarks.gd"))
	room.add_child(landmarks)
	room.move_child(landmarks,1)
	landmarks.owner = room
	var terrain := room.get_node("Terrain") as TileMapLayer
	terrain.clear()
	(room.get_node("Details") as TileMapLayer).clear()
	for y: int in range(15,18):
		for x: int in range(20):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
	spawn(room,"entry",Vector2(96,480))
	spawn(room,"checkpoint",Vector2(96,480))
	var door := point(room,"Return","exit",Vector2(48,480),"E / RETURN TO THE ANTECHAMBER")
	door.target_room = "atrium"
	door.target_spawn = "boss_return"
	point(room,"Lesson","sign",Vector2(145,480),"Amber: step away. Mint: jump the rush. Strike after.")
	var finale := point(room,"FinalEcho","finale",Vector2(560,480),"E / RESTORE THE FINAL ECHO")
	finale.stable_id = "journey_restored"
	finale.required_flag = "warden_defeated"
	var boss := (load("res://features/enemies/hollow_warden.tscn") as PackedScene).instantiate()
	boss.name = "Warden"
	boss.position = Vector2(448,480)
	room.get_node("Enemies").add_child(boss)
	boss.owner = room
	var packed := PackedScene.new()
	var result := packed.pack(room)
	if result == OK:
		result = ResourceSaver.save(packed,"res://features/world/rooms/heart_chamber.tscn")
	room.free()
	print("HEART_CHAMBER_CREATED" if result == OK else "HEART_CHAMBER_FAILED")
	get_tree().quit(0 if result == OK else 1)
