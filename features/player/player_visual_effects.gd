class_name PlayerVisualEffects
extends Node2D
## World-space pose snapshots. No collision nodes and no independent time scale.
const AURA := preload("res://features/combat/pixel_aura.gdshader")
const TINT := preload("res://features/player/dash_tint.gdshader")
@export var config: PlayerVfxConfig
@export var sprite_path: NodePath
@onready var player := get_parent() as Player
@onready var source := get_node(sprite_path) as AnimatedSprite2D
var ghosts: Array[Sprite2D] = []
var halos: Array[Sprite2D] = []
var ages: Array[float] = []
var front: Sprite2D
var aura: Sprite2D
var sample_left := 0.0
var was_dashing := false

func _ready() -> void:
	for index: int in range(config.trail_count):
		var halo := _create_aura()
		halos.append(halo)
		ghosts.append(_create_pose())
		ages.append(config.trail_seconds)
	aura = _create_aura()
	front = _create_pose()
	front.z_index = 1
	clear()

func _create_pose() -> Sprite2D:
	var pose := Sprite2D.new()
	pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pose.top_level = true
	pose.z_index = 0
	var material := ShaderMaterial.new()
	material.shader = TINT
	material.set_shader_parameter("tint", config.dash_color)
	pose.material = material
	add_child(pose)
	return pose

func _create_aura() -> Sprite2D:
	var halo := Sprite2D.new()
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.top_level = true
	halo.z_index = 0
	halo.region_enabled = true
	halo.region_filter_clip_enabled = false
	var material := ShaderMaterial.new()
	material.shader = AURA
	material.set_shader_parameter("glow_color", config.dash_color)
	material.set_shader_parameter("radius", config.dash_glow_radius)
	material.set_shader_parameter("strength", config.dash_glow_strength)
	halo.material = material
	add_child(halo)
	return halo

func _physics_process(delta: float) -> void:
	if player.state in [Player.State.DEAD, Player.State.HURT]:
		clear()
		return
	var dashing := player.state == Player.State.DASH
	var reduced := 0.4 if Session.reduce_flashes else 1.0
	for index: int in range(ghosts.size()):
		ages[index] += delta
		var opacity := pow(1.0 - clampf(ages[index]/config.trail_seconds, 0.0, 1.0), 1.4)
		ghosts[index].visible = opacity > 0.0
		halos[index].visible = opacity > 0.0
		ghosts[index].modulate.a = opacity * config.trail_opacity * reduced
		halos[index].modulate.a = opacity * 0.65 * reduced
	if dashing and not was_dashing:
		sample_left = 0.0
	sample_left -= delta
	if dashing and sample_left <= 0.0:
		sample_left = config.trail_interval
		var oldest := 0
		for index: int in range(ages.size()):
			if ages[index] > ages[oldest]:
				oldest = index
		_capture(ghosts[oldest], halos[oldest])
		ages[oldest] = 0.0
		ghosts[oldest].modulate.a = config.trail_opacity * reduced
		halos[oldest].modulate.a = 0.65 * reduced
	front.visible = dashing
	aura.visible = dashing
	if dashing:
		_capture(front, aura)
		front.modulate.a = 0.65 * reduced
		aura.modulate.a = reduced
	was_dashing = dashing

func _capture(pose: Sprite2D, halo: Sprite2D) -> void:
	var texture := source.sprite_frames.get_frame_texture(source.animation, source.frame) as AtlasTexture
	pose.texture = texture
	pose.global_transform = source.global_transform
	pose.flip_h = source.flip_h
	pose.show()
	halo.texture = texture.atlas
	halo.region_rect = texture.region.grow(config.dash_glow_radius * 2)
	halo.global_transform = source.global_transform
	halo.flip_h = source.flip_h
	halo.show()
	var bounds := Rect2(texture.region.position/texture.atlas.get_size(), texture.region.size/texture.atlas.get_size())
	var material := halo.material as ShaderMaterial
	material.set_shader_parameter("silhouette_texture", texture.atlas)
	material.set_shader_parameter("frame_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))

func clear() -> void:
	for index: int in range(ghosts.size()):
		ghosts[index].hide()
		halos[index].hide()
		ages[index] = config.trail_seconds
	if is_instance_valid(front):
		front.hide()
		aura.hide()
	sample_left = 0.0
	was_dashing = false
