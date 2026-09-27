class_name PlayerSlash
extends Node2D
## The course smear sequence follows the real sword active window.
const FRAMES := preload("res://features/player/slash_frames.tres")
const AURA := preload("res://features/combat/pixel_aura.gdshader")
@export var config: PlayerVfxConfig
var core: Sprite2D
var glow: Sprite2D
var pose := 0

func _ready() -> void:
	position = config.slash_position
	core = Sprite2D.new()
	core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	core.scale = config.slash_size / Vector2(92, 39)
	core.modulate = config.slash_color
	glow = Sprite2D.new()
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.region_enabled = true
	glow.region_filter_clip_enabled = false
	glow.scale = core.scale
	var material := ShaderMaterial.new()
	material.shader = AURA
	material.set_shader_parameter("glow_color", config.slash_glow_color)
	material.set_shader_parameter("radius", config.slash_glow_radius)
	glow.material = material
	add_child(glow)
	add_child(core)
	present(0.0)
	hide()

func present(progress: float, variant := 0) -> void:
	pose = mini(3, int(clampf(progress, 0.0, 1.0) * 4))
	var texture := FRAMES.get_frame_texture(&"return_swing" if variant == 1 else &"swing", pose) as AtlasTexture
	core.texture = texture
	glow.texture = texture.atlas
	glow.region_rect = texture.region.grow(config.slash_glow_radius * 2)
	var bounds := Rect2(texture.region.position / texture.atlas.get_size(), texture.region.size / texture.atlas.get_size())
	var material := glow.material as ShaderMaterial
	material.set_shader_parameter("silhouette_texture", texture.atlas)
	material.set_shader_parameter("frame_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
	var strength := config.slash_glow_strength * (0.5 if pose >= 2 else 1.0)
	material.set_shader_parameter("strength", strength * (0.3 if Session.reduce_flashes else 1.0))
