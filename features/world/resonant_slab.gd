class_name ResonantSlab
extends Node2D
## Pressure-triggered stone. WARNING is harmless; ACTIVE draws the actual spike shape.
enum State { IDLE, WARNING, ACTIVE, COOLDOWN }
@export var config: ResonantSlabConfig
@onready var trigger: Area2D = $Trigger
@onready var strike: BellFrameStrike = $Strike
var state := State.IDLE
var elapsed := 0.0
var needs_release := false

func _physics_process(delta: float) -> void:
	elapsed += delta
	strike.stop()
	var occupied := false
	for body: Node2D in trigger.get_overlapping_bodies():
		if body is Player and body.state != Player.State.DEAD and body.is_on_floor():
			occupied = true
	if not occupied:
		needs_release = false
	match state:
		State.IDLE:
			if occupied and not needs_release:
				_enter(State.WARNING)
				needs_release = true
		State.WARNING:
			if elapsed >= config.warning_seconds:
				_enter(State.ACTIVE)
		State.ACTIVE:
			if elapsed >= config.active_seconds:
				_enter(State.COOLDOWN)
			else:
				# Each visible stone tooth has its exact triangle; all share one hit list.
				for index: int in range(4):
					strike.strike(tooth(index), config.damage)
		State.COOLDOWN:
			if elapsed >= config.cooldown_seconds:
				_enter(State.IDLE)
	queue_redraw()

func tooth(index: int) -> PackedVector2Array:
	var left := -config.width/2 + index*config.width/4
	return PackedVector2Array([Vector2(left,0),Vector2(left+config.width/8,-config.height),Vector2(left+config.width/4,0)])

func _enter(next: State) -> void:
	state = next
	elapsed = 0
	if next == State.ACTIVE:
		strike.begin()
		Audio.play_sound("hit", 0.65, -9)

func _draw() -> void:
	if config == null:
		return
	draw_rect(Rect2(-config.width/2,-3,config.width,6),Color("334956"))
	var tint := Color("9bc0c0")
	if state == State.WARNING:
		tint = Color("edbb78")
	elif state == State.COOLDOWN:
		tint = Color("64798a")
	for index: int in range(4):
		var x := -config.width/2 + 8 + index*config.width/4
		draw_line(Vector2(x,-2),Vector2(x+6,-2),tint,2)
	if state == State.WARNING:
		# The stone vibrates in place; no future trajectory or range overlay.
		draw_line(Vector2(-20,-5),Vector2(20,-5),tint,2)
	if state == State.ACTIVE:
		for index: int in range(4):
			draw_colored_polygon(tooth(index),Color("c2d5d1"))
			draw_line(tooth(index)[0],tooth(index)[1],Color("759496"),2)
