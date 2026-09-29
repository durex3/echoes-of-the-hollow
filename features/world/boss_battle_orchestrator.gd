class_name BossBattleOrchestrator
extends Node

signal boss_defeated(room_instance: int)
signal impact(at: Vector2, killed: bool)

@export var boss_path: NodePath
@export var boss_name := "BOSS"
@export var deactivate_vents_on_awaken := false

var room: GameRoom
var boss: Node
var hud: Node
var player: Player

func setup(next_room: GameRoom, next_player: Player, next_hud: Node) -> void:
	room = next_room
	player = next_player
	hud = next_hud
	boss = room.get_node_or_null(boss_path)
	if not is_instance_valid(boss):
		return
	boss.set("target", player)
	if boss.has_signal("awakened"): boss.awakened.connect(_on_awakened)
	if boss.has_signal("withdrawn"): boss.withdrawn.connect(_on_withdrawn)
	if boss.has_signal("defeated"): boss.defeated.connect(_on_defeated, CONNECT_DEFERRED)
	if boss.has_signal("impact"): boss.impact.connect(_on_impact)
	var health := boss.get_node_or_null("Health") as HealthComponent
	if health: health.changed.connect(_on_health_changed)

func _on_awakened() -> void:
	if deactivate_vents_on_awaken:
		for vent: Node in room.get_node("Hazards").get_children():
			if vent is SteamVent:
				vent.deactivate()
	if is_instance_valid(hud) and hud.has_method("show_boss"):
		hud.show_boss(boss.health.current, boss.health.maximum, boss_name)

func _on_withdrawn() -> void:
	if is_instance_valid(hud) and hud.has_method("hide_boss"): hud.hide_boss()

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(hud) and hud.has_method("update_boss_health"): hud.update_boss_health(current, maximum)

func _on_impact(at: Vector2, killed: bool) -> void:
	impact.emit(at, killed)

func _on_defeated() -> void:
	if not is_instance_valid(room) or not is_instance_valid(boss) or not is_instance_valid(player) or player.state == Player.State.DEAD:
		return
	if is_instance_valid(hud) and hud.has_method("hide_boss"): hud.hide_boss()
	boss_defeated.emit(room.get_instance_id())
