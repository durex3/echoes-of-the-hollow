class_name FurnaceArenaGate
extends StaticBody2D

var closed := false

func set_closed(value: bool) -> void:
	closed = value
	$Shape.set_deferred("disabled",not value)
	queue_redraw()

func _draw() -> void:
	# The boss chamber is bounded by authored room geometry. The collision wall
	# remains invisible so the player reads a sealed arena instead of a pop-up bar.
	return
