extends Node
## One-time authored blockout builder. Refuses to replace any saved scene.

const OUTPUT := "res://features/world/prototypes/echo_cloister_blockout.tscn"
var scene: Node2D

func _ready() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Blockout exists. Edit the native scene; refusing regeneration.")
		get_tree().quit(1)
		return
	scene = Node2D.new()
	scene.name = "EchoCloisterBlockout"
	scene.set_script(load("res://features/world/prototypes/echo_cloister_blockout.gd"))
	polygon(scene, "Sky", Rect2(0, 0, 1024, 768), Color("586a7e"))
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load("res://features/world/cistern_tileset.tres")
	adopt(terrain, scene)
	for x: int in range(32):
		for y: int in range(22, 24):
			terrain.set_cell(Vector2i(x, y), 0, Vector2i(25 + x % 2, 0 if y == 22 else 2))
	for x: int in range(7, 14):
		terrain.set_cell(Vector2i(x, 8), 0, Vector2i(25 + x % 2, 0))
	wall("LeftEchoWall", Rect2(416, 256, 32, 320), &"cloister_left")
	wall("RightEchoWall", Rect2(576, 128, 32, 576), &"cloister_right")
	wall("LeftBoundary", Rect2(-32, -64, 32, 832))
	wall("RightBoundary", Rect2(1024, -64, 32, 832))
	wall("ReturnGate", Rect2(248, -64, 16, 320))
	var ability := WorldInteraction.new()
	ability.name = "Ability"
	ability.kind = "ability"
	ability.position = Vector2(128, 704)
	adopt(ability, scene)
	var latch := WorldInteraction.new()
	latch.name = "UpperLatch"
	latch.kind = "reward"
	latch.position = Vector2(320, 256)
	adopt(latch, scene)
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as Player
	player.name = "Player"
	player.position = Vector2(96, 704)
	adopt(player, scene)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(1.4, 1.4)
	camera.position = Vector2(70, -105)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1024
	camera.limit_bottom = 768
	adopt(camera, player)
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	adopt(overlay, scene)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(776, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.095, 0.93)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	adopt(panel, overlay)
	var label := Label.new()
	label.name = "Label"
	label.add_theme_font_override("font", load("res://assets/fonts/noto_sans_sc.otf"))
	label.add_theme_font_size_override("font_size", 14)
	adopt(label, panel)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	scene.free()
	print("BLOCKOUT_SAVED: ", error)
	get_tree().quit(0 if error == OK else 1)

func adopt(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = scene

func polygon(parent: Node, name_text: String, rect: Rect2, tint: Color) -> void:
	var art := Polygon2D.new()
	art.name = name_text
	art.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	art.color = tint
	adopt(art, parent)

func wall(name_text: String, rect: Rect2, id: StringName = &"") -> void:
	var body: StaticBody2D = StaticBody2D.new() if id.is_empty() else WallEchoSurface.new()
	body.name = name_text
	if body is WallEchoSurface:
		(body as WallEchoSurface).surface_id = id
	body.position = rect.position
	adopt(body, scene)
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	shape.position = rect.size / 2
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	adopt(shape, body)
	polygon(body, "Art", Rect2(Vector2.ZERO, rect.size), Color("334653") if not id.is_empty() else Color("aa8858"))
	if not id.is_empty():
		for y: int in range(12, int(rect.size.y) - 8, 24):
			polygon(body, "Groove%d" % y, Rect2(7, y, rect.size.x - 14, 4), Color("94e4ce"))
