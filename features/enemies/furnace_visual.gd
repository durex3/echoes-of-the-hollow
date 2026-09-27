extends Node2D
## Visual clocks inherit pause; captured poses never move collision bodies.
const AURA := preload("res://features/combat/pixel_aura.gdshader")
const CHARGE_TINT := preload("res://features/combat/charge_tint.gdshader")
@export var sprite_path: NodePath
@onready var boss := get_parent() as FurnaceKeeper
@onready var source := get_node(sprite_path) as AnimatedSprite2D
var glow: Sprite2D
var ghosts: Array[Sprite2D] = []
var ages: Array[float] = []
var sample_left := 0.0

func _ready() -> void:
	var tint := ShaderMaterial.new()
	tint.shader = CHARGE_TINT
	source.material = tint
	glow = Sprite2D.new()
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.z_index = 0
	glow.region_enabled = true
	glow.region_filter_clip_enabled = false
	var material := ShaderMaterial.new()
	material.shader = AURA
	glow.material = material
	add_child(glow)
	for index: int in range(6):
		var ghost := Sprite2D.new()
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.z_index = 0
		ghost.hide()
		add_child(ghost)
		ghosts.append(ghost)
		ages.append(1.0)

func _physics_process(delta: float) -> void:
	var airborne := boss.state == FurnaceKeeper.State.TAKEOFF or boss.state == FurnaceKeeper.State.LANDING
	var charging := boss.state == FurnaceKeeper.State.WARNING and boss.attack in [FurnaceKeeper.Attack.SLAM,FurnaceKeeper.Attack.COMBO]
	var releasing := boss.state == FurnaceKeeper.State.IMPACT
	var clear := boss.state == FurnaceKeeper.State.DORMANT or boss.state == FurnaceKeeper.State.DEAD
	var charge_seconds := boss.config.hover_seconds if boss.attack == FurnaceKeeper.Attack.SLAM else boss.config.combo_charge if boss.combo_left == boss.config.combo_strikes else boss.config.combo_gap
	var progress := clampf(1.0-boss.timer/charge_seconds,0.0,1.0)
	var pulse := pow(sin(progress*PI*2.0),2.0)
	(source.material as ShaderMaterial).set_shader_parameter("charge_amount",(0.4 if Session.reduce_flashes else 0.25+0.75*pulse) if charging else 0.0)
	for index: int in range(ghosts.size()):
		ages[index] += delta
		ghosts[index].visible = not clear and ages[index] < boss.config.trail_seconds
		ghosts[index].modulate = Color(1.0,0.12,0.56,0.35*(1.0-clampf(ages[index]/boss.config.trail_seconds,0,1)))
	sample_left -= delta
	if airborne and sample_left <= 0:
		sample_left = boss.config.trail_interval
		var oldest := 0
		for index: int in range(ages.size()):
			if ages[index] > ages[oldest]:
				oldest = index
		var ghost := ghosts[oldest]
		ghost.texture = source.sprite_frames.get_frame_texture(source.animation,source.frame)
		ghost.global_position = source.global_position
		ghost.scale = source.scale
		ghost.flip_h = source.flip_h
		ages[oldest] = 0.0
		ghost.show()
	# Ghosts stay at captured world positions while their parent travels.
	for index: int in range(ghosts.size()):
		if ghosts[index].visible:
			ghosts[index].top_level = true
	glow.visible = charging or airborne or releasing
	if not glow.visible:
		return
	var texture := source.sprite_frames.get_frame_texture(source.animation,source.frame) as AtlasTexture
	# Leave transparent drawing space around the atlas cell for the halo.
	glow.texture = texture.atlas
	glow.region_rect = texture.region.grow(boss.config.aura_radius*2)
	glow.position = source.position
	glow.scale = source.scale
	glow.flip_h = source.flip_h
	var bounds := Rect2(texture.region.position/texture.atlas.get_size(),texture.region.size/texture.atlas.get_size())
	var material := glow.material as ShaderMaterial
	material.set_shader_parameter("silhouette_texture",texture.atlas)
	material.set_shader_parameter("frame_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
	material.set_shader_parameter("upper_focus",1.0)
	material.set_shader_parameter("silhouette_scale",Vector2.ONE.lerp(boss.config.charge_expansion,pulse) if charging and not Session.reduce_flashes else Vector2.ONE)
	material.set_shader_parameter("radius",boss.config.aura_radius*(0.65+0.35*pulse) if charging else boss.config.aura_radius)
	var intensity := boss.config.aura_strength*(0.35+0.65*pulse) if charging else 0.65
	material.set_shader_parameter("strength",minf(intensity,0.55) if Session.reduce_flashes else intensity)
