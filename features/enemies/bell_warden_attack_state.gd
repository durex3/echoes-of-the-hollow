class_name BellWardenAttackState
extends BossAttackState

const ECHO_CLONE := preload("res://features/enemies/bell_warden_echo_clone.gd")
const RESONANCE := preload("res://features/enemies/bell_warden_resonance.gd")
const GHOST_SHEET := preload("res://assets/characters/bell_warden_sheet.png")
var recorded: Array[Vector2] = []
var hazards: Array[Node2D] = []
var layer_locked := false
var swap_target := Vector2.ZERO
var swap_cue: Sprite2D
var record_clock := 0.0

func _init(id := 0, label := "", cooldown_seconds := 0.0) -> void:
	attack_id = id
	name_id = label
	cooldown = cooldown_seconds

func enter() -> void:
	super.enter()
	recorded.clear()
	layer_locked = false
	swap_target = Vector2.ZERO
	record_clock = 0.0
	_begin_phase(BellWarden.State.WINDUP)

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var boss := host as BellWarden
	if attack_id == BellWarden.Attack.DOUBLE_ECHO:
		_update_echo(boss)
		return
	if attack_id == BellWarden.Attack.LAYER_RESONANCE:
		_update_resonance(boss)
		return
	match boss.state:
		BellWarden.State.WINDUP:
			if boss.timer <= 0.0:
				_begin_phase(BellWarden.State.STRIKE)
		BellWarden.State.STRIKE:
			if attack_id == BellWarden.Attack.DASH:
				boss.velocity.x = boss.facing * boss.config.dash_speed
			if boss.timer <= 0.0 or (attack_id == BellWarden.Attack.DASH and (boss.is_on_wall() or boss.global_position.x <= boss.config.arena_min_x or boss.global_position.x >= boss.config.arena_max_x)):
				_begin_phase(BellWarden.State.RECOVER)
		BellWarden.State.RECOVER:
			boss.velocity.x = move_toward(boss.velocity.x, -boss.facing * boss.config.recovery_retreat_speed, 1500.0 * delta)
			if boss.timer <= 0.0:
				machine.finish()
				boss._enter(BellWarden.State.CHASE)

func exit() -> void:
	(host as BellWarden).attack_box.end_swing()
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	hazards.clear()
	if is_instance_valid(swap_cue):
		swap_cue.queue_free()
	swap_cue = null
	super.exit()

func _begin_phase(next: BellWarden.State) -> void:
	var boss := host as BellWarden
	boss.state = next
	boss.action_elapsed = 0.0
	boss.velocity.x = 0.0
	boss.attack_box.end_swing()
	match next:
		BellWarden.State.WINDUP:
			boss.timer = boss.config.double_echo_record_gap * 2.0 if attack_id == BellWarden.Attack.DOUBLE_ECHO else boss.config.resonance_charge if attack_id == BellWarden.Attack.LAYER_RESONANCE else boss.config.sweep_windup if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_windup
			if attack_id in [BellWarden.Attack.DOUBLE_ECHO, BellWarden.Attack.LAYER_RESONANCE]:
				boss.contact_box.end_swing()
				boss.cue_changed.emit("双重回响" if attack_id == BellWarden.Attack.DOUBLE_ECHO else "楼层共振")
				boss._spawn_burst(boss.global_position + Vector2(0.0, -36.0), Color("b9d9ff") if attack_id == BellWarden.Attack.DOUBLE_ECHO else Color("f4d49a"), 34.0, 0.28, 2, 8)
				Audio.play_sound("ability_acquire", 0.78, -7.0)
				return
			boss.attack_box.position.x = boss.facing * (34.0 if attack_id == BellWarden.Attack.SWEEP else 42.0)
			boss.attack_box.damage = boss.config.sweep_damage if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_damage
			boss.attack_box.begin_swing()
			boss.cue_changed.emit("横扫蓄势" if attack_id == BellWarden.Attack.SWEEP else "突进蓄势")
		BellWarden.State.STRIKE:
			boss.timer = boss._active()
			boss.contact_box.begin_swing()
			boss.attack_box.active = attack_id in [BellWarden.Attack.SWEEP, BellWarden.Attack.DASH]
		BellWarden.State.RECOVER:
			boss.timer = boss.config.double_echo_recovery if attack_id == BellWarden.Attack.DOUBLE_ECHO else boss.config.resonance_recovery_seconds if attack_id == BellWarden.Attack.LAYER_RESONANCE else boss.config.sweep_recovery if attack_id == BellWarden.Attack.SWEEP else boss.config.dash_recovery
			boss.contact_box.begin_swing()
			boss.cue_changed.emit("反击窗口")

func _update_echo(boss: BellWarden) -> void:
	if boss.state == BellWarden.State.WINDUP:
		if boss.target.is_on_floor() and boss.action_elapsed >= record_clock and recorded.size() < 2:
			var landing := boss.target.global_position
			if not recorded.is_empty() and recorded[0].distance_to(landing) < 72.0:
				landing = _adjacent_echo_position(boss, recorded[0], landing)
			recorded.append(landing)
			record_clock = boss.action_elapsed + boss.config.double_echo_record_gap
		if boss.timer <= 0.0:
			if recorded.is_empty():
				recorded.append(boss.target.global_position)
			if recorded.size() == 1:
				recorded.append(_adjacent_echo_position(boss, recorded[0], boss.target.global_position))
			for index in range(mini(2, recorded.size())):
				var mark := ECHO_CLONE.new() as BellWardenEchoClone
				mark.delay_seconds = boss.config.double_echo_warning + float(index) * boss.config.double_echo_record_gap
				mark.active_seconds = boss.config.double_echo_active
				mark.damage = boss.config.double_echo_damage
				mark.player = boss.target
				mark.facing = -1.0 if boss.target.global_position.x < recorded[index].x else 1.0
				boss.get_parent().add_child(mark)
				mark.global_position = recorded[index]
				hazards.append(mark)
			_begin_phase(BellWarden.State.STRIKE)
	elif boss.state == BellWarden.State.STRIKE:
		if boss.timer <= 0.32 and not is_instance_valid(swap_cue):
			var candidate := recorded[recorded.size() - 1]
			if candidate.y >= 295.0 and candidate.x >= boss.config.arena_min_x + 35.0 and candidate.x <= boss.config.arena_max_x - 35.0 and candidate.distance_to(boss.target.global_position) >= 85.0 and candidate.distance_to(boss.global_position) >= 95.0:
				swap_target = candidate
				swap_cue = Sprite2D.new()
				swap_cue.texture = GHOST_SHEET
				swap_cue.region_enabled = true
				swap_cue.region_rect = Rect2(0, 93, 140, 93)
				swap_cue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				swap_cue.scale = boss.body_sprite.scale
				swap_cue.modulate = Color(1.0, 0.32, 0.78, 0.95)
				swap_cue.z_index = 8
				boss.get_parent().add_child(swap_cue)
				swap_cue.global_position = candidate + Vector2(-40.0, -49.0)
		if boss.timer <= 0.0:
			if is_instance_valid(swap_cue) and swap_target.distance_to(boss.target.global_position) >= 75.0:
				boss.global_position = swap_target
			if is_instance_valid(swap_cue):
				swap_cue.queue_free()
			swap_cue = null
			_begin_phase(BellWarden.State.RECOVER)
	elif boss.state == BellWarden.State.RECOVER:
		boss.velocity.x = 0.0
		if boss.timer <= 0.0:
			machine.finish()
			boss._enter(BellWarden.State.CHASE)

func _adjacent_echo_position(boss: BellWarden, anchor: Vector2, player_at: Vector2) -> Vector2:
	var preferred := signf(player_at.x - anchor.x)
	if is_zero_approx(preferred):
		preferred = 1.0 if anchor.x < (boss.config.arena_min_x + boss.config.arena_max_x) * 0.5 else -1.0
	var space := boss.get_world_2d().direct_space_state
	for direction in [preferred, -preferred]:
		for distance in [72.0, 56.0, 40.0, 28.0]:
			var x: float = anchor.x + direction * distance
			if x < boss.config.arena_min_x or x > boss.config.arena_max_x:
				continue
			var wall_ray := PhysicsRayQueryParameters2D.create(anchor + Vector2(0.0, -28.0), Vector2(x, anchor.y - 28.0))
			wall_ray.collision_mask = 1
			if not space.intersect_ray(wall_ray).is_empty():
				continue
			var floor_ray := PhysicsRayQueryParameters2D.create(Vector2(x, anchor.y - 12.0), Vector2(x, anchor.y + 24.0))
			floor_ray.collision_mask = 1
			var floor_hit := space.intersect_ray(floor_ray)
			if not floor_hit.is_empty() and absf((floor_hit["position"] as Vector2).y - anchor.y) <= 4.0:
				return Vector2(x, anchor.y)
	return Vector2(clampf(anchor.x + preferred * 28.0, boss.config.arena_min_x, boss.config.arena_max_x), anchor.y)

func _update_resonance(boss: BellWarden) -> void:
	if boss.state == BellWarden.State.WINDUP:
		if not layer_locked and boss.action_elapsed >= 0.4:
			layer_locked = true
			var mark := RESONANCE.new() as BellWardenResonance
			mark.player = boss.target
			mark.warning_seconds = boss.config.resonance_charge - 0.4
			mark.active_seconds = boss.config.resonance_active_seconds
			mark.damage = boss.config.resonance_layer_damage
			var foot := boss.target.global_position
			if foot.y < 196.0 and foot.x >= 224.0 and foot.x <= 352.0:
				mark.configure_layer(224.0, 352.0, 168.0)
			elif foot.y < 270.0 and foot.x < 288.0:
				mark.configure_layer(64.0, 160.0, 228.0)
			elif foot.y < 270.0:
				mark.configure_layer(336.0, 432.0, 228.0)
			else:
				mark.configure_layer(0.0, 576.0, 320.0)
			boss.get_parent().add_child(mark)
			hazards.append(mark)
			boss._spawn_burst(Vector2((mark.left + mark.right) * 0.5, mark.floor_y - 8.0), Color("f4d49a"), 28.0, 0.3, 2, 6)
		if boss.timer <= 0.0:
			_begin_phase(BellWarden.State.STRIKE)
	elif boss.state == BellWarden.State.STRIKE and boss.timer <= 0.0:
		_begin_phase(BellWarden.State.RECOVER)
	elif boss.state == BellWarden.State.RECOVER:
		boss.velocity.x = 0.0
		if boss.timer <= 0.0:
			machine.finish()
			boss._enter(BellWarden.State.CHASE)
