class_name GameRoom
extends Node2D

signal interaction_requested(interaction: WorldInteraction)
signal prompt_changed(text: String)
signal projectile_impact(at: Vector2, defeated: bool)
signal gate_breached(stable_id: String)
const BOLT := preload("res://features/combat/ink_bolt.tscn")
@export var room_id := "forest"
@export var display_name := "01 / THE FORGOTTEN GROVE"
@export var music_track := "forest"
@export var bounds := Rect2(0, 0, 1280, 576)
var player: Player
var enabled := true
var last_prompt := ""
var projectiles: Node2D

func _ready() -> void:
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	var gates := get_node_or_null("Gates")
	if gates:
		for gate: WindGate in gates.get_children():
			gate.set_open(gate.stable_id in Session.flags)
			gate.breached.connect(func(id: String) -> void: gate_breached.emit(id))
	for enemy: Node in $Enemies.get_children():
		if enemy is HollowWarden and "warden_defeated" in Session.flags:
			$Enemies.remove_child(enemy)
			enemy.queue_free()
			continue
		if enemy is DoomScribe:
			enemy.cast_requested.connect(_spawn_bolt.bind(enemy.get_instance_id()))
			enemy.defeated.connect(clear_projectiles.bind(enemy.get_instance_id()))

func _spawn_bolt(at: Vector2, direction: Vector2, settings: ScribeConfig, source_id: int) -> void:
	if not enabled:
		return
	var bolt := BOLT.instantiate() as InkBolt
	bolt.config = settings
	bolt.direction = direction
	bolt.source_id = source_id
	bolt.position = projectiles.to_local(at)
	bolt.impact.connect(func(where: Vector2, killed: bool) -> void: projectile_impact.emit(where,killed))
	projectiles.add_child(bolt)

func clear_projectiles(source_id := 0) -> void:
	for bolt: InkBolt in projectiles.get_children():
		if source_id == 0 or bolt.source_id == source_id:
			bolt.retire()

func _physics_process(_delta: float) -> void:
	if not enabled or not is_instance_valid(player) or player.state == Player.State.DEAD:
		return
	var nearest: WorldInteraction
	var distance := 64.0
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		if not point.visible:
			continue
		var current := player.global_position.distance_to(point.global_position)
		if current < minf(distance, point.interaction_radius):
			distance = current
			nearest = point
	var message := nearest.prompt if nearest else ""
	if message != last_prompt:
		last_prompt = message
		prompt_changed.emit(message)
	if nearest and Input.is_action_just_pressed("interact"):
		interaction_requested.emit(nearest)

func spawn_position(spawn_id: String) -> Vector2:
	var marker := get_node_or_null("Spawns/" + spawn_id) as Marker2D
	assert(marker != null, "Unknown spawn ID: " + spawn_id)
	return marker.global_position

func update_progress() -> void:
	var hazards := get_node_or_null("Hazards")
	if hazards and "cistern_restored" in Session.flags:
		for vent: SteamVent in hazards.get_children():
			vent.deactivate()
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		point.visible = true
		if point.kind == "ability":
			point.visible = not Session.abilities.has(point.stable_id)
		elif point.kind == "goal":
			point.visible = not Session.completed
		elif point.kind in ["reward", "upgrade", "chapter_end"]:
			point.visible = point.stable_id not in Session.flags
		elif point.kind == "finale":
			point.visible = "warden_defeated" in Session.flags and point.stable_id not in Session.flags
		if not point.visible_after_flag.is_empty():
			point.visible = point.visible and point.visible_after_flag in Session.flags

func is_cleared() -> bool:
	for enemy: Node in $Enemies.get_children():
		var health := enemy.get_node_or_null("Health") as HealthComponent
		if health and health.current > 0:
			return false
	return true
