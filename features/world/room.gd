class_name GameRoom
extends Node2D

signal interaction_requested(interaction: WorldInteraction)
signal prompt_changed(text: String)
@export var room_id := "forest"
@export var display_name := "01 / THE FORGOTTEN GROVE"
@export var music_track := "forest"
@export var bounds := Rect2(0, 0, 1280, 576)
var player: Player
var enabled := true
var last_prompt := ""

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
		if current < distance:
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
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		if point.kind == "ability":
			point.visible = not Session.abilities.has(point.stable_id)
		elif point.kind == "goal":
			point.visible = not Session.completed
		elif point.kind == "reward":
			point.visible = point.stable_id not in Session.flags

func is_cleared() -> bool:
	for enemy: Node in $Enemies.get_children():
		var health := enemy.get_node_or_null("Health") as HealthComponent
		if health and health.current > 0:
			return false
	return true
