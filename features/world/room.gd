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
var rehearsal := false
var challenge_mode := false

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
		if enemy is FurnaceKeeper and not rehearsal and "furnace_keeper_defeated" in Session.flags:
			$Enemies.remove_child(enemy)
			enemy.queue_free()
			continue
		if enemy is HollowWarden and not rehearsal and "warden_defeated" in Session.flags:
			$Enemies.remove_child(enemy)
			enemy.queue_free()
			continue
		if enemy is DoomScribe:
			enemy.cast_requested.connect(_spawn_bolt.bind(enemy.get_instance_id()))
			enemy.defeated.connect(clear_projectiles.bind(enemy.get_instance_id()))
	if room_id in ["heart_chamber", "furnace_core"]:
		(get_node("ArenaGate") as FurnaceArenaGate).set_closed(not is_cleared())

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
		if _boss_exit_locked(point):
			continue
		var current := player.global_position.distance_to(point.global_position)
		if current < minf(distance, point.interaction_radius):
			distance = current
			nearest = point
	var message := nearest.prompt if nearest else ""
	if nearest and nearest.kind == "exit":
		if nearest.prompt in ["E / FACE THE HOLLOW WARDEN", "E / CHAPTER II - EMBER CISTERN"]:
			message = TextCatalog.text(nearest.prompt) + " / " + TextCatalog.room_name(nearest.target_room)
		else:
			message = TextCatalog.text("E / TO ") + TextCatalog.room_name(nearest.target_room)
	if message != last_prompt:
		last_prompt = message
		prompt_changed.emit(message)
	if nearest and Input.is_action_just_pressed("interact"):
		interaction_requested.emit(nearest)

func nearby_exit_target() -> String:
	if not is_instance_valid(player):
		return ""
	var nearest_distance := 64.0
	var target := ""
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		if not point.visible or point.kind != "exit" or _boss_exit_locked(point):
			continue
		var distance := player.global_position.distance_to(point.global_position)
		if distance < minf(nearest_distance, point.interaction_radius):
			nearest_distance = distance
			target = point.target_room
	return target

func _boss_exit_locked(point: WorldInteraction) -> bool:
	return room_id in ["heart_chamber", "furnace_core"] and point.kind == "exit" and point.name == "Return" and not is_cleared()

func spawn_position(spawn_id: String) -> Vector2:
	var marker := get_node_or_null("Spawns/" + spawn_id) as Marker2D
	assert(marker != null, "Unknown spawn ID: " + spawn_id)
	return marker.global_position

func update_progress() -> void:
	if room_id in ["heart_chamber", "furnace_core"]:
		(get_node("ArenaGate") as FurnaceArenaGate).set_closed(not is_cleared())
	var hazards := get_node_or_null("Hazards")
	if hazards and "cistern_restored" in Session.flags:
		for vent: SteamVent in hazards.get_children():
			vent.deactivate()
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		if challenge_mode:
			point.visible = false
			continue
		point.visible = true
		if point.kind == "exit" and point.name == "Return" and room_id in ["heart_chamber", "furnace_core"]:
			point.visible = is_cleared()
		elif point.kind == "ability":
			point.visible = not Session.abilities.has(point.stable_id)
		elif point.kind == "goal":
			point.visible = not Session.completed
		elif point.kind in ["reward", "upgrade", "chapter_end"]:
			point.visible = point.stable_id not in Session.flags
			if room_id == "furnace_core" and point.kind == "chapter_end":
				point.visible = is_cleared() and "furnace_keeper_defeated" in Session.flags
		elif point.kind == "finale":
			point.visible = "warden_defeated" in Session.flags and point.stable_id not in Session.flags
		elif point.kind == "challenge":
			point.visible = not rehearsal and "furnace_keeper_defeated" in Session.flags
		if not point.visible_after_flag.is_empty():
			point.visible = point.visible and point.visible_after_flag in Session.flags

func is_cleared() -> bool:
	for enemy: Node in $Enemies.get_children():
		var health := enemy.get_node_or_null("Health") as HealthComponent
		if health and health.current > 0:
			return false
	return true
