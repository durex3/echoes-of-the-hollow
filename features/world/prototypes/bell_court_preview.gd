extends Node2D
## Front-half playtest harness; native rooms are reusable, campaign files are untouched.
const ROOMS := {
	"windworn_steps": preload("res://features/world/rooms/windworn_steps.tscn"),
	"bell_guard_walk": preload("res://features/world/rooms/bell_guard_walk.tscn"),
	"broken_bell_atrium": preload("res://features/world/rooms/broken_bell_atrium.tscn"),
	"echo_cloister": preload("res://features/world/rooms/echo_cloister.tscn"),
	"hanging_gallery": preload("res://features/world/rooms/hanging_gallery.tscn")
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

func _enter_tree() -> void:
	Session.save_path = "user://test_bell_preview_%s.json" % OS.get_process_id()
	Session.settings_path = "user://test_bell_preview_%s.cfg" % OS.get_process_id()
	Session.reset()
	baseline = "--baseline" in OS.get_cmdline_user_args()
	Session.abilities.assign(["double_jump", "dash"] if baseline else ["double_jump", "dash", "steam_ward"])
	if not baseline:
		Session.flags.assign(["heart_bloom"])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$RoomHost.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.died.connect(_retry.call_deferred)
	player.impact.connect($Feedback.show_impact)
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
	room.player = player
	player.position = room.spawn_position(spawn)
	for enemy: Node in room.get_node("Enemies").get_children():
		if id in cleared_rooms:
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
		show_notice("外廊已清，东侧通往安全中庭。" if room.room_id == "bell_guard_walk" else "掠袭已平息。西侧尽头可完成本段试玩，再返回中庭。")

func _refresh() -> void:
	for child: Node in room.get_node("Interactions").get_children():
		var point := child as WorldInteraction
		if point.kind == "ability":
			point.visible = point.stable_id not in Session.abilities
		elif point.kind == "reward":
			point.visible = point.stable_id not in preview_flags
	var gate := room.get_node_or_null("ReturnGate")
	if gate and "wall_passage_open" in preview_flags:
		(gate.get_node("Collision") as CollisionShape2D).set_deferred("disabled", true)
		(gate.get_node("Art") as CanvasItem).hide()

func _interact(point: WorldInteraction) -> void:
	if point.kind == "exit":
		if point.required_flag == "clear" and not room.is_cleared():
			show_notice("先击败外廊两名杖使；西侧仍可退回阶庭。")
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
		if point.stable_id not in preview_flags:
			preview_flags.append(point.stable_id)
			show_notice("上层回闩已开。向右回到中庭上层，西侧可进入悬铃回廊。")
		_refresh()
	elif point.kind == "goal":
		if room.is_cleared():
			finished = true
			show_notice("前半段试玩完成：鸣石、杖使、踏壁回环、铃翼掠袭。\n可以原路回访；双分支奖励与终钟 Boss 尚未开放。",12)
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
