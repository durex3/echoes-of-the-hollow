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
var reward_notice: RewardNotice
var root_control: Control
var ui_theme: Theme
var english_font: Font
const CHINESE_FONT := preload("res://assets/fonts/noto_sans_sc.otf")
var health_current := 5
var health_maximum := 5
var menu_can_continue := false
var boss_panel: VBoxContainer
var boss_title: Label
var boss_bar: ProgressBar
var finale_saved := false
var settings_panel: SettingsPanel
var vitality_pips: VitalityPips
var dash_label: Label
var dash_status := "Dash locked"
var controls: Label
var map_progress: Label
var map_objective: Label
var boss_hint: Label
var confirmation: ConfirmationDialog
var chapter_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root_control = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	ui_theme = theme
	english_font = preload("res://assets/fonts/alagard.ttf").duplicate() as Font
	english_font.fallbacks = [CHINESE_FONT]
	theme.default_font = CHINESE_FONT if Session.language == "zh_CN" else english_font
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
	var health_row := HBoxContainer.new()
	left.add_child(health_row)
	health_label.add_theme_font_size_override("font_size", 14)
	health_row.add_child(health_label)
	vitality_pips = VitalityPips.new()
	health_row.add_child(vitality_pips)
	dash_label = label("Dash locked", 11, Color("94e4ce"))
	health_row.add_child(dash_label)
	objective = label("Find the echo in the eastern ruins", 12, Color("b4c6c2"))
	left.add_child(objective)
	area_label = label("", 14, Color("94e4ce"))
	top.add_child(area_label)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -86
	bottom.offset_bottom = -12
	hud.add_child(bottom)
	toast = label("", 14, Color("efce8e"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(toast)
	prompt = label("", 16, Color("94e4ce"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(prompt)
	controls = label("", 11, Color("9aafad"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(controls)
	reward_notice = RewardNotice.new()
	hud.add_child(reward_notice)
	boss_panel = VBoxContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -170
	boss_panel.offset_right = 170
	boss_panel.offset_top = 70
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_panel)
	boss_title = label("HOLLOW WARDEN / I",14,Color("efce8e"))
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_title)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size.y = 8
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("263941")
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("d6ba7e")
	boss_bar.add_theme_stylebox_override("background",bar_background)
	boss_bar.add_theme_stylebox_override("fill",bar_fill)
	boss_panel.add_child(boss_bar)
	boss_hint = label("", 12, Color("94e4ce"))
	boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_hint)
	boss_panel.hide()
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
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
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
	chapter_button = Button.new()
	chapter_button.name = "ChapterPage"
	chapter_button.pressed.connect(func() -> void:
		world_map.chapter = 2 if world_map.chapter == 1 else 1
		world_map.queue_redraw()
		_refresh_map_page())
	map_layout.add_child(chapter_button)
	map_progress = label("", 12, Color("efce8e"))
	map_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_layout.add_child(map_progress)
	map_objective = label("", 11, Color("94e4ce"))
	map_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_layout.add_child(map_objective)
	world_map = WorldMap.new()
	world_map.custom_minimum_size = Vector2(540,202)
	world_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_layout.add_child(world_map)
	var close := Button.new()
	close.name = "CloseMap"
	close.text = "Back"
	close.set_meta("source_text",close.text)
	close.text = TextCatalog.text(close.text)
	close.pressed.connect(func() -> void: map_closed.emit())
	map_layout.add_child(close)
	map_panel.hide()
	settings_panel = SettingsPanel.new()
	root.add_child(settings_panel)
	settings_panel.closed.connect(func() -> void:
		show_menu(menu_mode, menu_can_continue)
		(menu.get_node("SettingsButton") as Button).grab_focus())
	confirmation = ConfirmationDialog.new()
	confirmation.title = TextCatalog.text("Start a new journey?")
	confirmation.dialog_text = TextCatalog.text("New journey replaces progress on the next save.")
	confirmation.confirmed.connect(func() -> void: start_requested.emit(false))
	root.add_child(confirmation)
	Session.language_changed.connect(_refresh_language)
	Session.bindings.changed.connect(_refresh_bindings)
	_refresh_bindings()

func show_map(room_id: String) -> void:
	world_map.configure(room_id,Session.visited,Session.checkpoint_room,Session.flags,Session.abilities)
	_refresh_map_page()
	map_objective.text = TextCatalog.text(JourneyProgress.objective(Session.abilities,Session.flags,Session.visited))
	modal.hide()
	map_panel.show()
	(map_panel.find_child("CloseMap",true,false) as Button).grab_focus()

func _refresh_map_page() -> void:
	chapter_button.visible = "journey_restored" in Session.flags
	world_map.custom_minimum_size.y = 168 if chapter_button.visible else 202
	chapter_button.text = TextCatalog.text("Chapter II / Show Chapter I" if world_map.chapter == 2 else "Chapter I / Show Chapter II")
	map_progress.text = world_map.mark_summary()

func hide_map() -> void:
	map_panel.hide()

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	set_text(node,text)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func show_menu(mode: String, can_continue := false) -> void:
	menu_mode = mode
	menu_can_continue = can_continue
	for child: Node in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	modal.show()
	var heading := "HOLLOW RESTORED" if mode == "finale" else ("ECHOES OF THE HOLLOW" if mode == "title" else ("ECHO RESTORED" if mode == "win" else "PAUSED"))
	if mode == "chapter_two":
		heading = "CISTERN RESTORED"
	var title := label(heading, 24, Color("efce8e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var subtitle := label("The warden rests. The grove remembers your journey." if mode == "finale" else "A small journey through the forgotten grove", 12, Color("b4c6c2"))
	if mode == "chapter_two":
		set_text(subtitle,"Steam vents are now safe throughout Chapter II")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(subtitle)
	if mode in ["finale", "chapter_two"]:
		var saved_label := label("Progress saved" if finale_saved else "Save failed - visit a shrine to retry",12,Color("efce8e"))
		saved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(saved_label)
	if mode == "title":
		if can_continue:
			button("Continue from checkpoint", func() -> void: start_requested.emit(true))
		button("New journey", request_new_journey)
		if can_continue:
			menu.add_child(label("New journey replaces progress on the next save.", 12, Color("b4c6c2")))
	else:
		button("Continue exploring" if mode in ["win","finale","chapter_two"] else "Resume", func() -> void: resume_requested.emit())
	button("Settings", func() -> void:
		modal.hide()
		settings_panel.open())
	menu.get_child(menu.get_child_count() - 1).name = "SettingsButton"
	button("Quit", func() -> void: quit_requested.emit())
	var language_button := Button.new()
	language_button.name = "LanguageButton"
	language_button.text = "语言 / Language: 简体中文" if Session.language == "zh_CN" else "Language / 语言: English"
	language_button.custom_minimum_size.y = 29
	language_button.pressed.connect(_toggle_language)
	menu.add_child(language_button)
	for child: Node in menu.get_children():
		if child is Button:
			child.grab_focus()
			break

func button(text: String, action: Callable) -> void:
	var node := Button.new()
	node.text = TextCatalog.text(text)
	node.custom_minimum_size.y = 29
	node.pressed.connect(action)
	menu.add_child(node)

func setting_toggle(text: String, value: bool, property: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = TextCatalog.text(text)
	toggle.button_pressed = value
	toggle.toggled.connect(func(enabled: bool) -> void:
		Session.set(property, enabled)
		if Session.save_settings() != OK:
			notify("Settings could not be saved"))
	menu.add_child(toggle)

func show_hud() -> void:
	hud.show()
	modal.hide()
	settings_panel.hide()

func update_health(current: int, maximum: int) -> void:
	health_current = current
	health_maximum = maximum
	health_label.text = TextCatalog.text("VITALITY") + " %d/%d" % [current, maximum]
	vitality_pips.update_health(current, maximum)

func update_progress() -> void:
	set_text(objective,JourneyProgress.objective(Session.abilities,Session.flags,Session.visited))

func show_boss(current: int, maximum: int) -> void:
	update_boss_health(current,maximum)
	update_boss_phase(1)
	reward_notice.remaining = 0
	boss_panel.show()

func update_boss_health(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current

func update_boss_phase(phase: int) -> void:
	set_text(boss_title,"HOLLOW WARDEN / II" if phase == 2 else "HOLLOW WARDEN / I")

func hide_boss() -> void:
	boss_panel.hide()

func notify(message: String) -> void:
	set_text(toast,message)
	toast_left = 3.0

func _process(delta: float) -> void:
	reward_notice.advance(delta,get_tree().paused or modal.visible or map_panel.visible or settings_panel.visible)
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0:
			set_text(toast,"")

func set_text(node: Label, source: String) -> void:
	node.set_meta("source_text",source)
	node.text = TextCatalog.text(source)

func _refresh_text(node: Node) -> void:
	if node.has_meta("source_text"):
		node.set("text",TextCatalog.text(str(node.get_meta("source_text"))))
	for child: Node in node.get_children():
		_refresh_text(child)

func _refresh_language() -> void:
	ui_theme.default_font = CHINESE_FONT if Session.language == "zh_CN" else english_font
	_refresh_text(root_control)
	update_health(health_current,health_maximum)
	update_progress()
	world_map.queue_redraw()
	_refresh_map_page()
	reward_notice.refresh_language()
	if modal.visible:
		show_menu(menu_mode,menu_can_continue)
	_refresh_bindings()

func _toggle_language() -> void:
	if Session.set_language("en" if Session.language == "zh_CN" else "zh_CN") != OK:
		notify("Settings could not be saved")
	(menu.get_node("LanguageButton") as Button).grab_focus()

func request_new_journey() -> void:
	if menu_can_continue:
		confirmation.title = TextCatalog.text("Start a new journey?")
		confirmation.dialog_text = TextCatalog.text("New journey replaces progress on the next save.")
		confirmation.ok_button_text = TextCatalog.text("New journey")
		confirmation.cancel_button_text = TextCatalog.text("Back")
		confirmation.popup_centered(Vector2i(400, 140))
	else:
		start_requested.emit(false)

func update_dash_status(value: String) -> void:
	dash_status = value
	dash_label.text = (Session.bindings.hint("dash") + " " if value != "Dash locked" else "") + TextCatalog.text(value)

func update_boss_cue(value: String) -> void:
	set_text(boss_hint, value)

func _refresh_bindings() -> void:
	_refresh_text(root_control)
	update_health(health_current, health_maximum)
	var hints: Array[String] = []
	hints.append(("LS" if Session.bindings.gamepad else Session.bindings.hint("move_left") + "/" + Session.bindings.hint("move_right")) + " " + TextCatalog.text("Move"))
	for action: String in ["jump", "attack", "interact", "world_map", "pause"]:
		var index := InputBindings.ACTIONS.find(action)
		hints.append(Session.bindings.hint(action) + " " + TextCatalog.text(InputBindings.TITLES[index]))
	controls.text = "   ".join(hints)
	update_dash_status(dash_status)
	reward_notice.refresh_language()
