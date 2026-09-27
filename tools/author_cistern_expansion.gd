extends "res://tools/build_atrium.gd"
## One-time hand-specified layout. Refuses to overwrite any existing new room.
const IDS := ["sluice_shaft","pump_chamber","echo_vault"]
const TITLES := ["14 / SLUICE SHAFT","15 / LOWER PUMP","16 / ECHO VAULT"]
const MASONRY := preload("res://features/world/cistern_tileset.tres")
const ATLAS := preload("res://assets/environment/forest.png")

func _ready() -> void:
	for id: String in IDS:
		if FileAccess.file_exists("res://features/world/rooms/%s.tscn" % id):
			push_error("Authored expansion exists; edit native scenes, never regenerate.")
			get_tree().quit(1)
			return
	for i: int in range(IDS.size()):
		var room := make_room(i)
		match i:
			0:
				exit_at(room,"Return",Vector2(48,672),"valve_gallery","shaft_return","E / RETURN TO THE VALVE GALLERY")
				for row: Array in [[10,14,19],[16,20,17],[22,26,15],[28,32,13],[34,40,11]]:
					ledge(room,row[0],row[1],row[2])
				point(room,"ClimbHint","sign",Vector2(270,672),"Follow the upper sluices. The valve opens a path below.")
				actor(room,"winged_chest",Vector2(760,480))
				var seal := point(room,"Seal","reward",Vector2(980,416),"E / CLAIM THE FLOW SEAL")
				seal.stable_id = "flow_seal"
				var cross := exit_at(room,"Crosslink",Vector2(850,672),"cistern_archive","shaft_return","E / TAKE THE ARCHIVE SERVICE PASSAGE")
				cross.required_flag = "flow_seal"
				exit_at(room,"VaultDoor",Vector2(1190,352),"echo_vault","entry","E / EXPLORE THE HIGH ALCOVE")
				spawn(room,"archive_return",Vector2(800,672))
				spawn(room,"vault_return",Vector2(1140,352))
				brazier(room,Vector2(960,416))
				brazier(room,Vector2(1180,352))
			1:
				exit_at(room,"Return",Vector2(48,608),"cistern_archive","pump_return","E / RETURN TO THE CISTERN ARCHIVE")
				ledge(room,12,16,17)
				ledge(room,19,25,15)
				point(room,"Lesson","sign",Vector2(245,608),"Take the dry upper route; return below after opening the valve.")
				vent(room,Vector2(320,608))
				vent(room,Vector2(960,608))
				actor(room,"rose_sentinel",Vector2(720,480))
				actor(room,"winged_chest",Vector2(1090,608))
				var seal := point(room,"Seal","reward",Vector2(1170,608),"E / CLAIM THE PRESSURE SEAL")
				seal.stable_id = "pressure_seal"
				var shortcut := exit_at(room,"Shortcut",Vector2(1240,608),"ember_quay","pump_return","E / OPEN THE QUAY MAINTENANCE ROUTE")
				shortcut.required_flag = "pressure_seal"
				spawn(room,"quay_return",Vector2(1180,608))
				brazier(room,Vector2(640,480))
				brazier(room,Vector2(1200,608))
			2:
				exit_at(room,"Return",Vector2(48,608),"sluice_shaft","vault_return","E / RETURN TO THE SLUICE SHAFT")
				ledge(room,8,12,17)
				ledge(room,14,18,12)
				ledge(room,21,27,10)
				point(room,"Lesson","sign",Vector2(220,608),"An optional high echo. Double jump from the first ledge.")
				var gift := point(room,"Heart","ability",Vector2(755,320),"E / CLAIM THE SLUICE ECHO")
				gift.stable_id = "steam_ward"
				brazier(room,Vector2(690,320))
		var packed := PackedScene.new()
		assert(packed.pack(room) == OK)
		assert(ResourceSaver.save(packed,"res://features/world/rooms/%s.tscn" % IDS[i]) == OK)
		room.free()
	print("CISTERN_EXPANSION_AUTHORED")
	get_tree().quit()

func make_room(index: int) -> GameRoom:
	var room := GameRoom.new()
	room.name = IDS[index].to_pascal_case()
	room.room_id = IDS[index]
	room.display_name = TITLES[index]
	room.music_track = "dungeon"
	var width := 960 if index == 2 else 1280
	var floor_y := 672 if index == 0 else 608
	room.bounds = Rect2(0,0,width,floor_y+96)
	var art := Node2D.new()
	art.name = "CastleArt"
	owned(room,room,art)
	var backdrop := Polygon2D.new()
	backdrop.name = "DeepInterior"
	backdrop.color = Color("101d29") if index != 2 else Color("191d2b")
	backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(width,0),Vector2(width,floor_y+96),Vector2(0,floor_y+96)])
	owned(room,art,backdrop)
	var walls := TileMapLayer.new()
	walls.name = "MasonryBackground"
	walls.tile_set = MASONRY
	walls.collision_enabled = false
	walls.modulate = Color(0.23,0.31,0.39)
	owned(room,art,walls)
	for x: int in range(width/32):
		for y: int in range(3,floor_y/32):
			walls.set_cell(Vector2i(x,y),0,Vector2i(12+x%2,8+y%3))
	for x: int in range(64,width-128,288):
		var arch := Sprite2D.new()
		arch.name = "Arch%d" % x
		arch.texture = ATLAS
		arch.region_enabled = true
		arch.region_rect = Rect2(0,256,192,224)
		arch.centered = false
		arch.position = Vector2(x,192 if index == 0 else 256)
		arch.modulate = Color(0.45,0.55,0.65)
		owned(room,art,arch)
	if index == 1:
		for x: int in range(0,width,128):
			var water := Sprite2D.new()
			water.name = "Water%d" % x
			water.texture = ATLAS
			water.region_enabled = true
			water.region_rect = Rect2(928,384,64,96)
			water.centered = false
			water.scale.x = 2
			water.position = Vector2(x,floor_y-32)
			water.modulate = Color(0.25,0.5,0.6,0.6)
			owned(room,art,water)
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = MASONRY
	owned(room,room,terrain)
	for x: int in range(width/32):
		for y: int in range(floor_y/32,floor_y/32+3):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(25+x%2,0 if y==floor_y/32 else 2+y%2))
	var bounds := StaticBody2D.new()
	bounds.name = "Bounds"
	owned(room,room,bounds)
	for x: int in [-16,width+16]:
		var shape := CollisionShape2D.new()
		shape.name = "Left" if x < 0 else "Right"
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(32,2048)
		shape.shape = rectangle
		shape.position = Vector2(x,0)
		owned(room,bounds,shape)
	for id: String in ["Spawns","Enemies","Interactions","Hazards"]:
		var group := Node2D.new()
		group.name = id
		owned(room,room,group)
	spawn(room,"entry",Vector2(110,floor_y))
	spawn(room,"checkpoint",Vector2(180,floor_y))
	var shrine := point(room,"Shrine","checkpoint",Vector2(180,floor_y),"E / SAVE PROGRESS")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.position.y = -20
	sprite.scale = Vector2(0.5,0.5)
	sprite.sprite_frames = load("res://features/world/checkpoint_frames.tres")
	sprite.animation = "idle"
	sprite.autoplay = "idle"
	owned(room,shrine,sprite)
	return room

func owned(room: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = room

func ledge(room: Node, left: int, right: int, row: int) -> void:
	var terrain: TileMapLayer = room.get_node("Terrain")
	# Thin native shelves leave an actual lower return corridor.
	for x: int in range(left,right):
		terrain.set_cell(Vector2i(x,row),0,Vector2i(25+x%2,0))

func exit_at(room: Node, id: String, at: Vector2, target: String, marker: String, text: String) -> WorldInteraction:
	var door := point(room,id,"exit",at,text)
	door.target_room = target
	door.target_spawn = marker
	var sprite := Sprite2D.new()
	sprite.name = "ForgeDoor"
	sprite.position.y = -32
	sprite.scale = Vector2(2,2)
	sprite.texture = load("res://assets/props/door_and_switch.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0,0,32,32)
	owned(room,door,sprite)
	return door

func actor(room: Node, id: String, at: Vector2) -> void:
	var enemy := (load("res://features/enemies/%s.tscn" % id) as PackedScene).instantiate() as Node2D
	enemy.name = id.to_pascal_case()
	enemy.position = at
	owned(room,room.get_node("Enemies"),enemy)

func vent(room: Node, at: Vector2) -> void:
	var hazard := preload("res://features/world/steam_vent.tscn").instantiate() as SteamVent
	hazard.name = "Steam%d" % int(at.x)
	hazard.position = at
	owned(room,room.get_node("Hazards"),hazard)

func brazier(room: Node, at: Vector2) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Brazier%d" % int(at.x)
	sprite.position = at-Vector2(0,32)
	sprite.sprite_frames = load("res://features/world/brazier_frames.tres")
	sprite.animation = "burn"
	sprite.autoplay = "burn"
	owned(room,room.get_node("CastleArt"),sprite)
