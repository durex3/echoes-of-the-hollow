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
		if enemy is BellWarden and not rehearsal and "bell_warden_defeated" in Session.flags:
			$Enemies.remove_child(enemy)
			enemy.queue_free()
			continue
		if room_id == "bell_guard_walk" and "bell_guard_cleared" in Session.flags or room_id == "bell_weight_chamber" and "bell_weight_cleared" in Session.flags or room_id == "hanging_gallery" and "hanging_gallery_cleared" in Session.flags or room_id == "confluence_bridge" and "confluence_bridge_cleared" in Session.flags:
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
		for child: Node in hazards.get_children():
			var vent := child as SteamVent
			if vent:
				vent.deactivate()
	var return_gate := get_node_or_null("ReturnGate")
	if return_gate and "wall_passage_open" in Session.flags:
		(return_gate.get_node("Collision") as CollisionShape2D).set_deferred("disabled", true)
		(return_gate.get_node("Art") as CanvasItem).hide()
	var east_bridge := get_node_or_null("ReturnBridge") as TileMapLayer
	if east_bridge:
		east_bridge.enabled = "east_weight_restored" in Session.flags
	var east_collision := get_node_or_null("BridgeCollision/Collision") as CollisionShape2D
	if east_collision:
		var restored := "east_weight_restored" in Session.flags if room_id == "bell_weight_chamber" else "west_weight_restored" in Session.flags
		var bridge_was_closed := east_collision.disabled
		east_collision.set_deferred("disabled", not restored)
		# The east-weight interaction sits beside the newly enabled bridge. If the
		# player is still overlapping its edge, clear that one-frame overlap before
		# physics resolves it as a hard trap.
		if restored and bridge_was_closed and room_id == "bell_weight_chamber" and is_instance_valid(player):
			if player.global_position.x > 1000.0 and player.global_position.y > 292.0:
				player.global_position = Vector2(976.0, 320.0)
	var west_bridge := get_node_or_null("BridgeTerrain") as TileMapLayer
	if west_bridge:
		west_bridge.enabled = "west_weight_restored" in Session.flags
	var bridge_art := get_node_or_null("BridgeArt") as CanvasItem
	if bridge_art and room_id in ["bell_weight_chamber", "hanging_gallery"]:
		bridge_art.visible = "east_weight_restored" in Session.flags if room_id == "bell_weight_chamber" else "west_weight_restored" in Session.flags
	for child: Node in $Interactions.get_children():
		var point := child as WorldInteraction
		if challenge_mode:
			point.visible = false
			continue
		point.visible = true
		# Hanging Gallery keeps a preview-only endpoint in the shared authored
		# scene. It must never complete the campaign when the same room is used
		# by the main chapter flow.
		if point.name == "PreviewEnd" and not rehearsal:
			point.visible = false
			continue
		if point.kind == "exit" and point.name == "Return" and room_id in ["heart_chamber", "furnace_core"]:
			point.visible = is_cleared()
		elif point.kind == "exit" and room_id == "terminal_platform" and point.name == "Return":
			point.visible = "bell_warden_defeated" in Session.flags
		elif point.kind == "exit" and point.required_flag == "clear":
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
