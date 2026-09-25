class_name GameUI
extends CanvasLayer

signal start_requested(load_save: bool)
signal resume_requested
signal quit_requested
signal map_closed
var health_label: Label
var area_label: Label
var objective: Label
var prompt: Label
var toast: Label
var modal: PanelContainer
var menu: VBoxContainer
var toast_left := 0.0
var hud: Control
var map_panel: PanelContainer
var world_map: WorldMap
var menu_mode := "title"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/alagard.ttf")
	theme.default_font_size = 14
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 14
	hud.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	health_label = label("VITALITY", 18, Color("e9d4a3"))
	left.add_child(health_label)
	objective = label("Find the echo in the eastern ruins", 12, Color("b4c6c2"))
	left.add_child(objective)
	area_label = label("", 14, Color("94e4ce"))
	top.add_child(area_label)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -68
	bottom.offset_bottom = -12
	hud.add_child(bottom)
	toast = label("", 14, Color("efce8e"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(toast)
	prompt = label("", 16, Color("94e4ce"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(prompt)
	var controls := label("A/D Move  SPACE Jump  J Attack  K Dash  E Use  Q Map  ESC Pause  M Mute", 11, Color("9aafad"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(controls)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -210
	modal.offset_right = 210
	modal.offset_top = -138
	modal.offset_bottom = 138
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.085, 0.97)
	style.border_color = Color("526d64")
	style.set_border_width_all(1)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	modal.add_child(menu)
	hud.hide()
	modal.hide()
	map_panel = PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_panel.offset_left = -290
	map_panel.offset_right = 290
	map_panel.offset_top = -160
	map_panel.offset_bottom = 160
	var map_style := style.duplicate() as StyleBoxFlat
	map_style.content_margin_left = 20
	map_style.content_margin_right = 20
	map_style.content_margin_top = 12
	map_style.content_margin_bottom = 12
	map_panel.add_theme_stylebox_override("panel",map_style)
	root.add_child(map_panel)
	var map_layout := VBoxContainer.new()
	map_panel.add_child(map_layout)
	var map_title := label("PATHS OF THE HOLLOW",20,Color("efce8e"))
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_layout.add_child(map_title)
	world_map = WorldMap.new()
	world_map.custom_minimum_size = Vector2(540,226)
	world_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_layout.add_child(world_map)
	var close := Button.new()
	close.name = "CloseMap"
	close.text = "Return / Q or ESC"
	close.pressed.connect(func() -> void: map_closed.emit())
	map_layout.add_child(close)
	map_panel.hide()

func show_map(room_id: String) -> void:
	world_map.configure(room_id,Session.visited,Session.checkpoint_room,Session.flags,Session.abilities)
	modal.hide()
	map_panel.show()
	(map_panel.find_child("CloseMap",true,false) as Button).grab_focus()

func hide_map() -> void:
	map_panel.hide()

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func show_menu(mode: String, can_continue := false) -> void:
	menu_mode = mode
	for child: Node in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	modal.show()
	var title := label("ECHOES OF THE HOLLOW" if mode == "title" else ("ECHO RESTORED" if mode == "win" else "PAUSED"), 24, Color("efce8e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var subtitle := label("A small journey through the forgotten grove", 12, Color("b4c6c2"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(subtitle)
	if mode == "title":
		if can_continue:
			button("Continue from checkpoint", func() -> void: start_requested.emit(true))
		button("New journey", func() -> void: start_requested.emit(false))
		if can_continue:
			menu.add_child(label("New journey replaces progress on the next save.", 12, Color("b4c6c2")))
	else:
		button("Continue exploring" if mode == "win" else "Resume", func() -> void: resume_requested.emit())
		if mode == "pause":
			setting_toggle("Reduce screen shake", Session.reduce_shake, "reduce_shake")
			setting_toggle("Reduce hit flashes", Session.reduce_flashes, "reduce_flashes")
	button("Quit", func() -> void: quit_requested.emit())
	for child: Node in menu.get_children():
		if child is Button:
			child.grab_focus()
			break

func button(text: String, action: Callable) -> void:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 29
	node.pressed.connect(action)
	menu.add_child(node)

func setting_toggle(text: String, value: bool, property: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = value
	toggle.toggled.connect(func(enabled: bool) -> void:
		Session.set(property, enabled)
		if Session.save_settings() != OK:
			notify("Settings could not be saved"))
	menu.add_child(toggle)

func show_hud() -> void:
	hud.show()
	modal.hide()

func update_health(current: int, maximum: int) -> void:
	health_label.text = "VITALITY  " + "| ".repeat(current) + ". ".repeat(maximum - current)

func update_progress() -> void:
	if "dash" in Session.abilities:
		objective.text = "Wind route open / Explore freely" if "belfry_cleared" in Session.flags else "Dash through the wind / Reach the silent belfry"
		return
	objective.text = "Echo restored / Explore freely" if Session.completed else ("Double jump unlocked / Return to the high shrine" if Session.abilities.has("double_jump") else "Find the echo in the eastern ruins")

func notify(message: String) -> void:
	toast.text = message
	toast_left = 3.0

func _process(delta: float) -> void:
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0:
			toast.text = ""
