class_name WorldInteraction
extends Node2D
## The room emits interactions. It never writes saves or changes scenes itself.
@export_enum("checkpoint", "exit", "ability", "goal", "reward", "sign", "upgrade", "finale", "chapter_end", "challenge") var kind := "checkpoint"
@export var visible_after_flag := ""
@export_range(16, 64) var interaction_radius := 64.0
@export var required_flag := ""
@export var required_ability := ""
@export var required_flags: Array[String] = []
@export var missing_flag_prompts: Array[String] = []
@export var target_room := ""
@export var target_spawn := "entry"
@export var checkpoint_spawn := "checkpoint"
@export var stable_id := ""
@export var prompt := "E / SAVE PROGRESS"
var clock := 0.0

func locked_message(abilities: Array[String], flags: Array[String]) -> String:
	if not required_ability.is_empty() and required_ability not in abilities:
		return "The high roots answer only to the sky echo"
	if not required_flag.is_empty() and required_flag not in flags:
		if required_flag == "flow_seal":
			return "Flow valve locked / Climb the Sluice Shaft"
		if required_flag == "pressure_seal":
			return "Pressure valve locked / Explore the Lower Pump"
		return "Clear this hall and claim its seal first"
	for index: int in range(required_flags.size()):
		if required_flags[index] not in flags:
			return missing_flag_prompts[index] if index < missing_flag_prompts.size() else "Clear this hall and claim its seal first"
	return ""

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var mint := Color("94e4ce")
	match kind:
		"checkpoint":
			draw_circle(Vector2(0, -19), 26 + sin(clock * 2) * 2, Color(0.35, 0.9, 0.75, 0.07))
		"exit":
			if has_node("ForgeDoor"):
				if target_room == "furnace_core":
					var ready := locked_message(Session.abilities, Session.flags).is_empty()
					var gold := Color("f1ce83") if ready else Color("956d53")
					draw_rect(Rect2(-36, -70, 72, 70), Color(gold, 0.08 if ready else 0.04))
					draw_rect(Rect2(-36, -70, 72, 70), gold, false, 3)
					for index: int in 2:
						var seal := "flow_seal" if index == 0 else "pressure_seal"
						var x := -13.0 if index == 0 else 13.0
						var seal_color := Color("f1ce83") if seal in Session.flags else Color("574c48")
						var diamond := PackedVector2Array([Vector2(x,-90), Vector2(x+6,-83), Vector2(x,-76), Vector2(x-6,-83)])
						draw_colored_polygon(diamond, seal_color)
					if ready:
						draw_arc(Vector2(0,-83), 29, 0, TAU, 32, Color(gold, 0.45 + 0.2 * sin(clock * 3)), 2)
					return
				var tint := Color("efb268") if not locked_message(Session.abilities,Session.flags).is_empty() else mint
				draw_circle(Vector2(0,-77),3,tint)
				return
			draw_style_box(_door_style(), Rect2(-21, -70, 42, 70))
			draw_line(Vector2(-16, -66), Vector2(-16, -4), mint, 2)
			draw_line(Vector2(16, -66), Vector2(16, -4), mint, 2)
			draw_circle(Vector2(0, -34), 4, mint)
			if target_room == "ember_quay":
				draw_arc(Vector2(0,-39), 27, 0, TAU, 32, Color("efce8e",0.7), 2)
		"sign":
			draw_rect(Rect2(-8,-3,16,2), Color("34645f"))
			draw_rect(Rect2(-2,-5,4,2), mint)
		"challenge":
			draw_line(Vector2(0,0), Vector2(0,-38), Color("7b827b"), 3)
			draw_rect(Rect2(-17,-44,34,24), Color("482b3b"))
			draw_rect(Rect2(-17,-44,34,24), Color("f1ce83"), false, 1)
			draw_line(Vector2(-9,-38), Vector2(9,-26), Color("ff9bcc"), 2)
			draw_line(Vector2(9,-38), Vector2(-9,-26), Color("ff9bcc"), 2)
			draw_circle(Vector2(0,-32), 2, Color("f1ce83"))
		"chapter_end":
			draw_style_box(_door_style(), Rect2(-24, -82, 48, 82))
			draw_rect(Rect2(-24,-82,48,82),Color("f1ce83"),false,2)
			draw_circle(Vector2(0,-40),9+sin(clock*2)*2,Color("f1ce83",0.75))
		"ability", "goal", "reward", "upgrade", "finale":
			var y := -26 + sin(clock * 2.4) * 4
			var tint := Color("efb6bb") if kind == "upgrade" else (Color("f1ce83") if kind == "goal" else mint)
			draw_circle(Vector2(0, y), 27, Color(tint, 0.06))
			draw_colored_polygon(PackedVector2Array([Vector2(0, y-14), Vector2(9, y), Vector2(0, y+14), Vector2(-9, y)]), tint)
			draw_arc(Vector2(0, y), 20, clock, clock + 4.2, 24, Color(tint, 0.45), 1)

func _door_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("122d35")
	style.border_color = Color("456064")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	return style
