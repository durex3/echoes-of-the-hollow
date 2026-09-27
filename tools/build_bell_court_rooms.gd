extends Node
## One-time authored layout, not procedural runtime generation.
## Refuses all writes if any output already exists; edit saved rooms in Godot.
const IDS := ["windworn_steps","bell_guard_walk","broken_bell_atrium","echo_cloister","hanging_gallery"]
var scene: GameRoom
var terrain: TileMapLayer

func _ready() -> void:
	for id: String in IDS:
		if FileAccess.file_exists("res://features/world/rooms/%s.tscn" % id):
			push_error("Room exists; refusing to overwrite any authored room: " + id)
			get_tree().quit(1)
			return
	entry()
	guard_walk()
	atrium()
	cloister()
	gallery()
	print("BELL_ROOMS_SAVED: five native rooms")
	get_tree().quit()

func adopt(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = scene

func start(id: String, title: String, width: int, height := 768) -> void:
	scene = GameRoom.new()
	scene.name = id.to_pascal_case()
	scene.room_id = id
	scene.display_name = title
	scene.bounds = Rect2(0,0,width,height)
	var backdrop := Node2D.new()
	backdrop.name = "Sky"
	backdrop.z_index = -20
	backdrop.set_script(load("res://features/world/bell_court_landmarks.gd"))
	backdrop.set("room_width",float(width))
	backdrop.set("room_height",float(height))
	backdrop.set("courtyard",id == "broken_bell_atrium")
	backdrop.set("theme",{"windworn_steps":"entry","bell_guard_walk":"guard","broken_bell_atrium":"hub","echo_cloister":"cloister","hanging_gallery":"gallery"}[id])
	adopt(backdrop,scene)
	terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load("res://features/world/cistern_tileset.tres")
	adopt(terrain,scene)
	for name_text: String in ["Spawns","Interactions","Enemies","Hazards","Decor"]:
		var folder := Node2D.new()
		folder.name = name_text
		if name_text == "Decor":
			folder.z_index = -2
		adopt(folder,scene)
	wall("WestBoundary",Rect2(-32,-64,32,height+128))
	wall("EastBoundary",Rect2(width,-64,32,height+128))
	fill(Rect2i(0,height-64,width,64))

func finish() -> void:
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed,"res://features/world/rooms/%s.tscn" % scene.room_id)
	assert(result == OK,"Failed room save")
	scene.free()

func fill(rect: Rect2i) -> void:
	for x: int in range(rect.position.x/32,rect.end.x/32):
		for y: int in range(rect.position.y/32,rect.end.y/32):
			terrain.set_cell(Vector2i(x,y),0,Vector2i(25+x%2,0 if y == rect.position.y/32 else 2))

func mark(id: String, at: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = id
	marker.position = at
	adopt(marker,scene.get_node("Spawns"))

func point(id: String, at: Vector2, kind: String, label: String) -> WorldInteraction:
	var interaction := WorldInteraction.new()
	interaction.name = id
	interaction.position = at
	interaction.kind = kind
	interaction.prompt = label
	adopt(interaction,scene.get_node("Interactions"))
	if kind == "checkpoint":
		var shrine := AnimatedSprite2D.new()
		shrine.name = "Shrine"
		shrine.sprite_frames = load("res://features/world/checkpoint_frames.tres")
		shrine.animation = shrine.sprite_frames.get_animation_names()[0]
		shrine.autoplay = shrine.animation
		shrine.position.y = -20
		adopt(shrine,interaction)
	return interaction

func door(id: String, at: Vector2, target: String, spawn: String, label: String, requirement := "") -> void:
	var interaction := point(id,at,"exit",label)
	interaction.target_room = target
	interaction.target_spawn = spawn
	interaction.required_flag = requirement

func sprite(parent: Node, name_text: String, at: Vector2, region: Rect2, tint := Color.WHITE) -> void:
	var art := Sprite2D.new()
	art.name = name_text
	art.position = at
	art.texture = load("res://assets/environment/forest.png")
	art.region_enabled = true
	art.region_rect = region
	art.centered = false
	art.modulate = tint
	adopt(art,parent)

func arch(x: float, floor_y: float) -> void:
	sprite(scene.get_node("Decor"),"Arch%d" % x,Vector2(x,floor_y-160),Rect2(0,256,192,160),Color(0.8,0.88,0.92,0.68))

func wall(name_text: String, rect: Rect2, id: StringName = &"") -> void:
	var body: StaticBody2D = StaticBody2D.new() if id.is_empty() else WallEchoSurface.new()
	body.name = name_text
	body.position = rect.position
	if body is WallEchoSurface:
		(body as WallEchoSurface).surface_id = id
	adopt(body,scene)
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	shape.position = rect.size/2
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	adopt(shape,body)
	var art := Node2D.new()
	art.name = "Art"
	adopt(art,body)
	for y: int in range(0,int(rect.size.y),32):
		sprite(art,"Stone%d" % y,Vector2(0,y),Rect2(800,64,rect.size.x,minf(32,rect.size.y-y)))
	if not id.is_empty():
		for y: int in range(10,int(rect.size.y)-4,24):
			var groove := Line2D.new()
			groove.name = "Groove%d" % y
			groove.points = PackedVector2Array([Vector2(7,y),Vector2(rect.size.x-7,y)])
			groove.width = 3
			groove.default_color = Color("94e4ce")
			adopt(groove,art)

func enemy(kind: String, id: String, at: Vector2) -> void:
	var packed := load("res://features/enemies/bell_%s.tscn" % kind) as PackedScene
	var instance := packed.instantiate() as Node2D
	instance.name = id
	instance.position = at
	adopt(instance,scene.get_node("Enemies"))

func slab(at: Vector2) -> void:
	var hazard := (load("res://features/world/resonant_slab.tscn") as PackedScene).instantiate() as Node2D
	hazard.position = at
	adopt(hazard,scene.get_node("Hazards"))

func entry() -> void:
	start("windworn_steps","风蚀阶庭",1024)
	mark("entry",Vector2(96,704))
	mark("east",Vector2(880,704))
	mark("checkpoint",Vector2(176,704))
	point("Shrine",Vector2(176,704),"checkpoint","记录试玩重试点")
	point("StoneLesson",Vector2(320,704),"sign","鸣石踩下后才回鸣；亮起时可以退到两侧实地。")
	slab(Vector2(480,704))
	arch(40,704)
	arch(704,704)
	door("East",Vector2(928,704),"bell_guard_walk","entry","向东 · 守钟外廊")
	finish()

func guard_walk() -> void:
	start("bell_guard_walk","守钟外廊",1536)
	mark("entry",Vector2(112,704))
	mark("east",Vector2(1408,704))
	door("West",Vector2(64,704),"windworn_steps","east","向西 · 风蚀阶庭")
	door("East",Vector2(1472,704),"broken_bell_atrium","entry","向东 · 断钟中庭","clear")
	enemy("invoker","FirstInvoker",Vector2(448,704))
	enemy("invoker","SecondInvoker",Vector2(1088,704))
	scene.get_node("Enemies/SecondInvoker").opening_spell = 1
	point("StaffLesson",Vector2(192,704),"sign","前方杖使会放出钟波，跳过后近身；地面出现咒印时离开原位。剑击可以打断施法。")
	arch(640,704)
	finish()

func atrium() -> void:
	start("broken_bell_atrium","断钟中庭",1024)
	mark("entry",Vector2(128,704))
	mark("cloister_lower",Vector2(864,704))
	mark("cloister_upper",Vector2(832,256))
	mark("gallery",Vector2(160,256))
	mark("checkpoint",Vector2(416,704))
	fill(Rect2i(64,256,832,32))
	point("Shrine",Vector2(416,704),"checkpoint","记录中庭重试点")
	door("WestLower",Vector2(64,704),"bell_guard_walk","east","向西 · 守钟外廊")
	door("EastLower",Vector2(928,704),"echo_cloister","entry","向东 · 回音修院下层")
	door("EastUpper",Vector2(864,256),"echo_cloister","upper","向东 · 回音修院上层","wall_passage_open")
	door("WestUpper",Vector2(96,256),"hanging_gallery","entry","向西 · 悬铃回廊")
	point("Branches",Vector2(544,256),"sign","两座承钟支路与终钟台尚未开放；本次试玩先向西体验铃翼掠袭。")
	arch(32,704)
	arch(800,704)
	finish()

func cloister() -> void:
	start("echo_cloister","回音修院",1024)
	mark("entry",Vector2(96,704))
	mark("upper",Vector2(432,192))
	mark("checkpoint",Vector2(176,704))
	door("LowerReturn",Vector2(48,704),"broken_bell_atrium","cloister_lower","向西 · 中庭下层")
	var ability := point("WallEcho",Vector2(176,704),"ability","领取踏壁回响")
	ability.stable_id = "wall_echo"
	wall("LowLesson",Rect2(256,640,32,64),&"lesson_wall")
	fill(Rect2i(288,640,320,64))
	wall("FirstLeft",Rect2(416,416,32,160),&"cloister_first_left")
	wall("FirstRight",Rect2(576,320,32,320),&"cloister_first_right")
	fill(Rect2i(96,416,352,32))
	wall("SecondLeft",Rect2(96,96,32,320),&"cloister_second_left")
	wall("SecondRight",Rect2(256,192,32,160),&"cloister_second_right")
	fill(Rect2i(256,192,224,32))
	wall("ReturnGate",Rect2(384,-64,16,256))
	var latch := point("UpperLatch",Vector2(328,192),"reward","打开上层回闩")
	latch.stable_id = "wall_passage_open"
	door("UpperReturn",Vector2(448,192),"broken_bell_atrium","cloister_upper","向右 · 中庭上层回桥","wall_passage_open")
	point("Lesson",Vector2(352,640),"sign","先跳向右侧刻槽墙，再连续点按跳跃；系统帮助蹬向对墙，不用来回切方向。宽台可休息。")
	finish()

func gallery() -> void:
	start("hanging_gallery","悬铃回廊",1152,384)
	mark("entry",Vector2(1040,320))
	mark("checkpoint",Vector2(1040,320))
	door("East",Vector2(1104,320),"broken_bell_atrium","gallery","向东 · 中庭上层")
	point("Shrine",Vector2(1008,320),"checkpoint","记录回廊重试点")
	point("BatLesson",Vector2(928,320),"sign","铃翼远处蓄力后发出三道声刃，跳开或盾挡；靠近后会俯冲，扑空低停时反击。")
	enemy("skimmer","FirstSkimmer",Vector2(752,248))
	enemy("skimmer","SecondSkimmer",Vector2(288,248))
	slab(Vector2(240,320))
	arch(480,320)
	point("PreviewEnd",Vector2(64,320),"goal","完成本段试玩")
	finish()
