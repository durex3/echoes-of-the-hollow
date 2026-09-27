extends "res://tools/build_atrium.gd"
## One-time, explicit room authoring. Existing scenes are never regenerated.
const IDS := ["ember_quay", "valve_gallery", "cistern_archive", "furnace_core"]
const TITLES := ["10 / EMBER QUAY", "11 / VALVE GALLERY", "12 / CISTERN ARCHIVE", "13 / FURNACE CORE"]

func _ready() -> void:
	for id: String in IDS:
		if ResourceLoader.exists("res://features/world/rooms/%s.tscn" % id):
			push_error("Chapter room exists; edit native scenes instead of regenerating.")
			get_tree().quit(1)
			return
	for index: int in range(IDS.size()):
		var room := make_room(IDS[index], TITLES[index])
		match index:
			0:
				door(room,"Return",48,"heart_chamber","chapter_return","E / RETURN TO THE HEART CHAMBER")
				shrine(room,180)
				point(room,"Lesson","sign",Vector2(300,480),"Steam: amber warns, white burns. Cross on green.")
				vent(room,Vector2(440,480))
				door(room,"FlowDoor",650,"valve_gallery","entry","E / ENTER THE VALVE GALLERY")
				door(room,"PressureDoor",820,"cistern_archive","entry","E / ENTER THE CISTERN ARCHIVE")
				point(room,"RouteHint","sign",Vector2(980,480),"Two branches, two valve seals. Return here to open the core.")
				var gate := door(room,"CoreDoor",1160,"furnace_core","entry","E / ENTER THE FURNACE CORE")
				gate.required_flags.assign(["flow_seal","pressure_seal"])
				gate.missing_flag_prompts.assign(["Missing flow seal / Explore Valve Gallery", "Missing pressure seal / Explore Cistern Archive"])
				spawn(room,"flow_return",Vector2(650,480))
				spawn(room,"pressure_return",Vector2(820,480))
				spawn(room,"core_return",Vector2(1090,480))
			1:
				door(room,"Return",48,"ember_quay","flow_return","E / RETURN TO EMBER QUAY")
				shrine(room,180)
				vent(room,Vector2(320,480))
				platform(room,13,16,13)
				platform(room,19,36,11)
				vent(room,Vector2(800,352))
				enemy(room,"slime",Vector2(990,352))
				point(room,"ClimbHint","sign",Vector2(460,416),"Climb the dry ledges. Wait for the steam to settle.")
				var seal := point(room,"Seal","reward",Vector2(1100,352),"E / CLAIM THE FLOW SEAL")
				seal.stable_id = "flow_seal"
				var shortcut := door(room,"Shortcut",1200,"ember_quay","flow_return","E / RETURN TO EMBER QUAY")
				shortcut.position.y = 352
				platform(room,36,40,11)
				shortcut.required_flag = "flow_seal"
			2:
				door(room,"Return",48,"ember_quay","pressure_return","E / RETURN TO EMBER QUAY")
				shrine(room,180)
				vent(room,Vector2(400,480))
				enemy(room,"living_armor",Vector2(660,480))
				platform(room,26,28,13)
				enemy(room,"doom_scribe",Vector2(1060,480))
				point(room,"CoverHint","sign",Vector2(770,480),"Dry stone blocks ink. Fight away from the steam.")
				var seal := point(room,"Seal","reward",Vector2(1160,480),"E / CLAIM THE PRESSURE SEAL")
				seal.stable_id = "pressure_seal"
				var shortcut := door(room,"Shortcut",1240,"ember_quay","pressure_return","E / RETURN TO EMBER QUAY")
				shortcut.required_flag = "pressure_seal"
			3:
				door(room,"Return",48,"ember_quay","core_return","E / RETURN TO EMBER QUAY")
				point(room,"Lesson","sign",Vector2(200,480),"Draw guardians onto dry ground. Restore the core after battle.")
				vent(room,Vector2(384,480))
				vent(room,Vector2(832,480))
				enemy(room,"living_armor",Vector2(590,480))
				enemy(room,"doom_scribe",Vector2(1080,480))
				var finale := point(room,"CoreEcho","chapter_end",Vector2(1200,480),"E / RESTORE THE CISTERN CORE")
				finale.stable_id = "cistern_restored"
		var packed := PackedScene.new()
		var result := packed.pack(room)
		if result == OK:
			result = ResourceSaver.save(packed,"res://features/world/rooms/%s.tscn" % IDS[index])
		room.free()
		if result != OK:
			push_error("Cannot save authored chapter room")
			get_tree().quit(1)
			return
	print("CHAPTER_TWO_CREATED")
	get_tree().quit()

func make_room(id: String, title: String) -> GameRoom:
	var room := (load("res://features/world/rooms/forest.tscn") as PackedScene).instantiate() as GameRoom
	room.name = id.to_pascal_case()
	room.room_id = id
	room.display_name = title
	room.music_track = "dungeon"
	room.bounds.size.x = 1280
	room.get_node("Backdrop").ruins = true
	for group: String in ["Spawns", "Enemies", "Interactions"]:
		for child: Node in room.get_node(group).get_children():
			child.free()
	var terrain := room.get_node("Terrain") as TileMapLayer
	terrain.clear()
	(room.get_node("Details") as TileMapLayer).clear()
	for y: int in range(15,18):
		for x: int in range(40):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==15 else 7))
	var landmarks := Node2D.new()
	landmarks.name = "CisternLandmarks"
	landmarks.set_script(load("res://features/world/cistern_landmarks.gd"))
	room.add_child(landmarks)
	room.move_child(landmarks,1)
	landmarks.owner = room
	var hazards := Node2D.new()
	hazards.name = "Hazards"
	room.add_child(hazards)
	hazards.owner = room
	spawn(room,"entry",Vector2(100,480))
	spawn(room,"checkpoint",Vector2(180,480))
	return room

func door(room: Node, id: String, x: float, target: String, marker: String, prompt: String) -> WorldInteraction:
	var result := point(room,id,"exit",Vector2(x,480),prompt)
	result.target_room = target
	result.target_spawn = marker
	return result

func shrine(room: Node, x: float) -> void:
	var result := point(room,"Shrine","checkpoint",Vector2(x,480),"E / SAVE PROGRESS")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.position.y = -20
	sprite.scale = Vector2(0.5,0.5)
	sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	result.add_child(sprite)
	sprite.owner = room

func platform(room: Node, left: int, right: int, row: int) -> void:
	var terrain := room.get_node("Terrain") as TileMapLayer
	for x: int in range(left,right):
		for y: int in range(row,15):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(1+x%3,6 if y==row else 7))

func enemy(room: Node, type: String, at: Vector2) -> void:
	var actor := (load("res://features/enemies/%s.tscn" % type) as PackedScene).instantiate() as Node2D
	actor.name = type.to_pascal_case()
	actor.position = at
	room.get_node("Enemies").add_child(actor)
	actor.owner = room

func vent(room: Node, at: Vector2) -> void:
	var actor := (load("res://features/world/steam_vent.tscn") as PackedScene).instantiate() as SteamVent
	actor.position = at
	room.get_node("Hazards").add_child(actor)
	actor.owner = room
