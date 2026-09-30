class_name SwordCourt
extends Node2D
## One owned cast, four readable volleys; children own their swept collisions.
signal volley_locked(index: int)
signal volley_fired(index: int)
signal summon_finished
signal cast_finished
signal impact(at: Vector2, defeated: bool)
const SWORD := preload("res://features/combat/royal_sword.tscn")
const BURST := preload("res://features/enemies/boss_visual_burst.gd")
const ROUNDS := [[0,1],[5,6],[2,4],[3]]
enum Phase { SUMMON, LOCK, RELEASE, WAIT_FLIGHT, GAP, FINISHED }
@export var config: SwordCourtConfig
var target: Player
var swords: Array[RoyalSword] = []
var phase := Phase.SUMMON
var elapsed := 0.0
var round_index := -1
var launched := 0
var locked_target := Vector2.ZERO
var volley_hits: Array[int] = []

func _ready() -> void:
	for index: int in range(7):
		var sword := SWORD.instantiate() as RoyalSword
		sword.config = config
		sword.target = target
		sword.royal = index == 3
		sword.summon_delay = absf(index-3) * config.summon_stagger
		sword.position = config.crown_positions[index]
		sword.impact.connect(func(at: Vector2, defeated: bool) -> void: impact.emit(at,defeated))
		add_child(sword)
		swords.append(sword)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.state == Player.State.DEAD:
		retire()
		return
	elapsed += delta
	match phase:
		Phase.SUMMON:
			if elapsed >= config.summon_seconds:
				_lock_next()
				summon_finished.emit()
		Phase.LOCK:
			if elapsed >= (config.royal_lock_seconds if round_index == 3 else config.lock_seconds):
				phase = Phase.RELEASE
				elapsed = 0.0
				launched = 0
				volley_hits = []
				_fire_next()
				volley_fired.emit(round_index)
		Phase.RELEASE:
			if launched < ROUNDS[round_index].size() and elapsed >= config.pair_stagger:
				_fire_next()
			if launched == ROUNDS[round_index].size():
				phase = Phase.WAIT_FLIGHT
		Phase.WAIT_FLIGHT:
			var flying := false
			for index: int in ROUNDS[round_index]:
				flying = flying or (is_instance_valid(swords[index]) and swords[index].dangerous())
			if not flying:
				phase = Phase.GAP
				elapsed = 0.0
		Phase.GAP:
			if elapsed >= config.round_gap:
				if round_index == 3:
					phase = Phase.FINISHED
					cast_finished.emit()
					retire()
				else:
					_lock_next()

func _lock_next() -> void:
	round_index += 1
	phase = Phase.LOCK
	elapsed = 0.0
	locked_target = target.global_position + config.aim_offset
	for index: int in ROUNDS[round_index]:
		if is_instance_valid(swords[index]):
			swords[index].lock_on(locked_target,config.royal_lock_seconds if round_index == 3 else config.lock_seconds)
	_spawn_burst(locked_target, Color("f6d27d") if round_index < 3 else Color("fff1b0"), 28.0 if round_index < 3 else 38.0, 0.26, 2, 8)
	volley_locked.emit(round_index)

func _fire_next() -> void:
	var index: int = ROUNDS[round_index][launched]
	if is_instance_valid(swords[index]):
		swords[index].launch(volley_hits)
	launched += 1
	Audio.play_sound("attack",0.7 if round_index == 3 else 1.1,-6.0)

func _spawn_burst(at: Vector2, tint: Color, radius: float, duration: float, rings: int, rays: int) -> void:
	var burst := BURST.new() as BossVisualBurst
	burst.configure(tint, radius, duration, rings, rays)
	get_parent().add_child(burst)
	burst.global_position = at

func retire() -> void:
	phase = Phase.FINISHED
	for sword: RoyalSword in swords:
		if is_instance_valid(sword):
			sword.retire()
	set_physics_process(false)
	hide()
	queue_free()
