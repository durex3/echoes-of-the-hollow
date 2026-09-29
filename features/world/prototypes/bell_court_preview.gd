extends Node2D
## Front-half playtest harness; native rooms are reusable, campaign files are untouched.
const ROOMS := {
	"windworn_steps": preload("res://features/world/rooms/windworn_steps.tscn"),
	"bell_guard_walk": preload("res://features/world/rooms/bell_guard_walk.tscn"),
	"broken_bell_atrium": preload("res://features/world/rooms/broken_bell_atrium.tscn"),
	"echo_cloister": preload("res://features/world/rooms/echo_cloister.tscn"),
	"hanging_gallery": preload("res://features/world/rooms/hanging_gallery.tscn"),
	"bell_weight_chamber": preload("res://features/world/rooms/bell_weight_chamber.tscn"),
	"quiet_reliquary": preload("res://features/world/rooms/quiet_reliquary.tscn"),
	"confluence_bridge": preload("res://features/world/rooms/confluence_bridge.tscn"),
	"terminal_platform": preload("res://features/world/rooms/terminal_platform.tscn")
}
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var title: Label = $Overlay/Title
@onready var status: Label = $Overlay/Status
@onready var prompt: Label = $Overlay/Prompt
@onready var notice: Label = $Overlay/Notice
var room: GameRoom
var checkpoint_room := "windworn_steps"
var checkpoint_spawn := "entry"
var cleared_rooms: Array[String] = []
var preview_flags: Array[String] = []
var visited: Array[String] = []
var switching := false
var notice_left := 0.0
var finished := false
var map_open := false
var status_text := ""
var baseline := false
var boss_only := false

func _enter_tree() -> void:
	Session.save_path = "user://test_bell_preview_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_bell_preview_%s.cfg" % OS.get_process_id()
	Session.reset()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	boss_only = "--boss" in OS.get_cmdline_user_args()
	Session.abilities.assign(["double_jump", "dash"] if baseline else ["double_jump", "dash", "steam_ward"])
	if not baseline:
		Session.flags.assign(["heart_bloom"])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$RoomHost.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.died.connect(_retry.call_deferred)
	player.impact.connect($Feedback.show_impact)
	if boss_only:
		preview_flags.assign(["east_weight_restored", "west_weight_restored", "wall_passage_open"])
		load_room("terminal_platform", "entry")
		show_notice("第三关 Boss 单独试玩｜进度仅在本次试玩内保留\n按 J 攻击，观察三阶段招式、移动动画和接触碰撞。")
	else:
		load_room("windworn_steps", "entry")
		show_notice("第三关前半段试玩｜进度仅在本次试玩内保留\n先观察阶庭的鸣石，再向东进入守钟外廊。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_tree().paused = not get_tree().paused
		map_open = false
		player.reset_input()
		notice.text = "已暂停 · 再按暂停键继续" if get_tree().paused else ""
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map") and not event.is_echo():
		map_open = not map_open
		get_tree().paused = map_open
		player.reset_input()
		notice.text = "阶庭 ↔ 外廊 ↔ 中庭下层 ↔ 修院\n修院上层 ↔ 中庭上层 ↔ 悬铃回廊\n当前：%s｜刻槽回闩：%s\n再次按地图键返回" % [room.display_name,"已开" if "wall_passage_open" in preview_flags else "未开"] if map_open else ""
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(room) or get_tree().paused:
		return
	if notice_left > 0:
		notice_left -= delta
		if notice_left <= 0:
			notice.text = ""
	var nearest: WorldInteraction
	var distance := 58.0
	for child: Node in room.get_node("Interactions").get_children():
		var point := child as WorldInteraction
		if not point.visible:
			continue
		var separation := point.global_position.distance_to(player.global_position)
		if separation < distance:
			distance = separation
			nearest = point
	prompt.text = "[%s] %s" % [Session.bindings.hint("interact"),nearest.prompt] if nearest else ""
	if not nearest and room.room_id=="echo_cloister" and "wall_echo" in Session.abilities:
		if player.wall_echo.can_jump():
			prompt.text = "已贴墙：点按 [%s] 自动蹬向对墙，不用来回切换方向。" % Session.bindings.hint("jump")
		elif not player.wall_echo.surface_id.is_empty():
			prompt.text = "这面墙已经蹬过；朝另一面刻槽墙移动，或落地再试。"
		else:
			prompt.text = "踏壁：靠近青绿刻槽墙后，连续点按 [%s]；系统帮助你蹬向对墙。" % Session.bindings.hint("jump")
	if nearest and Input.is_action_just_pressed("interact") and not switching and player.state != Player.State.DEAD:
		_interact(nearest)
	var current := "生命 %d/%d  ·  二段跳 / 冲刺  ·  护盾 %s  ·  踏壁 %s" % [player.health.current,player.health.maximum,"未获得" if "steam_ward" not in Session.abilities else ("就绪" if player.steam_ward.cooldown_left <= 0 else "冷却"),"已获得" if "wall_echo" in Session.abilities else "未获得"]
	if current != status_text:
		status_text = current
		status.text = current
	if player.position.y > room.bounds.end.y + 96 and player.state != Player.State.DEAD:
		player.health.take_damage(player.health.maximum, player.position)

func load_room(id: String, spawn: String) -> void:
	if not ROOMS.has(id):
		push_error("Unknown preview room: " + id)
		return
	$Feedback.clear()
	if is_instance_valid(room):
		$RoomHost.remove_child(room)
		room.queue_free()
	player.cancel_dash(true)
	player.reset_input()
	player.velocity = Vector2.ZERO
	room = (ROOMS[id] as PackedScene).instantiate() as GameRoom
	room.enabled = false # Harness owns prompts/interactions; no campaign mutations.
	$RoomHost.add_child(room)
	if id not in visited:
		visited.append(id)
	notice.text = ""
	notice_left = 0.0
	room.player = player
	player.position = room.spawn_position(spawn)
	for enemy: Node in room.get_node("Enemies").get_children():
		if id in cleared_rooms:
			room.get_node("Enemies").remove_child(enemy)
			enemy.queue_free()
		else:
			enemy.target = player
			enemy.defeated.connect(_enemy_defeated)
			enemy.impact.connect($Feedback.show_impact.bind(false))
	camera.limit_left = int(room.bounds.position.x)
	camera.limit_top = int(room.bounds.position.y)
	camera.limit_right = int(room.bounds.end.x)
	camera.limit_bottom = int(room.bounds.end.y)
	camera.reset_smoothing()
	title.text = "失谐钟庭 · " + room.display_name + "  / 前半段试玩"
	_refresh()
	switching = false

func _enemy_defeated() -> void:
	if room.is_cleared():
		if room.room_id not in cleared_rooms:
			cleared_rooms.append(room.room_id)
		if room.room_id == "terminal_platform":
			preview_flags.append("bell_warden_defeated")
			show_notice("缚钟守望者已击败。左侧返程门开放；正式章节结局尚未接入。")
		else:
			show_notice("外廊已清，东侧通往安全中庭。" if room.room_id == "bell_guard_walk" else "掠袭已平息。西侧尽头可完成本段试玩，再返回中庭。")
		_refresh()

func _refresh() -> void:
	for child: Node in room.get_node("Interactions").get_children():
		var point := child as WorldInteraction
		if room.room_id == "terminal_platform" and point.name == "Return":
			point.visible = room.is_cleared()
			continue
		if point.kind == "ability":
			point.visible = point.stable_id not in Session.abilities
		elif point.kind in ["reward", "upgrade"]:
			point.visible = point.stable_id not in preview_flags
	var gate := room.get_node_or_null("ReturnGate")
	if gate and "wall_passage_open" in preview_flags:
		(gate.get_node("Collision") as CollisionShape2D).set_deferred("disabled", true)
		(gate.get_node("Art") as CanvasItem).hide()
	var bridge := room.get_node_or_null("ReturnBridge") as TileMapLayer
	if bridge:
		bridge.enabled = "east_weight_restored" in preview_flags
	var east_art := room.get_node_or_null("BridgeArt") as CanvasItem
	if east_art and room.room_id == "bell_weight_chamber":
		east_art.visible = "east_weight_restored" in preview_flags
	var bridge_collision := room.get_node_or_null("BridgeCollision/Collision") as CollisionShape2D
	if bridge_collision:
		var restored := "east_weight_restored" in preview_flags if room.room_id == "bell_weight_chamber" else "west_weight_restored" in preview_flags
		var bridge_was_closed := bridge_collision.disabled
		bridge_collision.set_deferred("disabled", not restored)
		if restored and bridge_was_closed and room.room_id == "bell_weight_chamber" and is_instance_valid(player):
			if player.global_position.x > 1000.0 and player.global_position.y > 292.0:
				player.global_position = Vector2(976.0, 320.0)
	var west_bridge := room.get_node_or_null("BridgeTerrain") as TileMapLayer
	if west_bridge:
		west_bridge.enabled = "west_weight_restored" in preview_flags
	var west_art := room.get_node_or_null("BridgeArt") as CanvasItem
	if west_art and room.room_id == "hanging_gallery":
		west_art.visible = "west_weight_restored" in preview_flags

func _interact(point: WorldInteraction) -> void:
	if point.kind == "exit":
		if not point.required_ability.is_empty() and point.required_ability not in Session.abilities:
			show_notice("需要踏壁回响才能进入静声藏室。")
			return
		if point.required_flag == "clear" and not room.is_cleared():
			show_notice("先击败外廊两名杖使；西侧仍可退回阶庭。")
			return
		for required: String in point.required_flags:
			if required not in preview_flags:
				show_notice("需要先恢复东西两座承重，中央合鸣桥才会连通。")
				return
		if not point.required_flag.is_empty() and point.required_flag != "clear" and point.required_flag not in preview_flags:
			show_notice("沿刻槽墙到上层，打开修院回闩。")
			return
		switching = true
		load_room.call_deferred(point.target_room,point.target_spawn)
	elif point.kind == "checkpoint":
		checkpoint_room = room.room_id
		checkpoint_spawn = point.checkpoint_spawn
		show_notice("本次试玩的重试位置已记录；生命不变。\n关闭试玩后进度不保留。")
	elif point.kind == "ability":
		if point.stable_id not in Session.abilities:
			Session.unlock(point.stable_id)
			player.health.restore_full()
			Audio.play_sound("ability_acquire")
			show_notice("获得踏壁回响 · 生命恢复\n先靠向青绿刻槽墙，再连续点按 [%s]；系统会帮你蹬向对墙。\n不用来回切方向，稍早或稍晚按也有效。长按不会连跳；宽台可休息。" % Session.bindings.hint("jump"),10)
		_refresh()
	elif point.kind == "reward":
		if not room.is_cleared():
			show_notice("先清理承钟机室，承重装置才安全可操作。")
			return
		if point.stable_id not in preview_flags:
			preview_flags.append(point.stable_id)
			if point.stable_id == "east_weight_restored":
				show_notice("东承重已恢复。上方回桥现在连通中庭；机室西侧可安全返回。")
			elif point.stable_id == "west_weight_restored":
				show_notice("西承重已恢复。上方回桥现在连通中庭；回廊东侧可安全返回。")
			else:
				show_notice("上层回闩已开。向右回到中庭上层，西侧可进入悬铃回廊。")
		_refresh()
	elif point.kind == "upgrade":
		if point.stable_id == "bell_heart" and point.stable_id not in preview_flags:
			preview_flags.append(point.stable_id)
			Session.set_flag("bell_heart")
			player.health.maximum = Session.maximum_health()
			player.health.restore_full()
			Audio.play_sound("ability_acquire")
			show_notice("获得钟庭之心 · 最大生命 +1 · 生命恢复\n这是本次试玩的唯一生命上限奖励。", 10)
		_refresh()
	elif point.kind == "goal":
		if room.is_cleared():
			finished = true
			show_notice("前半段试玩完成：双承重回桥、钟庭之心、合鸣桥廊。\n可以原路回访；终钟 Boss 与正式章节存档尚未开放。",12)
		else:
			show_notice("悬铃回廊还有掠食者。")
	else:
		show_notice(point.prompt)

func show_notice(message: String, seconds := 7.0) -> void:
	notice.text = message
	notice_left = seconds

func _retry() -> void:
	# Death separately heals, while memory checkpoints never do.
	cleared_rooms.erase(checkpoint_room)
	load_room(checkpoint_room,checkpoint_spawn)
	player.revive(room.spawn_position(checkpoint_spawn))
	show_notice("已回到本次试玩的重试点。")
