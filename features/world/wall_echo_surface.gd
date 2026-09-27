class_name WallEchoSurface
extends StaticBody2D
## Only authored marked surfaces allow Wall Echo; ordinary old walls stay inert.
## Adjacent pieces of one continuous wall must share the same surface_id.

@export var surface_id: StringName

func echo_id() -> StringName:
	return surface_id if not surface_id.is_empty() else StringName(str(get_instance_id()))
