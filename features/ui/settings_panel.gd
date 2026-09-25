class_name SettingsPanel
extends PanelContainer
signal closed
var rows: VBoxContainer
var status: Label
var capture_action := ""
var binding_buttons: Dictionary = {}
var back_button: Button
var scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -245
	offset_right = 245
	offset_top = -166
	offset_bottom = 166
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e27")
	style.border_color = Color("94e4ce")
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	add_child(outer)
	var title := Label.new()
	title.text = TextCatalog.text("Settings")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 222)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color("efce8e"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status)
	back_button = Button.new()
	back_button.text = TextCatalog.text("Back")
	back_button.pressed.connect(close)
	outer.add_child(back_button)
	hide()

func open() -> void:
	capture_action = ""
	status.text = ""
	build()
	scroll.set_deferred("scroll_vertical", 0)
	show()
	back_button.grab_focus()

func build() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	binding_buttons.clear()
	volume_row("Music volume", "music_volume")
	volume_row("Sound volume", "sfx_volume")
	var full := CheckButton.new()
	full.text = TextCatalog.text("Fullscreen")
	full.button_pressed = Session.fullscreen
	full.toggled.connect(func(value: bool) -> void:
		Session.fullscreen = value
		Session.apply_display()
		save())
	rows.add_child(full)
	for item: Array in [["Reduce screen shake", "reduce_shake"], ["Reduce hit flashes", "reduce_flashes"]]:
		var toggle := CheckButton.new()
		toggle.text = TextCatalog.text(item[0])
		toggle.button_pressed = Session.get(item[1])
		toggle.toggled.connect(func(value: bool) -> void:
			Session.set(item[1], value)
			save())
		rows.add_child(toggle)
	var note := Label.new()
	note.text = TextCatalog.text("Select an action, then press a key or gamepad button. ESC cancels.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	rows.add_child(note)
	for index: int in range(InputBindings.ACTIONS.size()):
		var action: String = InputBindings.ACTIONS[index]
		# Keep Esc/Start as a permanent route back to menus.
		if action == "pause":
			continue
		var button := Button.new()
		button.text = "%s    %s  |  %s" % [TextCatalog.text(InputBindings.TITLES[index]), Session.bindings.hint(action, false), Session.bindings.hint(action, true)]
		button.pressed.connect(func() -> void:
			capture_action = action
			status.text = TextCatalog.text("Waiting for input / ESC to cancel"))
		rows.add_child(button)
		binding_buttons[action] = button
		button.focus_entered.connect(func() -> void: scroll.ensure_control_visible.call_deferred(button))
	var reset := Button.new()
	reset.text = TextCatalog.text("Reset bindings")
	reset.pressed.connect(func() -> void:
		Session.bindings.apply({})
		save()
		build()
		back_button.grab_focus())
	rows.add_child(reset)

func volume_row(title: String, property: String) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = 140
	label.text = TextCatalog.text(title)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = property
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(Session.get(property)) * 100
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var percent := Label.new()
	percent.custom_minimum_size.x = 40
	percent.text = "%d%%" % slider.value
	row.add_child(percent)
	slider.value_changed.connect(func(value: float) -> void:
		Session.set(property, value / 100.0)
		percent.text = "%d%%" % value
		save())

func save() -> void:
	status.text = TextCatalog.text("Settings saved" if Session.save_settings() == OK else "Settings could not be saved")

func close() -> void:
	capture_action = ""
	hide()
	closed.emit()

func handle_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if capture_action.is_empty():
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close()
		return
	if event.is_action_pressed("pause"):
		capture_action = ""
		status.text = TextCatalog.text("Binding cancelled")
		return
	if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		var error := Session.bindings.rebind(capture_action, event)
		if not error.is_empty():
			status.text = error.replace("Already assigned: ", TextCatalog.text("Already assigned: ")) if error.begins_with("Already assigned: ") else TextCatalog.text(error)
			return
		var action := capture_action
		capture_action = ""
		save()
		build()
		(binding_buttons[action] as Button).grab_focus()
		scroll.ensure_control_visible.call_deferred(binding_buttons[action])
