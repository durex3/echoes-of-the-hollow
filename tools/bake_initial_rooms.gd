extends SceneTree
## One-time map seed, not part of builds. Requires explicit --seed-rooms.

func _initialize() -> void:
	if "--seed-rooms" not in OS.get_cmdline_user_args():
		push_error("This tool overwrites room geometry. Explicit --seed-rooms is required.")
		quit(1)
		return
	for id: String in ["forest", "ruins"]:
		var path := "res://features/world/rooms/%s.tscn" % id
		var scene := load(path) as PackedScene
		var room := scene.instantiate()
		var terrain := room.get_node("Terrain") as TileMapLayer
		var details := room.get_node("Details") as TileMapLayer
		if not terrain.get_used_cells().is_empty():
			push_error("Refusing to overwrite authored terrain: " + id)
			room.free()
			quit(1)
			return
		paint(terrain, Rect2i(0,15,40,3), id == "ruins")
		if id == "forest":
			paint(terrain, Rect2i(8,12,7,2), false)
			paint(terrain, Rect2i(11,7,5,2), false)
			paint(terrain, Rect2i(22,12,4,2), false)
		else:
			paint(terrain, Rect2i(21,13,5,2), true)
			paint(terrain, Rect2i(28,11,5,2), true)
		for x: int in [6,17,26,34]:
			details.set_cell(Vector2i(x,14),0,Vector2i(14,7))
		var packed := PackedScene.new()
		var result := packed.pack(room)
		if result == OK:
			result = ResourceSaver.save(packed, path)
		room.free()
		if result != OK:
			quit(1)
			return
	print("ROOM_BAKE_OK")
	quit()

func paint(layer: TileMapLayer, rect: Rect2i, ruins: bool) -> void:
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			var atlas_y := (6 if ruins else 0) + (0 if y == rect.position.y else 1)
			var atlas_x := 0 if x == rect.position.x else (4 if x == rect.end.x-1 else 1+(x%3))
			layer.set_cell(Vector2i(x,y),0,Vector2i(atlas_x,atlas_y))
