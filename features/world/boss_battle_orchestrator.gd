class_name BossBattleOrchestrator
extends Node

var room: GameRoom
var boss: Node
var hud: Node
var boss_name := "BOSS"
var defeated_callback: Callable

func setup(next_room: GameRoom, next_boss: Node, next_hud: Node, title: String, on_defeated: Callable) -> void:
	room = next_room
	boss = next_boss
	hud = next_hud
	boss_name = title
	defeated_callback = on_defeated
	if boss.has_signal("awakened"): boss.awakened.connect(_on_awakened)
	if boss.has_signal("withdrawn"): boss.withdrawn.connect(_on_withdrawn)
	if boss.has_signal("phase_changed"): boss.phase_changed.connect(_on_phase_changed)
	if boss.has_signal("cue_changed"): boss.cue_changed.connect(_on_cue_changed)
	if boss.has_signal("defeated"): boss.defeated.connect(_on_defeated, CONNECT_DEFERRED)
	var health := boss.get_node_or_null("Health") as HealthComponent
	if health: health.changed.connect(_on_health_changed)

func _on_awakened() -> void:
	if is_instance_valid(hud) and hud.has_method("show_boss"):
		hud.show_boss(boss.health.current, boss.health.maximum, boss_name)

func _on_withdrawn() -> void:
	if is_instance_valid(hud) and hud.has_method("hide_boss"): hud.hide_boss()

func _on_phase_changed(next_phase: int) -> void:
	if is_instance_valid(hud) and hud.has_method("update_boss_phase"): hud.update_boss_phase(next_phase)

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(hud) and hud.has_method("update_boss_health"): hud.update_boss_health(current, maximum)

func _on_cue_changed(message: String) -> void:
	if message.is_empty() or not is_instance_valid(hud) or not hud.has_method("notify"):
		return
	var readable := message
	readable = readable.replace("终钟回响 / 记住旧位置", "金色锚点：离开记录位置")
	readable = readable.replace("逆相残像", "紫蓝分身：看地面线和高位弧")
	readable = readable.replace("镰刀横扫 / 后撤或绕到身后", "红色横扫：后撤或绕后")
	readable = readable.replace("锁向镰突 / 跳过或绕后", "红色突进：跳过或绕后")
	readable = readable.replace("终钟镰斩 / 跳跃、踏壁或举盾", "终结镰斩：跳跃、踏壁或举盾")
	hud.notify(readable)

func _on_defeated() -> void:
	if is_instance_valid(hud) and hud.has_method("hide_boss"): hud.hide_boss()
	if defeated_callback.is_valid(): defeated_callback.call(room.get_instance_id())
