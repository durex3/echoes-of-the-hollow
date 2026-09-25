extends Node
## Native art regression and representative room views; isolated from route acceptance.

func run(h: Node, game: Node) -> void:
	var ids := ["ember_quay","valve_gallery","cistern_archive","furnace_core"]
	var cells := [120,210,124,120]
	var views := [Vector2(460,480),Vector2(760,352),Vector2(720,480),Vector2(660,480)]
	for index: int in range(ids.size()):
		game.load_room(ids[index],"entry")
		game.ui.reward_notice.remaining = 0
		game.ui.set_text(game.ui.toast,"")
		game.player.revive(views[index])
		# Keep the scene view readable; combat is covered by the continuous route.
		for enemy: Node in game.room.get_node("Enemies").get_children():
			enemy.set_physics_process(false)
		await h.frames(35)
		var terrain: TileMapLayer = game.room.get_node("Terrain")
		h.check(terrain.get_used_cells().size() == cells[index], "Art pass preserves %s authored collision footprint" % ids[index])
		var art: Node = game.room.get_node("CastleArt")
		var decorations_safe := true
		for node: Node in art.get_children():
			if node is TileMapLayer:
				decorations_safe = decorations_safe and not node.collision_enabled
			decorations_safe = decorations_safe and not node is CollisionObject2D
		h.check(decorations_safe, "Background masonry and props do not obstruct %s traversal" % ids[index])
		await h.shot("80_" + ids[index] + "_forge_art")
	game.player.health.invulnerability_left = 0
	game.load_room("ember_quay","checkpoint")
	await h.frames(3)
