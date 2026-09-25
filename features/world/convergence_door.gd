extends WorldInteraction
## Three visible sockets reflect the scene-authored gate requirements.

func _ready() -> void:
	Session.progress_changed.connect(queue_redraw)

func _draw() -> void:
	super._draw()
	for index: int in range(required_flags.size()):
		var at := Vector2((index-1)*16,-85)
		var acquired := required_flags[index] in Session.flags
		draw_circle(at,6,Color("94e4ce") if acquired else Color("263941"))
		draw_arc(at,6,0,TAU,20,Color("d6ba7e"),1)
