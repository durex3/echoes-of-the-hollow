extends Node2D
## Standalone F6 design preview. No campaign access, save writes, or main-menu link.

@onready var player: Player = $Player
@onready var ability: WorldInteraction = $Ability
@onready var latch: WorldInteraction = $UpperLatch
@onready var gate_shape: CollisionShape2D = $ReturnGate/Collision
@onready var gate_art: Polygon2D = $ReturnGate/Art
@onready var hud: Label = $Overlay/Panel/Label
var shortcut_open := false
var loop_completed := false
var last_hint := ""

func _enter_tree() -> void:
	Session.save_path = "user://test_echo_cloister_preview_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_echo_cloister_preview_%s.cfg" % OS.get_process_id()
	Session.reset()
	Session.abilities.assign(["double_jump", "dash", "steam_ward"])
	Session.flags.assign(["heart_bloom"])

func _ready() -> void:
	player.died.connect(func() -> void: player.revive.call_deferred(Vector2(96, 704)))

func _physics_process(_delta: float) -> void:
	var message := "从下方进入刻槽竖井，先沿右墙起跳，再向两面墙交替蹬跳。"
	var near_ability := player.position.distance_to(ability.position) < 64.0
	var near_latch := player.position.distance_to(latch.position) < 64.0
	if "wall_echo" not in Session.abilities:
		message = "先到起点旁的回响处，按 %s 领取踏壁回响。" % Session.bindings.hint("interact")
		if near_ability and Input.is_action_just_pressed("interact"):
			Session.unlock("wall_echo")
			ability.hide()
			player.health.restore_full()
			Audio.play_sound("ability_acquire")
	elif not shortcut_open and near_latch:
		message = "按 %s 打开上层回闩，向左步行返回起点。" % Session.bindings.hint("interact")
		if Input.is_action_just_pressed("interact"):
			shortcut_open = true
			gate_shape.set_deferred("disabled", true)
			gate_art.hide()
			latch.hide()
	elif shortcut_open:
		message = "左侧回闩已开：从上层走回下层，失足会落在安全地面。"
		if player.position.x < 224.0 and player.is_on_floor() and player.position.y > 680.0:
			loop_completed = true
	if loop_completed:
		message = "完成：领奖 → 交替壁跃 → 上层开闩 → 从新路返回。"
	var text := "第三关 · 回音修院白盒｜不写入玩家存档\n%s\n靠近刻槽墙后连续点按 %s，系统辅助蹬向对墙；不用来回切方向。" % [message, Session.bindings.hint("jump")]
	if text != last_hint:
		last_hint = text
		hud.text = text
