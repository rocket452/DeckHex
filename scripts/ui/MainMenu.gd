extends Control
class_name MainMenu

signal mode_selected(mode: String)

enum Mode {
	SIMULATED_PVP,
	ADVENTURE
}

var selected_mode: Mode = Mode.SIMULATED_PVP

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	# Background
	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.1, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Main container
	var main_container := VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 30)
	add_child(main_container)
	
	# Title
	var title_label := Label.new()
	title_label.text = "DECKHEX"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Subtitle
	var subtitle_label := Label.new()
	subtitle_label.text = "Tactical Card Combat"
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(subtitle_label)
	
	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 100)
	main_container.add_child(spacer1)
	
	# Mode selection container
	var mode_container := HBoxContainer.new()
	mode_container.add_theme_constant_override("separation", 40)
	main_container.add_child(mode_container)
	
	# PvP Battle button
	var pvp_button := _create_mode_button("1. SIMULATED PvP", Mode.SIMULATED_PVP)
	mode_container.add_child(pvp_button)
	
	# Adventure button
	var adventure_button := _create_mode_button("2. ADVENTURE", Mode.ADVENTURE)
	mode_container.add_child(adventure_button)
	
	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(spacer2)
	
	# Mode description
	var description_label := Label.new()
	description_label.text = "Select a game mode to begin"
	description_label.add_theme_font_size_override("font_size", 18)
	description_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.name = "description_label"
	main_container.add_child(description_label)
	
	# Update initial description
	_update_description()

func _create_mode_button(text: String, mode: Mode) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 80)
	button.add_theme_font_size_override("font_size", 20)
	
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	button.add_theme_stylebox_override("normal", style)
	
	# Hover style
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.3, 0.4, 0.5, 0.9)
	hover_style.border_color = Color(0.6, 0.7, 0.8)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed style
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.4, 0.5, 0.6, 1.0)
	pressed_style.border_color = Color(0.8, 0.9, 1.0)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Selected style
	var selected_style := style.duplicate()
	selected_style.bg_color = Color(0.5, 0.7, 0.4, 0.9)
	selected_style.border_color = Color(0.7, 0.9, 0.6)
	button.add_theme_stylebox_override("selected", selected_style)
	
	# Connect signals
	button.pressed.connect(_on_mode_selected.bind(mode))
	button.mouse_entered.connect(_on_button_hover.bind(mode))
	
	# Store mode reference
	button.set_meta("mode", mode)
	
	return button

func _on_mode_selected(mode: Mode) -> void:
	selected_mode = mode
	
	# Update button styles
	for child in get_children():
		if child is HBoxContainer:
			for button in child.get_children():
				if button is Button:
					var button_mode: Mode = button.get_meta("mode")
					if button_mode == mode:
						button.remove_theme_stylebox_override("normal")
						button.add_theme_stylebox_override("normal", button.get_theme_stylebox("selected"))
					else:
						button.remove_theme_stylebox_override("normal")
						button.add_theme_stylebox_override("normal", _create_default_style())
	
	_update_description()
	
	# Emit signal after brief delay for visual feedback
	await get_tree().create_timer(0.3).timeout
	mode_selected.emit(_mode_to_string(mode))

func _on_button_hover(mode: Mode) -> void:
	# Update description on hover
	var description_label = get_node("VBoxContainer/description_label") as Label
	if description_label:
		match mode:
			Mode.SIMULATED_PVP:
				description_label.text = "Battle against CPU-controlled Abyssian deck\nLyonar (Player) vs Abyssian (CPU)"
			Mode.ADVENTURE:
				description_label.text = "Navigate through encounters on a roguelike map\nChoose your path and face various challenges"

func _update_description() -> void:
	var description_label = get_node("VBoxContainer/description_label") as Label
	if description_label:
		match selected_mode:
			Mode.SIMULATED_PVP:
				description_label.text = "Battle against CPU-controlled Abyssian deck\nLyonar (Player) vs Abyssian (CPU)\n\nPress SPACE to start"
			Mode.ADVENTURE:
				description_label.text = "Navigate through encounters on a roguelike map\nChoose your path and face various challenges\n\nPress SPACE to start"

func _create_default_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _mode_to_string(mode: Mode) -> String:
	match mode:
		Mode.SIMULATED_PVP:
			return "simulated_pvp"
		Mode.ADVENTURE:
			return "adventure"
		_:
			return ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			mode_selected.emit("simulated_pvp")
		elif event.keycode == KEY_2:
			mode_selected.emit("adventure")
		elif event.keycode == KEY_SPACE:
			mode_selected.emit(_mode_to_string(selected_mode))
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
