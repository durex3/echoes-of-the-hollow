@tool
extends Node2D
## Background silhouettes only. Terrain and collision are authored native nodes.
@export var room_width := 1280.0
@export var room_height := 768.0
@export var courtyard := false
@export_enum("entry","guard","hub","cloister","gallery") var theme := "entry"
const STONE := preload("res://assets/environment/forest.png")

func _draw() -> void:
	draw_rect(Rect2(0,0,room_width,room_height),Color("71879a"))
	# Hand-authored, low-contrast sky bands and clouds retain empty combat space.
	for index: int in range(24):
		var y := index*room_height/24
		var shade := Color("637a91").lerp(Color("849caa"),float(index)/24)
		draw_rect(Rect2(0,y,room_width,room_height/24+1),shade)
	for index: int in range(6):
		var x := 72.0+index*258
		var y := 94.0+(index%3)*74
		cloud(Vector2(x,y),0.55+float(index%2)*0.2)
	# Distant course-pack masonry replaces the repeated flat castle symbols.
	for index: int in range(5):
		var x := float(index)*352-96
		var top := room_height-340-float((index*47)%100)
		draw_texture_rect_region(STONE,Rect2(x,top,128,224),Rect2(352,192,128,224),Color(0.68,0.82,0.92,0.28))
		for y: int in range(int(top)+224,int(room_height),96):
			draw_texture_rect_region(STONE,Rect2(x,y,128,96),Rect2(352,320,128,96),Color(0.68,0.82,0.92,0.28))
	architecture()
	if theme == "entry":
		broken_column(Vector2(48,room_height-64),172)
		broken_column(Vector2(room_width-72,room_height-64),224)
	elif theme == "guard":
		broken_column(Vector2(700,room_height-64),210)
		banner(Vector2(788,room_height-280),84)
	elif theme == "cloister":
		# Recessed panels distinguish the teaching space without imitating platforms.
		for x: int in [48,688,880]:
			draw_rect(Rect2(x,96,56,room_height-160),Color("637e8b"))
			draw_rect(Rect2(x+8,104,40,room_height-176),Color("6e8995"))
		for y: int in [272,496]:
			draw_texture_rect_region(STONE,Rect2(672,y,192,12),Rect2(512,192,128,12),Color(0.8,0.85,0.9,0.38))
	elif theme == "gallery":
		for index: int in range(4):
			var x := 80.0+index*304
			var y := 108.0+(index%2)*27
			chain(Vector2(x,0),y-36)
			bell(Vector2(x,y),0.40,false)
		broken_column(Vector2(554,room_height-64),144)
	if courtyard:
		# One tall belfry joins the two routes visually: chain above, broken bell below.
		broken_column(Vector2(358,704),610)
		broken_column(Vector2(666,704),546)
		draw_texture_rect_region(STONE,Rect2(370,88,292,20),Rect2(512,192,128,16),Color("9da7a2"))
		chain(Vector2(512,108),417)
		bell(Vector2(512,620),1.35,true)
		banner(Vector2(698,196),112)
		# Small bells remain visible from the upper bridge.
		chain(Vector2(760,0),90)
		bell(Vector2(760,134),0.48,false)
	# Grounded debris, foliage and dark skirting tie the buildings to the terrain.
	for x: int in range(36,int(room_width),256):
		draw_texture_rect_region(STONE,Rect2(x,room_height-81,48,17),Rect2(640,192,64,32),Color("8b9493"))
		draw_texture_rect_region(STONE,Rect2(x+58,room_height-88,32,24),Rect2(640,224,32,32),Color("677c71"))

func masonry(rect: Rect2, tint: Color) -> void:
	for y: int in range(0,int(rect.size.y),32):
		for x: int in range(0,int(rect.size.x),32):
			var size := Vector2(minf(32,rect.size.x-x),minf(32,rect.size.y-y))
			draw_texture_rect_region(STONE,Rect2(rect.position+Vector2(x,y),size),Rect2(Vector2(800+32*((x/32+y/32)%2),64),size),tint)

func lancet(center: Vector2, height: float) -> void:
	# Recessed, closed architectural window: subdued edges distinguish it from doors.
	var shape := PackedVector2Array([Vector2(-34,0),Vector2(-34,-height+28),Vector2(-18,-height+10),Vector2(0,-height),Vector2(18,-height+10),Vector2(34,-height+28),Vector2(34,0)])
	for i: int in range(shape.size()):
		shape[i] += center
	draw_colored_polygon(shape,Color("263b46"))
	shape.append(shape[0])
	draw_polyline(shape,Color("647377"),4)
	draw_line(center+Vector2(0,-height+12),center,Color("516871"),4)
	draw_line(center+Vector2(-30,-height*0.45),center+Vector2(30,-height*0.45),Color("516871"),3)
	draw_rect(Rect2(center+Vector2(-26,-height+38),Vector2(19,height-44)),Color(0.47,0.65,0.67,0.14))

func architecture() -> void:
	var floor_y := room_height-64
	var stone := Color("647079")
	match theme:
		"hub":
			# Tall belfry bays frame the suspended bell and both playable levels.
			masonry(Rect2(304,72,416,632),Color("59666e"))
			masonry(Rect2(336,304,352,32),Color("84918f"))
			for x: int in [384,512,640]:
				lancet(Vector2(x,238),148)
			for x: int in [408,616]:
				lancet(Vector2(x,660),256)
			masonry(Rect2(464,352,96,352),Color("485b64"))
			banner(Vector2(320,392),92)
			banner(Vector2(704,392),118)
		"cloister":
			masonry(Rect2(0,64,room_width,floor_y-64),Color("4c5c67"))
			for x: int in [48,352,736,928]:
				lancet(Vector2(x,368),236)
				lancet(Vector2(x,656),190)
			for y: int in [80,384]:
				masonry(Rect2(0,y,room_width,16),stone)
		"guard":
			for x: int in [240,576,912,1248]:
				masonry(Rect2(x-48,floor_y-280,96,280),Color("536773"))
				lancet(Vector2(x,floor_y-40),176)
				banner(Vector2(x+68,floor_y-228),110)
			masonry(Rect2(0,floor_y-48,room_width,48),Color("455d69"))
		"gallery":
			for x: int in [0,304,608,912]:
				masonry(Rect2(x,0,40,floor_y),Color("536471"))
				masonry(Rect2(x,0,240,32),stone)
				banner(Vector2(x+210,28),70)
			masonry(Rect2(0,floor_y-32,room_width,32),Color("4e646e"))
		_:
			masonry(Rect2(624,floor_y-320,160,320),Color("536673"))
			lancet(Vector2(704,floor_y-48),220)
			banner(Vector2(810,floor_y-258),138)

func cloud(at: Vector2, opacity: float) -> void:
	var tint := Color("a2b2bb")
	tint.a = opacity*0.45
	draw_rect(Rect2(at,Vector2(136,6)),tint)
	draw_rect(Rect2(at+Vector2(24,-6),Vector2(76,6)),tint)
	draw_rect(Rect2(at+Vector2(45,-11),Vector2(38,5)),tint)
	draw_rect(Rect2(at+Vector2(-22,6),Vector2(176,4)),Color(tint,opacity*0.17))

func broken_column(foot: Vector2, height: float) -> void:
	var rect := Rect2(foot-Vector2(16,height),Vector2(32,height))
	# Pixel masonry is the same course atlas as foreground walkable terrain.
	for y: int in range(0,int(height),32):
		draw_texture_rect_region(STONE,Rect2(rect.position+Vector2(0,y),Vector2(32,minf(32,height-y))),Rect2(800,64,32,minf(32,height-y)),Color(0.72,0.83,0.89,0.65))
	draw_rect(Rect2(rect.position-Vector2(5,4),Vector2(42,7)),Color("718790"))
	draw_rect(Rect2(foot+Vector2(-22,-12),Vector2(44,12)),Color("627b86"))

func chain(at: Vector2, length: float) -> void:
	for y: int in range(0,int(length),8):
		draw_rect(Rect2(at+Vector2(-2,y),Vector2(4,6)),Color("7f8172"),false,1)
		draw_line(at+Vector2(0,y+5),at+Vector2(0,y+9),Color("b0ac89"),1)

func banner(at: Vector2, length: float) -> void:
	draw_rect(Rect2(at+Vector2(-18,-3),Vector2(42,5)),Color("847e6c"))
	var cloth := PackedVector2Array([Vector2(-12,0),Vector2(17,0),Vector2(17,length-18),Vector2(8,length-25),Vector2(5,length),Vector2(-4,length-12),Vector2(-12,length-8)])
	for index: int in range(cloth.size()):
		cloth[index] += at
	draw_colored_polygon(cloth,Color("536879"))
	draw_line(at+Vector2(-7,8),at+Vector2(-7,length-18),Color("829193"),2)
	draw_rect(Rect2(at+Vector2(0,14),Vector2(5,16)),Color("b0a47d"))

func bell(at: Vector2, size: float, cracked: bool) -> void:
	var outline := PackedVector2Array([Vector2(-44,0),Vector2(-44,-7),Vector2(-35,-7),Vector2(-35,-17),Vector2(-29,-17),Vector2(-29,-46),Vector2(-24,-46),Vector2(-24,-60),Vector2(-14,-60),Vector2(-14,-68),Vector2(14,-68),Vector2(14,-60),Vector2(24,-60),Vector2(24,-46),Vector2(29,-46),Vector2(29,-17),Vector2(35,-17),Vector2(35,-7),Vector2(44,-7),Vector2(44,0)])
	for index: int in range(outline.size()):
		outline[index] = (at+outline[index]*size).round()
	draw_colored_polygon(outline,Color("766d55"))
	# Narrow cast-metal facets, collar rivets and tarnish survive at gameplay scale.
	for index: int in range(7):
		var x := -21+index*7
		draw_rect(Rect2(at+Vector2(x,-55)*size,Vector2(5,42)*size),Color("a18f69") if index<3 else Color("625f50"))
	draw_rect(Rect2(at+Vector2(-22,-51)*size,Vector2(7,35)*size),Color("b2a179"))
	draw_rect(Rect2(at+Vector2(15,-45)*size,Vector2(8,32)*size),Color("6a6b5e"))
	for y: int in [-57,-12,-5]:
		draw_rect(Rect2(at+Vector2(-25 if y==-57 else -38,y)*size,Vector2(50 if y==-57 else 76,3)*size),Color("b5a27c"))
	draw_rect(Rect2(at+Vector2(-4,0)*size,Vector2(8,15)*size),Color("998665"))
	for x: int in [-28,-14,0,14,28]:
		draw_rect(Rect2(at+Vector2(x,-9)*size,Vector2(2,2)*size),Color("e0c697"))
	for index: int in range(12):
		var x := -19+(index*17)%39
		var y := -49+(index*13)%34
		draw_rect(Rect2(at+Vector2(x,y)*size,Vector2(3,2)*size),Color("687b6b"))
	if cracked:
		draw_polyline(PackedVector2Array([at+Vector2(7,-66)*size,at+Vector2(0,-40)*size,at+Vector2(12,-23)*size,at+Vector2(3,0)*size]),Color("435f6d"),3*size)
