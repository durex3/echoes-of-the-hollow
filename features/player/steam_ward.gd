class_name SteamWard
extends Node2D
## Steam-only charge; no health invulnerability or physics shapes are changed.
signal status_changed(status: String, seconds: int)
signal steam_blocked
@export var config: SteamWardConfig
var active_left := 0.0
var cooldown_left := 0.0
var feedback_left := 0.0
var last_status := ""
var last_seconds := -1

func activate() -> bool:
	if "steam_ward" not in Session.abilities or cooldown_left > 0:
		return false
	active_left = config.active_seconds
	cooldown_left = config.cooldown_seconds
	Audio.play_sound("ability_acquire",1.2,-8)
	publish()
	queue_redraw()
	return true

func absorb() -> bool:
	if active_left <= 0 or "steam_ward" not in Session.abilities:
		return false
	active_left = 0
	feedback_left = config.feedback_seconds
	steam_blocked.emit()
	Audio.play_sound("save",1.3,-8)
	publish()
	queue_redraw()
	return true

func advance(delta: float) -> void:
	active_left = maxf(0,active_left-delta)
	cooldown_left = maxf(0,cooldown_left-delta)
	feedback_left = maxf(0,feedback_left-delta)
	publish()
	queue_redraw()

func cancel(reset_cooldown := false) -> void:
	active_left = 0
	feedback_left = 0
	if reset_cooldown:
		cooldown_left = 0
	publish()
	queue_redraw()

func publish() -> void:
	var status := "Ward ready"
	var seconds := 0
	if "steam_ward" not in Session.abilities:
		status = "Ward locked"
	elif feedback_left > 0:
		status = "Steam blocked"
	elif active_left > 0:
		status = "Ward active"
	elif cooldown_left > 0:
		status = "Ward cooling"
		seconds = ceili(cooldown_left)
	if status != last_status or seconds != last_seconds:
		last_status = status
		last_seconds = seconds
		status_changed.emit(status,seconds)

func _draw() -> void:
	if active_left <= 0 and feedback_left <= 0:
		return
	var radius := 29.0 if active_left > 0 else 29.0+12.0*(1-feedback_left/config.feedback_seconds)
	var tint := Color("94e4ef")
	if active_left <= 0:
		tint.a = feedback_left/config.feedback_seconds
	draw_arc(Vector2(0,-23),radius,0,TAU,32,tint,2)
	if active_left > 0:
		draw_circle(Vector2(0,-56),3,tint)
