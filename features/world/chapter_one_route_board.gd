class_name ChapterOneRouteBoard
extends WorldInteraction
## Hub sign for the first chapter. It explains the authored loop without
## changing legacy door IDs or the high-shrine save flag.

func _process(delta: float) -> void:
	if "training_cleared" in Session.flags and "scriptorium_cleared" in Session.flags and "belfry_cleared" in Session.flags:
		prompt = "Three marks glow. The eastern gate opens to the Echo Antechamber."
	elif "double_jump" in Session.abilities:
		prompt = "Sky echo acquired. The high roots are optional; the three marks lie east."
	else:
		prompt = "The archive east teaches the sky echo. Return here after the climb."
	super._process(delta)
