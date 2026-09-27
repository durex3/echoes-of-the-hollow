extends Node
## One-time authored scene construction. Never overwrites existing rooms.

func _ready() -> void:
	for id: String in ["wind_hall", "belfry"]:
		if FileAccess.file_exists("res://features/world/rooms/" + id + ".tscn"):
			push_error("Wind rooms already exist; edit the native scenes.")
			get_tree().quit(1)
			return
	for id: String in ["wind_hall", "belfry"]:
		var room := (load("res://features/world/rooms/sanctuary.tscn") as PackedScene).instantiate() as GameRoom
		room.name = "WindHall" if id == "wind_hall" else "Belfry"
		room.room_id = id
		room.display_name = "06 / WIND GALLERY" if id == "wind_hall" else "07 / SILENT BELFRY"
		room.music_track = "dungeon"
		var width := 960 if id == "wind_hall" else 1280
		room.bounds.size.x = width
		room.get_node("Backdrop").room_width = float(width)
		room.get_node("Backdrop").ruins = true
		room.get_node("Bounds/Right").position.x = width + 16
		for group: String in ["Spawns", "Enemies", "Interactions"]:
			for child: Node in room.get_node(group).get_children():
				child.free()
		var terrain := room.get_node("Terrain") as TileMapLayer
		terrain.clear()
		(room.get_node("Details") as TileMapLayer).clear()
		for y: int in range(15,18):
			for x: int in range(width/32):
				terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
		spawn(room,"entry",Vector2(110,480))
		spawn(room,"checkpoint",Vector2(165,480))
		spawn(room,"east",Vector2(width-150,480))
		var shrine := point(room,"Shrine","checkpoint",165,"E / SAVE PROGRESS")
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.position.y = -20
		sprite.scale = Vector2(0.5,0.5)
		sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
		sprite.animation = "idle"
		sprite.autoplay = "idle"
		shrine.add_child(sprite)
		sprite.owner = room
		var west := point(room,"WestDoor","exit",48,"E / RETURN TO THE ROOTS" if id == "wind_hall" else "E / RETURN TO WIND GALLERY")
		west.target_room = "sanctuary" if id == "wind_hall" else "wind_hall"
		west.target_spawn = "wind_return" if id == "wind_hall" else "east"
		if id == "wind_hall":
			point(room,"WindEcho","ability",320,"E / CLAIM THE WIND ECHO").stable_id = "dash"
			point(room,"Lesson","sign",510,"K: dash through wind. No invincibility.")
			var gates := Node2D.new()
			gates.name = "Gates"
			room.add_child(gates)
			gates.owner = room
			var gate := (load("res://features/world/wind_gate.tscn") as PackedScene).instantiate()
			gate.position = Vector2(608,480)
			gates.add_child(gate)
			gate.owner = room
			var east := point(room,"EastDoor","exit",880,"E / ENTER THE SILENT BELFRY")
			east.required_flag = "wind_passage_open"
			east.target_room = "belfry"
			east.target_spawn = "entry"
		else:
			point(room,"Lesson","sign",245,"Dash to reposition. Strike after the warning.")
			for x: int in [10,11,25,26]:
				for y: int in [13,14]:
					terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==13 else 7))
			for spec: Array in [["living_armor",650],["doom_scribe",995]]:
				var enemy := (load("res://features/enemies/" + spec[0] + ".tscn") as PackedScene).instantiate()
				enemy.position = Vector2(spec[1],480)
				room.get_node("Enemies").add_child(enemy)
				enemy.owner = room
			point(room,"Beacon","reward",1140,"E / LIGHT THE WIND BEACON").stable_id = "belfry_cleared"
			var exit_point := point(room,"Shortcut","exit",1230,"E / RETURN TO THE GROVE")
			exit_point.required_flag = "belfry_cleared"
			exit_point.target_room = "forest"
			exit_point.target_spawn = "sanctuary_return"
		var packed := PackedScene.new()
		var result := packed.pack(room)
		if result == OK:
			result = ResourceSaver.save(packed,"res://features/world/rooms/" + id + ".tscn")
		room.free()
		if result != OK:
			push_error("Could not create " + id)
			get_tree().quit(1)
			return
	print("WIND_ROOMS_CREATED")
	get_tree().quit()

func spawn(room: Node, id: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = id
	marker.position = at
	room.get_node("Spawns").add_child(marker)
	marker.owner = room

func point(room: Node, id: String, kind: String, x: float, prompt: String) -> WorldInteraction:
	var result := WorldInteraction.new()
	result.name = id
	result.kind = kind
	result.position = Vector2(x,480)
	result.prompt = prompt
	room.get_node("Interactions").add_child(result)
	result.owner = room
	return result
