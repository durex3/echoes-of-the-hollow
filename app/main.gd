extends Node2D

const PLAYER_SCENE := preload("res://features/player/player.tscn")
const ROOMS := {
	"forest": preload("res://features/world/rooms/forest.tscn"),
	"ruins": preload("res://features/world/rooms/ruins.tscn"),
	"training": preload("res://features/world/rooms/training.tscn"),
	"scriptorium": preload("res://features/world/rooms/scriptorium.tscn"),
	"sanctuary": preload("res://features/world/rooms/sanctuary.tscn"),
	"wind_hall": preload("res://features/world/rooms/wind_hall.tscn"),
	"belfry": preload("res://features/world/rooms/belfry.tscn"),
	"atrium": preload("res://features/world/rooms/atrium.tscn"),
	"heart_chamber": preload("res://features/world/rooms/heart_chamber.tscn"),
	"ember_quay": preload("res://features/world/rooms/ember_quay.tscn"),
	"valve_gallery": preload("res://features/world/rooms/valve_gallery.tscn"),
	"cistern_archive": preload("res://features/world/rooms/cistern_archive.tscn"),
	"furnace_core": preload("res://features/world/rooms/furnace_core.tscn"),
	"sluice_shaft": preload("res://features/world/rooms/sluice_shaft.tscn"),
	"pump_chamber": preload("res://features/world/rooms/pump_chamber.tscn"),
	"echo_vault": preload("res://features/world/rooms/echo_vault.tscn"),
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
var boss_challenge := 0

func _ready() -> void:
	if get_parent() == get_tree().root:
		Session.apply_display()
	ui.start_requested.connect(start_game)
	ui.challenge_requested.connect(start_boss_challenge)
	ui.title_requested.connect(return_to_title)
	ui.resume_requested.connect(resume)
	ui.map_closed.connect(close_map)
	ui.quit_requested.connect(func() -> void: get_tree().quit())
	Session.progress_changed.connect(ui.update_progress)
	ui.show_menu("title", not Repository.read(Session.save_path).is_empty())
	if "--smoke" in OS.get_cmdline_user_args():
		Session.save_path = "user://smoke_progress.json"
		start_game(false)

func start_game(load_save: bool) -> void:
	boss_challenge = 0
	Session.reset()
	if load_save and not Session.restore():
		ui.notify("Save unavailable. Starting a new journey.")
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health.changed.connect(ui.update_health)
	player.dash_status_changed.connect(ui.update_dash_status)
	player.steam_ward.status_changed.connect(ui.update_ward_status)
	player.died.connect(_on_player_died)
	player.impact.connect($Feedback.show_impact)
	running = true
	load_room(Session.checkpoint_room, Session.checkpoint_spawn)
	ui.show_hud()
	ui.update_health(player.health.current, player.health.maximum)
	ui.update_progress()

func start_boss_challenge(chapter: int) -> void:
	if chapter not in [1, 2, 3]:
		return
	get_tree().paused = false
	ui.hide_map()
	if is_instance_valid(room):
		room_host.remove_child(room)
		room.queue_free()
	room = null
	if is_instance_valid(player):
		player.queue_free()
	Session.reset()
	Session.unlock("double_jump")
	Session.unlock("dash")
	if chapter >= 2:
		# Chapter II and III practice starts after the first chapter's permanent vitality reward.
		Session.set_flag("heart_bloom")
		Session.unlock("steam_ward")
	boss_challenge = chapter
	ui.challenge_chapter = chapter
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health.changed.connect(ui.update_health)
	player.dash_status_changed.connect(ui.update_dash_status)
	player.steam_ward.status_changed.connect(ui.update_ward_status)
	player.died.connect(_on_player_died)
	player.impact.connect($Feedback.show_impact)
	running = true
	load_room({1: "heart_chamber", 2: "furnace_core", 3: "terminal_platform"}[chapter], "entry", true)
	ui.show_hud()
	ui.update_health(player.health.current, player.health.maximum)
	ui.update_progress()
	ui.set_text(ui.objective,"Defeat the boss")

func return_to_title() -> void:
	get_tree().paused = false
	ui.hide_map()
	$Feedback.clear()
	ui.hide_boss()
	if is_instance_valid(room):
		room_host.remove_child(room)
		room.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	room = null
	player = null
	running = false
	boss_challenge = 0
	ui.challenge_chapter = 0
	Session.reset()
	Session.restore()
	ui.hud.hide()
	ui.show_menu("title", not Repository.read(Session.save_path).is_empty())

func load_room(room_id: String, spawn: String, rehearsal := false) -> void:
	if not ROOMS.has(room_id):
		push_error("Unknown room: " + room_id)
		return
	$Feedback.clear()
	ui.hide_boss()
	player.cancel_dash(true)
	player.steam_ward.cancel()
	player.cancel_attack()
	if player.state == Player.State.ATTACK:
		player.state = Player.State.MOVE
	if is_instance_valid(room):
		room_host.remove_child(room)
		room.queue_free()
	room = (ROOMS[room_id] as PackedScene).instantiate() as GameRoom
	room.rehearsal = rehearsal
	room.challenge_mode = boss_challenge != 0
	room_host.add_child(room)
	room.player = player
	room.interaction_requested.connect(_on_interaction)
	room.gate_breached.connect(_on_gate_breached)
	room.projectile_impact.connect($Feedback.show_impact.bind(false))
	room.prompt_changed.connect(func(message: String) -> void: ui.set_text(ui.prompt,message))
	room.update_progress()
	var boss_orchestrator := room.get_node_or_null("BossBattleOrchestrator") as BossBattleOrchestrator
	if boss_orchestrator:
		boss_orchestrator.setup(room, player, ui)
		boss_orchestrator.impact.connect($Feedback.show_impact.bind(false))
		match room_id:
			"heart_chamber": boss_orchestrator.boss_defeated.connect(_on_warden_defeated)
			"furnace_core": boss_orchestrator.boss_defeated.connect(_on_keeper_defeated)
			"terminal_platform": boss_orchestrator.boss_defeated.connect(_on_bell_warden_defeated)
	for enemy: Node in room.get_node("Enemies").get_children():
		if enemy is WingedChest or enemy is RoseSentinel:
			enemy.target = player
			enemy.impact.connect($Feedback.show_impact.bind(false))
		if enemy is DoomScribe:
			enemy.target = player
		if enemy is LivingArmor:
			enemy.target = player
			# Player damage already owns its sound; the enemy event adds visuals.
			enemy.impact.connect($Feedback.show_impact.bind(false))
		if enemy is BellInvoker or enemy is BellSkimmer:
			enemy.target = player
			enemy.impact.connect($Feedback.show_impact.bind(false))
			enemy.defeated.connect(_on_chapter_three_enemy_defeated.bind(room.get_instance_id()), CONNECT_DEFERRED)
	player.global_position = room.spawn_position(spawn)
	player.velocity = Vector2.ZERO
	Session.visit(room_id)
	camera.limit_left = int(room.bounds.position.x)
	camera.limit_top = int(room.bounds.position.y)
	camera.limit_right = int(room.bounds.end.x)
	camera.limit_bottom = int(room.bounds.end.y)
	camera.zoom = Vector2(1.4,1.4)
	if room_id == "heart_chamber":
		camera.position = Vector2(320,396)
	elif room_id == "furnace_core":
		camera.position = Vector2(860,330)
	else:
		camera.position = player.position - Vector2(0,65)
	camera.reset_smoothing()
	ui.set_text(ui.area_label,room.display_name)
	ui.set_text(ui.prompt,"")
	Audio.play_music(room.music_track)
	transition_pending = false

func _process(_delta: float) -> void:
	if running and is_instance_valid(player):
		camera.zoom = Vector2(1.4,1.4)
		if room.room_id == "heart_chamber":
			camera.position = Vector2(320,396)
		elif room.room_id == "furnace_core":
			camera.position = Vector2(860,330)
		else:
			camera.position = player.position + Vector2(player.facing * 45, -65)

func _input(event: InputEvent) -> void:
	Session.bindings.observe(event)
	if ui.confirmation.visible:
		return
	if ui.settings_panel.visible:
		var capturing := not ui.settings_panel.capture_action.is_empty()
		ui.settings_panel.handle_input(event)
		if capturing or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event.is_action_pressed("mute"):
		Audio.toggle_mute()
	if event.is_action_pressed("world_map") and running and boss_challenge == 0 and player.state != Player.State.DEAD:
		if ui.map_panel.visible:
			close_map()
		else:
			map_return_paused = get_tree().paused
			map_return_menu = ui.menu_mode
			player.reset_input()
			get_tree().paused = true
			ui.show_map(room.room_id,room.nearby_exit_target())
		return
	if event.is_action_pressed("pause") and running:
		if ui.menu_mode in ["challenge_complete", "challenge_select"] and ui.modal.visible:
			return
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
	if ui.menu_mode == "chapter_two" and room.room_id == "furnace_core":
		var resume_spawn := "chapter_three_return" if "cistern_restored" in Session.flags and "furnace_keeper_defeated" in Session.flags else "core_return"
		load_room("ember_quay", resume_spawn)
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
	if boss_challenge != 0:
		return
	match point.kind:
		"challenge":
			if room.room_id == "furnace_core" and not room.rehearsal and "furnace_keeper_defeated" in Session.flags:
				player.revive(room.spawn_position("entry"))
				load_room.call_deferred("furnace_core","entry",true)
				transition_pending = true
				ui.notify("Practice battle / Your completed journey is preserved")
		"exit":
			if room._boss_exit_locked(point):
				return
			var locked := point.locked_message(Session.abilities,Session.flags)
			if not locked.is_empty():
				ui.notify(locked)
				return
			if point.target_room == "heart_chamber" and room.room_id == "atrium":
				Session.checkpoint_room = "atrium"
				Session.checkpoint_spawn = "checkpoint"
				_save("Progress saved")
			if point.target_room == "furnace_core" and room.room_id == "ember_quay":
				Session.checkpoint_room = "ember_quay"
				Session.checkpoint_spawn = "checkpoint"
				_save("Progress saved")
			if point.target_room == "windworn_steps" and room.room_id == "ember_quay":
				# The first third-chapter entry becomes the new safe retry point. Keeping
				# the old quay checkpoint here sent deaths and reloads back across the
				# chapter boundary even after the player had entered the Bell Court.
				Session.checkpoint_room = "windworn_steps"
				Session.checkpoint_spawn = "entry"
				_save("Progress saved / Chapter III opened")
			if point.target_room == "terminal_platform" and room.room_id == "confluence_bridge":
				Session.checkpoint_room = "terminal_platform"
				Session.checkpoint_spawn = "checkpoint"
				_save("Boss approach saved")
			if point.target_room == "ember_quay" and room.room_id == "heart_chamber" and "journey_restored" not in Session.flags:
				Session.set_flag("journey_restored")
				room.update_progress()
				_save("Final echo restored / Chapter II opened")
			transition_pending = true
			load_room.call_deferred(point.target_room, point.target_spawn)
		"checkpoint":
			Session.checkpoint_room = room.room_id
			Session.checkpoint_spawn = point.checkpoint_spawn
			_save("Progress saved")
		"ability":
			if point.stable_id in Session.abilities:
				return
			Session.unlock(point.stable_id)
			if point.stable_id == "steam_ward":
				player.health.restore_full()
			room.update_progress()
			Audio.play_sound("ability_acquire")
			_save_reward(point.stable_id)
		"upgrade":
			if point.stable_id not in ["heart_bloom", "bell_heart"] or point.stable_id in Session.flags:
				return
			Session.set_flag(point.stable_id)
			player.health.maximum = Session.maximum_health()
			player.health.restore_full()
			room.update_progress()
			_save_reward(point.stable_id)
		"reward", "chapter_end":
			if point.kind == "chapter_end" and room.room_id == "furnace_core" and (not room.is_cleared() or "furnace_keeper_defeated" not in Session.flags):
				return
			if point.stable_id in Session.flags:
				if point.kind == "chapter_end" and room.room_id == "furnace_core":
					transition_pending = true
					load_room.call_deferred("ember_quay", "core_return")
				return
			if not room.is_cleared():
				ui.notify("Defeat the hall guardians to release the seal")
				return
			if point.kind == "chapter_end" and room.room_id == "furnace_core":
				Session.checkpoint_room = "ember_quay"
				Session.checkpoint_spawn = "chapter_three_return"
			Session.set_flag(point.stable_id)
			player.health.restore_full()
			room.update_progress()
			_save_reward(point.stable_id)
			if point.kind == "chapter_end":
				player.reset_input()
				get_tree().paused = true
				ui.finale_saved = ui.reward_notice.save_succeeded
				ui.show_menu("chapter_two")
		"finale":
			if "warden_defeated" not in Session.flags or "journey_restored" in Session.flags or not room.is_cleared():
				return
			Session.set_flag("journey_restored")
			room.update_progress()
			var saved := Session.commit() == OK
			player.reset_input()
			get_tree().paused = true
			ui.finale_saved = saved
			ui.show_menu("finale")
		"goal":
			if room.room_id == "terminal_platform":
				if "bell_warden_defeated" not in Session.flags:
					return
				if "bell_court_restored" in Session.flags:
					return
				Session.set_flag("bell_court_restored")
				Session.completed = true
				Session.progress_changed.emit()
				room.update_progress()
				_save("钟庭复苏 / Chapter III complete")
				get_tree().paused = true
				ui.show_menu("win")
				return
			if not Session.abilities.has("double_jump"):
				ui.notify("The shrine awaits an echo from the eastern ruins")
				return
			Session.completed = true
			Session.progress_changed.emit()
			room.update_progress()
			_save("The grove remembers. Seek the three marks.")
			get_tree().paused = true
			ui.show_menu("high_shrine")

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
	var fallen_player := player
	var fallen_room := room
	ui.hide_boss()
	room.enabled = false
	room.clear_projectiles()
	for enemy: Node in room.get_node("Enemies").get_children():
		if enemy is FurnaceKeeper:
			enemy.clear_flames()
	ui.notify("Returning to the last shrine...")
	await get_tree().create_timer(0.85, false).timeout
	if player != fallen_player or room != fallen_room or not is_instance_valid(player) or not is_instance_valid(room):
		return
	if boss_challenge != 0:
		load_room({1: "heart_chamber", 2: "furnace_core", 3: "terminal_platform"}[boss_challenge], "entry", true)
		player.revive(room.spawn_position("entry"))
		return
	load_room(Session.checkpoint_room, Session.checkpoint_spawn)
	player.revive(room.spawn_position(Session.checkpoint_spawn))

func _on_warden_defeated(room_instance: int) -> void:
	if not is_instance_valid(room) or room.get_instance_id() != room_instance or player.state == Player.State.DEAD or "warden_defeated" in Session.flags:
		return
	if boss_challenge != 0:
		_finish_boss_challenge()
		return
	Session.set_flag("warden_defeated")
	ui.hide_boss()
	room.update_progress()
	player.health.restore_full()
	_save_reward("warden_defeated")
	Audio.play_sound("ability_acquire", 0.8, -2.0)

func _on_keeper_defeated(room_instance: int) -> void:
	if not is_instance_valid(room) or room.get_instance_id() != room_instance or player.state == Player.State.DEAD:
		return
	if boss_challenge != 0:
		_finish_boss_challenge()
		return
	ui.hide_boss()
	player.health.restore_full()
	if room.rehearsal:
		room.update_progress()
		ui.notify("Practice complete / Your journey is unchanged")
		return
	if "furnace_keeper_defeated" in Session.flags:
		return
	Session.set_flag("furnace_keeper_defeated")
	room.update_progress()
	_save_reward("furnace_keeper_defeated")

func _on_chapter_three_enemy_defeated(room_instance: int) -> void:
	if is_instance_valid(room) and room.get_instance_id() == room_instance:
		if room.is_cleared():
			var clear_flag: String = {"bell_guard_walk":"bell_guard_cleared", "bell_weight_chamber":"bell_weight_cleared", "hanging_gallery":"hanging_gallery_cleared", "confluence_bridge":"confluence_bridge_cleared"}.get(room.room_id, "")
			if not clear_flag.is_empty() and clear_flag not in Session.flags:
				Session.set_flag(clear_flag)
				_save("Hall cleared / Route saved")
		room.update_progress()

func _on_bell_warden_defeated(room_instance: int) -> void:
	if not is_instance_valid(room) or room.get_instance_id() != room_instance or player.state == Player.State.DEAD:
		return
	if boss_challenge != 0:
		_finish_boss_challenge()
		return
	ui.hide_boss()
	if "bell_warden_defeated" in Session.flags:
		return
	Session.set_flag("bell_warden_defeated")
	room.update_progress()
	player.health.restore_full()
	_save_reward("bell_warden_defeated")

func _finish_boss_challenge() -> void:
	ui.hide_boss()
	player.health.restore_full()
	player.reset_input()
	get_tree().paused = true
	ui.show_menu("challenge_complete")
