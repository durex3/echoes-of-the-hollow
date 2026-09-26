class_name SteamVent
extends Area2D
## Visible rest -> warning -> active loop. No moving collision or global clock.
enum Phase { REST, WARNING, ACTIVE }
@export var config: SteamConfig
var phase := Phase.REST
var elapsed := 0.0
var enabled := true
var protected_ids: Array[int] = []

func _ready() -> void:
	assert(config != null)
	var shape := RectangleShape2D.new()
	shape.size = config.plume_size
	$Shape.shape = shape
	$Shape.position.y = -config.plume_size.y / 2.0

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	elapsed += delta
	var duration := config.rest_seconds
	if phase == Phase.WARNING:
		duration = config.warning_seconds
	elif phase == Phase.ACTIVE:
		duration = config.active_seconds
	if elapsed >= duration:
		elapsed -= duration
		phase = (phase + 1) % 3 as Phase
		protected_ids.clear()
	if phase == Phase.ACTIVE:
		for body: Node2D in get_overlapping_bodies():
			if body is Player:
				if body.state == Player.State.DEAD or body.get_instance_id() in protected_ids:
					continue
				if body.health.invulnerability_left <= 0 and body.steam_ward.absorb():
					protected_ids.append(body.get_instance_id())
					continue
				body.health.take_damage(config.damage, global_position)
	queue_redraw()

func deactivate() -> void:
	protected_ids.clear()
	enabled = false
	phase = Phase.REST
	elapsed = 0
	queue_redraw()

func _draw() -> void:
	if config == null:
		return
	var half := config.plume_size.x / 2.0
	draw_rect(Rect2(-half, -6, half * 2, 6), Color("47535a"))
	for x: int in range(-int(half) + 4, int(half), 8):
		draw_line(Vector2(x, -5), Vector2(x, -1), Color("182630"), 3)
	if not enabled:
		return
	if phase == Phase.REST:
		draw_line(Vector2(-half, -9), Vector2(half, -9), Color("94e4ce"), 2)
	elif phase == Phase.WARNING:
		draw_rect(Rect2(-half, -config.plume_size.y, half * 2, config.plume_size.y), Color(1, 0.65, 0.3, 0.10))
		draw_line(Vector2(-half, -9), Vector2(half, -9), Color("efb268"), 4)
		for x: int in [-20, 0, 20]:
			draw_line(Vector2(x, -14), Vector2(x, -26 - elapsed * 12), Color("efb268"), 2)
	else:
		draw_rect(Rect2(-half, -config.plume_size.y, half * 2, config.plume_size.y), Color(0.85, 0.91, 0.94, 0.36))
		for x: int in range(-int(half) + 4, int(half), 8):
			for index: int in range(3):
				var y := -10.0 - fmod(elapsed * 70 + index * 25 + x, config.plume_size.y - 12)
				draw_line(Vector2(x,y), Vector2(x+2,y-10), Color("dde9eb"), 2)
