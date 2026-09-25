class_name WorldInteraction
extends Node2D
## The room emits interactions. It never writes saves or changes scenes itself.
@export_enum("checkpoint", "exit", "ability", "goal", "reward", "sign", "upgrade", "finale", "chapter_end") var kind := "checkpoint"
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
@export var prompt := "E  /  REST & SAVE"
var clock := 0.0

func locked_message(abilities: Array[String], flags: Array[String]) -> String:
	if not required_ability.is_empty() and required_ability not in abilities:
		return "The high roots answer only to the sky echo"
	if not required_flag.is_empty() and required_flag not in flags:
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
				var tint := Color("efb268") if not locked_message(Session.abilities,Session.flags).is_empty() else mint
				draw_circle(Vector2(0,-77),3,tint)
				return
			draw_style_box(_door_style(), Rect2(-21, -70, 42, 70))
			draw_line(Vector2(-16, -66), Vector2(-16, -4), mint, 2)
			draw_line(Vector2(16, -66), Vector2(16, -4), mint, 2)
			draw_circle(Vector2(0, -34), 4, mint)
		"sign":
			draw_line(Vector2(0,0), Vector2(0,-38), Color("7b827b"), 3)
			draw_rect(Rect2(-15,-40,30,18), Color("304e52"))
			draw_line(Vector2(-9,-32), Vector2(9,-32), mint, 2)
		"ability", "goal", "reward", "upgrade", "finale", "chapter_end":
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
