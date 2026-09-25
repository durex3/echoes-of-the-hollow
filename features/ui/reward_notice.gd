class_name RewardNotice
extends PanelContainer
## Informational overlay: never captures input or pauses gameplay.
const REWARDS := {
	"flow_seal": ["FLOW SEAL ACQUIRED", "One of two furnace valves restored", "All vitality restored. Return to Ember Quay."],
	"pressure_seal": ["PRESSURE SEAL ACQUIRED", "One of two furnace valves restored", "All vitality restored. Return to Ember Quay."],
	"cistern_restored": ["CISTERN RESTORED", "Steam vents are now safe throughout Chapter II", "Both chapters remain open to explore."],
	"warden_defeated": ["HOLLOW WARDEN DEFEATED", "The final echo is now within reach", "All vitality restored. Claim the echo on your right."],
	"double_jump": ["SKY ECHO ACQUIRED", "Double jump unlocked", "Press SPACE again in the air."],
	"dash": ["WIND ECHO ACQUIRED", "Wind dash unlocked", "K / Right shoulder to dash. No invincibility."],
	"heart_bloom": ["HEART BLOOM ACQUIRED", "Maximum vitality +1 permanently", "All vitality restored."],
	"training_cleared": ["WATCHERS SEAL ACQUIRED", "Forest shortcut + Ink Sanctum entrance unlocked", "All vitality restored. Take the east exit to the grove."],
	"scriptorium_cleared": ["INK SEAL ACQUIRED", "Archive return route unlocked", "All vitality restored. Take the east exit."],
	"belfry_cleared": ["WIND BEACON LIT", "Shortcut to the high grove unlocked", "All vitality restored. Take the door on your right."]
}
var title_label: Label
var effect_label: Label
var detail_label: Label
var save_label: Label
var remaining := 0.0
var reward_id := ""
var save_succeeded := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -264
	offset_right = 264
	offset_top = 64
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.065,0.085,0.96)
	style.border_color = Color("d6ba7e")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel",style)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",4)
	add_child(rows)
	title_label = _line(rows,20,Color("efce8e"))
	effect_label = _line(rows,16,Color("94e4ce"))
	detail_label = _line(rows,13,Color("e1e5df"))
	save_label = _line(rows,12,Color("b4c6c2"))
	hide()

func _line(rows: VBoxContainer, font_size: int, color: Color) -> Label:
	var line := Label.new()
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size",font_size)
	line.add_theme_color_override("font_color",color)
	rows.add_child(line)
	return line

func present(id: String, saved: bool) -> void:
	if not REWARDS.has(id):
		return
	reward_id = id
	save_succeeded = saved
	refresh_language()
	remaining = 6.0
	show()

func refresh_language() -> void:
	if not REWARDS.has(reward_id):
		return
	var content: Array = REWARDS[reward_id]
	title_label.text = TextCatalog.text(content[0])
	effect_label.text = TextCatalog.text(content[1])
	detail_label.text = TextCatalog.text(content[2])
	save_label.text = TextCatalog.text("Progress saved" if save_succeeded else "Save failed - visit a shrine to retry")
	save_label.add_theme_color_override("font_color",Color("b4c6c2") if save_succeeded else Color("ffba91"))

func advance(delta: float, covered: bool) -> void:
	if remaining <= 0:
		hide()
		return
	visible = not covered
	if not covered:
		remaining = maxf(0.0,remaining-delta)
		if remaining <= 0:
			hide()
