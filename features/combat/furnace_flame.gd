class_name FurnaceFlame
extends Area2D
## Source-pack flame art; each cast handles each target once, including blocks.
signal impact(at: Vector2, killed: bool)
const AURA := preload("res://features/combat/pixel_aura.gdshader")
@export var config: FurnaceConfig
@export var wave := false
@export var tall := false
@export var outward := false
@export var instant := false
var direction := -1.0
var warning_left := 0.0
var active_left := 0.0
var elapsed := 0.0
var dissipating := false
var handled: Array[int] = []
var glow: Sprite2D
var burst_sprites: Array[Sprite2D] = []
var burst_glows: Array[Sprite2D] = []
@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	warning_left = 0.0 if wave or instant else config.eruption_warning
	active_left = config.wave_seconds if wave else config.outward_seconds if outward else config.eruption_seconds
	if tall and instant:
		active_left = config.burst_seconds
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26,38) if wave else Vector2(config.pillar_width,config.outward_height) if outward else Vector2(config.pillar_width,config.pillar_height) if tall else Vector2(66,88)
	$Shape.shape = shape
	$Shape.position.y = -shape.size.y/2
	if outward:
		$Shape.position.x = direction*config.outward_hit_offset
	# The wave occupies the right half of its source cells; crop before centering.
	# Only the art is fitted to the existing 26x38 / 66x88 damage shapes.
	sprite.scale = Vector2(0.4,0.3) if wave else Vector2(1.4,config.outward_height/128.0) if outward else Vector2(2.0,1.9) if tall else Vector2(0.55,0.7)
	sprite.position.y = -19.05 if wave else -config.outward_height/2 if outward else -shape.size.y/2
	sprite.flip_h = (wave or outward) and direction < 0
	sprite.animation = &"wave" if wave or outward else &"eruption"
	if tall and instant:
		sprite.visible = false
	sprite.frame = 0
	if not (tall and instant):
		sprite.visible = warning_left <= 0
	if outward:
		glow = _create_glow()
		_update_glow()
	if tall and instant:
		for side: float in [-1.0,1.0]:
			var burst := Sprite2D.new()
			burst.flip_h = side < 0
			burst.scale = Vector2(1,config.burst_height/128.0)
			add_child(burst)
			burst_sprites.append(burst)
			burst_glows.append(_create_glow())
		_update_burst()

func _create_glow() -> Sprite2D:
	var aura := Sprite2D.new()
	aura.region_enabled = true
	aura.region_filter_clip_enabled = false
	var material := ShaderMaterial.new()
	material.shader = AURA
	material.set_shader_parameter("radius",config.flame_aura_radius)
	material.set_shader_parameter("strength",config.flame_aura_strength)
	aura.material = material
	add_child(aura)
	move_child(aura,0)
	return aura

func _fit_glow(aura: Sprite2D, pose: Sprite2D, texture: AtlasTexture) -> void:
	aura.texture = texture.atlas
	(aura.material as ShaderMaterial).set_shader_parameter("silhouette_texture",texture.atlas)
	aura.region_rect = texture.region.grow(config.flame_aura_radius)
	aura.position = pose.position
	aura.scale = pose.scale
	aura.flip_h = pose.flip_h
	aura.modulate = pose.modulate
	aura.visible = pose.visible
	var bounds := Rect2(texture.region.position/texture.atlas.get_size(),texture.region.size/texture.atlas.get_size())
	(aura.material as ShaderMaterial).set_shader_parameter("frame_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))

func _update_burst() -> void:
	var opening := clampf(elapsed/config.burst_seconds,0.0,1.0)
	var texture := sprite.sprite_frames.get_frame_texture(&"wave",int(elapsed*12)%4) as AtlasTexture
	for index: int in range(burst_sprites.size()):
		var burst := burst_sprites[index]
		burst.visible = not dissipating and opening < 1.0
		burst.texture = texture
		burst.position = Vector2((-1.0 if index == 0 else 1.0)*opening*24,-config.burst_height/2)
		burst.modulate.a = 1.0-opening*opening
		_fit_glow(burst_glows[index],burst,texture)

func _update_glow() -> void:
	if not is_instance_valid(glow):
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) as AtlasTexture
	# AnimatedSprite2D and Sprite2D share the same frame transform.
	glow.texture = texture.atlas
	(glow.material as ShaderMaterial).set_shader_parameter("silhouette_texture",texture.atlas)
	glow.region_rect = texture.region.grow(config.flame_aura_radius)
	glow.position = sprite.position
	glow.scale = sprite.scale
	glow.flip_h = sprite.flip_h
	glow.modulate = sprite.modulate
	glow.visible = sprite.visible
	var bounds := Rect2(texture.region.position/texture.atlas.get_size(),texture.region.size/texture.atlas.get_size())
	(glow.material as ShaderMaterial).set_shader_parameter("frame_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))

func _physics_process(delta: float) -> void:
	if dissipating:
		elapsed += delta
		_update_burst()
		var frames := sprite.sprite_frames.get_frame_count(&"dissipate")
		sprite.frame = mini(frames-1,int(elapsed/config.flame_dissipate_seconds*frames))
		_update_glow()
		if elapsed >= config.flame_dissipate_seconds:
			retire()
		return
	if warning_left > 0:
		warning_left = maxf(0,warning_left-delta)
		sprite.visible = warning_left <= 0
		queue_redraw()
		return
	active_left -= delta
	elapsed += delta
	_update_burst()
	if active_left <= 0:
		if wave or (tall and instant):
			retire()
		else:
			dissipating = true
			elapsed = 0
			sprite.animation = &"dissipate"
			sprite.frame = 0
			set_deferred("monitoring",false)
			$Shape.set_deferred("disabled",true)
		return
	if wave or outward:
		var speed := config.wave_speed if wave else config.outward_speed
		var motion := Vector2(direction*speed*delta,0)
		var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-18),global_position+motion+Vector2(0,-18),1)
		if wave and not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			retire()
			return
		position += motion
	if global_position.x < config.arena_min_x or global_position.x > config.arena_max_x:
		retire()
		return
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox and area.get_instance_id() not in handled:
			var result: Hurtbox.HitResult = area.resolve_hit(config.damage,global_position)
			handled.append(area.get_instance_id())
			if result == Hurtbox.HitResult.DAMAGED:
				impact.emit(area.hit_position(),area.health.current == 0)
			if wave:
				retire()
				return
	var count := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.frame = int(elapsed*12)%count if wave or outward else mini(count-1,int(elapsed/config.eruption_seconds*count))
	_update_glow()
	queue_redraw()

func retire() -> void:
	set_physics_process(false)
	hide()
	queue_free()

func _draw() -> void:
	if warning_left > 0:
		var width := config.pillar_width if tall else 66.0
		var height := config.pillar_height if tall else 88.0
		draw_rect(Rect2(-width/2,-height,width,height),Color(1,0.45,0.65,0.10))
		draw_line(Vector2(-width/2,-3),Vector2(width/2,-3),Color("ff9bcc"),4)
		draw_line(Vector2(0,-12),Vector2(0,-36),Color("ff9bcc"),2)
