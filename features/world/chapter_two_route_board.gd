class_name ChapterTwoRouteBoard
extends WorldInteraction
## A small authored sign at the chapter hub. It turns the two-seal graph into
## a readable next step without changing doors, collision, or save semantics.

func _process(delta: float) -> void:
	if "flow_seal" in Session.flags and "pressure_seal" in Session.flags:
		prompt = "Both valves are set. The gold door leads to the Furnace Core."
	elif "flow_seal" in Session.flags:
		prompt = "Flow seal set. Enter the Cistern Archive and descend to the Lower Pump."
	elif "pressure_seal" in Session.flags:
		prompt = "Pressure seal set. Enter the Valve Gallery and climb the Sluice Shaft."
	else:
		prompt = "Two valve routes are open. Choose either branch, then follow its return path."
	super._process(delta)
