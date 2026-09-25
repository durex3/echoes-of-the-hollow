extends Node2D

const PLAYER_SCENE := preload("res://features/player/player.tscn")
const ROOMS := {
	"forest": preload("res://features/world/rooms/forest.tscn"),
	"ruins": preload("res://features/world/rooms/ruins.tscn"),
	"training": preload("res://features/world/rooms/training.tscn"),
	"scriptorium": preload("res://features/world/rooms/scriptorium.tscn"),
	"sanctuary": preload("res://features/world/rooms/sanctuary.tscn"),
	"wind_hall": preload("res://features/world/rooms/wind_hall.tscn"),
	"belfry": preload("res://features/world/rooms/belfry.tscn")
}
const Repository := preload("res://core/save_repository.gd")
@onready var room_host: Node2D = $RoomHost
@onready var camera: Camera2D = $Camera
@onready var ui: GameUI = $UI
var player: Player
var room: GameRoom
var running := false
var transition_pending := false
var map_return_paused := false
var map_return_menu := "pause"

func _ready() -> void:
	ui.start_requested.connect(start_game)
	ui.resume_requested.connect(resume)
	ui.map_closed.connect(close_map)
	ui.quit_requested.connect(func() -> void: get_tree().quit())
	Session.progress_changed.connect(ui.update_progress)
	ui.show_menu("title", not Repository.read(Session.save_path).is_empty())
	if "--smoke" in OS.get_cmdline_user_args():
		Session.save_path = "user://smoke_progress.json"
		start_game(false)

func start_game(load_save: bool) -> void:
	Session.reset()
	if load_save and not Session.restore():
		ui.notify("Save unavailable. Starting a new journey.")
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health.changed.connect(ui.update_health)
	player.died.connect(_on_player_died)
	player.impact.connect($Feedback.show_impact)
	running = true
	load_room(Session.checkpoint_room, Session.checkpoint_spawn)
	ui.show_hud()
	ui.update_health(player.health.current, player.health.maximum)
	ui.update_progress()

func load_room(room_id: String, spawn: String) -> void:
	if not ROOMS.has(room_id):
		push_error("Unknown room: " + room_id)
		return
	$Feedback.clear()
	player.cancel_dash()
	player.cancel_attack()
	if player.state == Player.State.ATTACK:
		player.state = Player.State.MOVE
	if is_instance_valid(room):
		room_host.remove_child(room)
		room.queue_free()
	room = (ROOMS[room_id] as PackedScene).instantiate() as GameRoom
	room_host.add_child(room)
	room.player = player
	room.interaction_requested.connect(_on_interaction)
	room.gate_breached.connect(_on_gate_breached)
	room.projectile_impact.connect($Feedback.show_impact.bind(false))
	room.prompt_changed.connect(func(message: String) -> void: ui.set_text(ui.prompt,message))
	room.update_progress()
	for enemy: Node in room.get_node("Enemies").get_children():
		if enemy is DoomScribe:
			enemy.target = player
		if enemy is LivingArmor:
			enemy.target = player
			# Player damage already owns its sound; the enemy event adds visuals.
			enemy.impact.connect($Feedback.show_impact.bind(false))
	player.global_position = room.spawn_position(spawn)
	player.velocity = Vector2.ZERO
	Session.visit(room_id)
	camera.limit_left = int(room.bounds.position.x)
	camera.limit_top = int(room.bounds.position.y)
	camera.limit_right = int(room.bounds.end.x)
	camera.limit_bottom = int(room.bounds.end.y)
	camera.position = player.position - Vector2(0, 65)
	camera.reset_smoothing()
	ui.set_text(ui.area_label,room.display_name)
	ui.set_text(ui.prompt,"")
	Audio.play_music(room.music_track)
	transition_pending = false

func _process(_delta: float) -> void:
	if running and is_instance_valid(player):
		camera.position = player.position + Vector2(player.facing * 45, -65)

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("mute"):
		Audio.toggle_mute()
	if event.is_action_pressed("world_map") and running and player.state != Player.State.DEAD:
		if ui.map_panel.visible:
			close_map()
		else:
			map_return_paused = get_tree().paused
			map_return_menu = ui.menu_mode
			player.reset_input()
			get_tree().paused = true
			ui.show_map(room.room_id)
		return
	if event.is_action_pressed("pause") and running:
		if ui.map_panel.visible:
			close_map()
			return
		if get_tree().paused:
			resume()
		else:
			player.reset_input()
			get_tree().paused = true
			ui.show_menu("pause")

func resume() -> void:
	player.reset_input()
	ui.hide_map()
	get_tree().paused = false
	ui.show_hud()

func close_map() -> void:
	ui.hide_map()
	player.reset_input()
	if map_return_paused:
		get_tree().paused = true
		ui.show_menu(map_return_menu)
	else:
		resume()

func _on_interaction(point: WorldInteraction) -> void:
	if transition_pending:
		return
	match point.kind:
		"exit":
			if not point.required_ability.is_empty() and point.required_ability not in Session.abilities:
				ui.notify("The high roots answer only to the sky echo")
				return
			if not point.required_flag.is_empty() and point.required_flag not in Session.flags:
				ui.notify("Clear this hall and claim its seal first")
				return
			transition_pending = true
			load_room.call_deferred(point.target_room, point.target_spawn)
		"checkpoint":
			Session.checkpoint_room = room.room_id
			Session.checkpoint_spawn = point.checkpoint_spawn
			player.health.restore_full()
			_save("Restored & saved")
		"ability":
			if point.stable_id in Session.abilities:
				return
			Session.unlock(point.stable_id)
			room.update_progress()
			Audio.play_sound("ability_acquire")
			_save_reward(point.stable_id)
		"upgrade":
			if point.stable_id != "heart_bloom" or point.stable_id in Session.flags:
				return
			Session.set_flag(point.stable_id)
			player.health.maximum = Session.maximum_health()
			player.health.restore_full()
			room.update_progress()
			_save_reward(point.stable_id)
		"reward":
			if point.stable_id in Session.flags:
				return
			if not room.is_cleared():
				ui.notify("Defeat the hall guardians to release the seal")
				return
			Session.set_flag(point.stable_id)
			player.health.restore_full()
			room.update_progress()
			_save_reward(point.stable_id)
		"goal":
			if not Session.abilities.has("double_jump"):
				ui.notify("The shrine awaits an echo from the eastern ruins")
				return
			Session.completed = true
			Session.progress_changed.emit()
			room.update_progress()
			_save("The grove remembers. Journey complete.")
			get_tree().paused = true
			ui.show_menu("win")

func _save(message: String) -> void:
	if Session.commit() == OK:
		ui.notify(message)
		Audio.play_sound("save")
	else:
		ui.notify("Save failed / Progress remains in this session")

func _save_reward(stable_id: String) -> void:
	var saved := Session.commit() == OK
	ui.reward_notice.present(stable_id,saved)
	ui.set_text(ui.toast,"")
	ui.toast_left = 0
	if saved:
		Audio.play_sound("save")

func _on_gate_breached(stable_id: String) -> void:
	Session.set_flag(stable_id)
	_save("Wind barrier opened / Route saved")

func _on_player_died() -> void:
	room.enabled = false
	room.clear_projectiles()
	ui.notify("Returning to the last shrine...")
	await get_tree().create_timer(0.85, false).timeout
	load_room(Session.checkpoint_room, Session.checkpoint_spawn)
	player.revive(room.spawn_position(Session.checkpoint_spawn))
