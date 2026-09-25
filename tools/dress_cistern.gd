extends Node
## Explicit one-time art migration. Preserves every authored collision cell and actor.
const ROOMS := ["ember_quay", "valve_gallery", "cistern_archive", "furnace_core"]
const ATLAS := preload("res://assets/environment/forest.png")
var masonry: TileSet
var flames: SpriteFrames

func _ready() -> void:
	for id: String in ROOMS:
		var check_room := (load("res://features/world/rooms/%s.tscn" % id) as PackedScene).instantiate()
		var dressed := check_room.has_node("CastleArt")
		check_room.free()
		if dressed:
			push_error("Cistern already dressed. Edit its native scene; do not rerun this migration.")
			get_tree().quit(1)
			return
	make_resources()
	for id: String in ROOMS:
		var path := "res://features/world/rooms/%s.tscn" % id
		var room := (load(path) as PackedScene).instantiate() as GameRoom
		var terrain := room.get_node("Terrain") as TileMapLayer
		var before := terrain.get_used_cells()
		terrain.tile_set = masonry
		# Swap artwork only: all filled world cells retain their full square collision.
		for cell: Vector2i in before:
			var surface := not before.has(cell + Vector2i.UP)
			var art := Vector2i(25 + posmod(cell.x,2),0 if surface else 2 + posmod(cell.y,2))
			if id == "ember_quay" and surface and cell.x >= 7 and cell.x <= 17:
				art = Vector2i(17 + posmod(cell.x,2),6)
			terrain.set_cell(cell,0,art)
		assert(terrain.get_used_cells().size() == before.size())
		for name: String in ["Backdrop", "CisternLandmarks"]:
			var old := room.get_node(name)
			room.remove_child(old)
			old.free()
		var root := Node2D.new()
		root.name = "CastleArt"
		room.add_child(root)
		room.move_child(root,0)
		root.owner = room
		var fill := Polygon2D.new()
		fill.name = "DeepInterior"
		fill.polygon = PackedVector2Array([Vector2(0,0),Vector2(1280,0),Vector2(1280,576),Vector2(0,576)])
		fill.color = Color("0b1920") if id != "furnace_core" else Color("20171d")
		root.add_child(fill)
		fill.owner = room
		var walls := layer(room,root,"MasonryBackground")
		walls.modulate = Color(0.26,0.34,0.38) if id != "furnace_core" else Color(0.36,0.27,0.25)
		for x: int in range(40):
			for y: int in range(4,15):
				walls.set_cell(Vector2i(x,y),0,Vector2i(12+posmod(x,2),8+posmod(y,3)))
		# Ceiling cornice establishes a continuous enclosed architecture.
		for x: int in range(40):
			walls.set_cell(Vector2i(x,4),0,Vector2i(25+posmod(x,2),0))
		match id:
			"ember_quay":
				for x: int in [64,384,704,1024]:
					arch(room,root,Vector2(x,256),Color(0.54,0.68,0.71))
				water(room,root,416,Color(0.28,0.55,0.59,0.60))
				props(room,root,Vector2(242,472))
				props(room,root,Vector2(928,472))
				brazier(room,root,Vector2(560,480))
				brazier(room,root,Vector2(1050,480))
			"valve_gallery":
				for x: int in [96,352,640,928]:
					arch(room,root,Vector2(x,160),Color(0.47,0.58,0.64))
				var beams := layer(room,root,"TimberGalleries")
				beams.modulate = Color(0.6,0.6,0.65)
				for x: int in range(40):
					beams.set_cell(Vector2i(x,9),0,Vector2i(17+posmod(x,2),6))
				water(room,root,512,Color(0.24,0.45,0.50,0.7))
				brazier(room,root,Vector2(552,480))
				brazier(room,root,Vector2(936,352))
			"cistern_archive":
				for x: int in [32,288,576,928]:
					arch(room,root,Vector2(x,224),Color(0.48,0.52,0.62))
				for x: int in [248,536,940]:
					props(room,root,Vector2(x,472))
				brazier(room,root,Vector2(488,480))
				brazier(room,root,Vector2(980,480))
			"furnace_core":
				for x: int in [96,448,800]:
					arch(room,root,Vector2(x,224),Color(0.68,0.47,0.39))
				for x: int in [272,496,720,944,1152]:
					brazier(room,root,Vector2(x,480))
				# Central hearth landmark uses the original five-frame fire bowl at 2x.
				brazier(room,root,Vector2(656,432),2)
				var pedestal := layer(room,root,"HearthPedestal")
				pedestal.modulate = Color(0.5,0.39,0.35)
				for x: int in [19,20,21]:
					for y: int in [13,14]:
						pedestal.set_cell(Vector2i(x,y),0,Vector2i(25+posmod(x,2),2))
				root.move_child(pedestal,root.get_child_count()-2)
		# Native art children are editor-visible and do not affect nearby interactions.
		for point: WorldInteraction in room.get_node("Interactions").get_children():
			if point.kind == "exit":
				var door := Sprite2D.new()
				door.name = "ForgeDoor"
				door.texture = load("res://assets/props/door_and_switch.png")
				door.region_enabled = true
				door.region_rect = Rect2(0,0,32,32)
				door.position = Vector2(0,-32)
				door.scale = Vector2(2,2)
				point.add_child(door)
				door.owner = room
		var packed := PackedScene.new()
		assert(packed.pack(room) == OK)
		assert(ResourceSaver.save(packed,path) == OK)
		print("DRESSED: ",id," preserved collision cells=",before.size())
		room.free()
	get_tree().quit()

func make_resources() -> void:
	masonry = TileSet.new()
	masonry.tile_size = Vector2i(32,32)
	masonry.add_physics_layer()
	masonry.set_physics_layer_collision_layer(0,1)
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(32,32)
	masonry.add_source(source,0)
	for y: int in range(16):
		for x: int in range(32):
			var cell := Vector2i(x,y)
			source.create_tile(cell)
			var data := source.get_tile_data(cell,0)
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	assert(ResourceSaver.save(masonry,"res://features/world/cistern_tileset.tres") == OK)
	flames = SpriteFrames.new()
	flames.rename_animation("default","burn")
	flames.set_animation_speed("burn",8)
	for index: int in range(5):
		var frame := AtlasTexture.new()
		frame.atlas = ATLAS
		frame.region = Rect2(512+index*32,256,32,64)
		flames.add_frame("burn",frame)
	assert(ResourceSaver.save(flames,"res://features/world/brazier_frames.tres") == OK)

func layer(room: Node, parent: Node, id: String) -> TileMapLayer:
	var result := TileMapLayer.new()
	result.name = id
	result.tile_set = masonry
	result.collision_enabled = false
	parent.add_child(result)
	result.owner = room
	return result

func sprite(room: Node, parent: Node, id: String, at: Vector2, region: Rect2, tint: Color, zoom := 1.0) -> Sprite2D:
	var result := Sprite2D.new()
	result.name = id
	result.texture = ATLAS
	result.region_enabled = true
	result.region_rect = region
	result.centered = false
	result.position = at
	result.scale = Vector2.ONE * zoom
	result.modulate = tint
	parent.add_child(result)
	result.owner = room
	return result

func arch(room: Node, parent: Node, at: Vector2, tint: Color) -> void:
	sprite(room,parent,"StoneArch",at,Rect2(0,256,192,224),tint)

func water(room: Node, parent: Node, y: float, tint: Color) -> void:
	for x: int in range(0,1280,128):
		var surface := sprite(room,parent,"Water",Vector2(x,y),Rect2(992,384,32,96),tint)
		surface.scale.x = 4

func brazier(room: Node, parent: Node, at: Vector2, zoom := 1.0) -> void:
	var result := AnimatedSprite2D.new()
	result.name = "Brazier"
	result.sprite_frames = flames
	result.animation = "burn"
	result.autoplay = "burn"
	result.position = at - Vector2(0,32*zoom)
	result.scale = Vector2.ONE * zoom
	parent.add_child(result)
	result.owner = room

func props(room: Node, parent: Node, at: Vector2) -> void:
	var crate := sprite(room,parent,"Crate",at-Vector2(22,36),Rect2(52,28,44,36),Color(0.75,0.8,0.85))
	crate.texture = load("res://assets/props/props_destructible.png")
	var barrel := sprite(room,parent,"Barrel",at+Vector2(24,-28),Rect2(108,36,22,28),Color(0.75,0.8,0.85))
	barrel.texture = crate.texture
