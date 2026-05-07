extends Control
class_name RunMapManager

signal encounter_selected(node: EncounterNode)
signal run_completed(victory: bool)
signal run_abandoned

const MAIN_GAME_SCENE := preload("res://scenes/MainGame.tscn")

var run_map: RunMap = null
var main_game: MainGame = null

# UI References
var map_container: Control = null
var layer_container: VBoxContainer = null
var info_panel: PanelContainer = null
var info_label: Label = null
var confirm_button: Button = null

# State
var selected_node_id: String = ""
var is_in_battle: bool = false

func _ready() -> void:
	_setup_ui()
	_start_new_run()

func _setup_ui() -> void:
	# Background
	var background := ColorRect.new()
	background.color = Color(0.05, 0.06, 0.08, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	
	# Title
	var title := Label.new()
	title.text = "Choose Your Path"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	root.add_child(title)
	
	# Map container (scrollable)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	
	map_container = Control.new()
	map_container.custom_minimum_size = Vector2(800, 500)
	scroll.add_child(map_container)
	
	# Info panel at bottom
	info_panel = PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 100)
	root.add_child(info_panel)
	
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 12)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_right", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)
	
	info_label = Label.new()
	info_label.text = "Select a node to view details"
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_margin.add_child(info_label)
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(200, 50)
	root.add_child(confirm_button)
	_setup_map_button()

func _start_new_run() -> void:
	run_map = RunMap.new(4)  # 4 middle layers + start + boss
	selected_node_id = ""
	is_in_battle = false
	_setup_map_button()
	info_label.text = "Select a node to view details"
	info_label.remove_theme_color_override("font_color")
	_refresh_map_ui()

func _refresh_map_ui() -> void:
	# Clear existing nodes
	for child in map_container.get_children():
		child.queue_free()
	
	if run_map == null:
		return
	
	# Draw nodes for each layer
	var layer_height := 100
	var node_spacing := 150
	var start_x := 100
	var start_y := 50
	
	for layer in range(run_map.max_layers + 1):
		var nodes := run_map.get_nodes_in_layer(layer)
		var layer_y := start_y + layer * layer_height
		
		for node in nodes:
			var node_x := start_x + node.position_in_layer * node_spacing
			var button := _create_node_button(node, Vector2(node_x, layer_y))
			map_container.add_child(button)
		
		# Draw connections to next layer
		if layer < run_map.max_layers:
			for node in nodes:
				for conn_id in node.connections:
					var target_node := run_map.get_node(conn_id)
					if target_node != null:
						_draw_connection(node, target_node, start_x, start_y, layer_height, node_spacing)

func _create_node_button(node: EncounterNode, position: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.custom_minimum_size = Vector2(80, 60)
	button.text = EncounterType.get_display_name(node.type)
	
	# Style based on state
	var is_current := node.id == run_map.current_node_id
	var is_selectable := run_map.can_select_node(node.id)
	var is_completed := node.completed
	
	if is_completed:
		button.modulate = Color(0.5, 0.5, 0.5)
		button.disabled = true
	elif is_selectable:
		button.modulate = EncounterType.get_display_color(node.type)
		button.pressed.connect(_on_node_selected.bind(node.id))
	else:
		button.modulate = Color(0.3, 0.3, 0.3)
		button.disabled = true
	
	if is_current:
		button.add_theme_stylebox_override("normal", _create_border_style(Color.WHITE))
	
	return button

func _draw_connection(from_node: EncounterNode, to_node: EncounterNode, start_x: float, start_y: float, layer_height: float, node_spacing: float) -> void:
	var from_pos := Vector2(start_x + from_node.position_in_layer * node_spacing + 40, start_y + from_node.layer_index * layer_height + 60)
	var to_pos := Vector2(start_x + to_node.position_in_layer * node_spacing + 40, start_y + to_node.layer_index * layer_height)
	
	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 2
	line.default_color = Color(0.4, 0.4, 0.4, 0.6)
	map_container.add_child(line)

func _create_border_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.border_color = color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	return style

func _on_node_selected(node_id: String) -> void:
	selected_node_id = node_id
	var node := run_map.get_node(node_id)
	if node == null:
		return
	
	info_label.text = "%s\nLayer %d" % [EncounterType.get_display_name(node.type), node.layer_index]
	info_label.add_theme_color_override("font_color", EncounterType.get_display_color(node.type))
	confirm_button.disabled = false
	
	encounter_selected.emit(node)

func _on_confirm_button_pressed() -> void:
	if selected_node_id.is_empty():
		return
	
	var node := run_map.get_node(selected_node_id)
	if node == null:
		return
	
	_enter_battle(node)

func _enter_battle(node: EncounterNode) -> void:
	is_in_battle = true
	
	# Select the node in the map
	run_map.select_node(node.id)
	
	# Generate encounter config
	var temp_encounter_manager := EncounterManager.new()
	var config := temp_encounter_manager.create_config_from_node(node)
	
	# Hide map UI
	visible = false
	
	# Instantiate and show battle scene
	if main_game == null:
		main_game = MAIN_GAME_SCENE.instantiate()
		main_game.battle_complete.connect(_on_battle_complete)
		add_child(main_game)
	
	main_game.visible = true
	# Use call_deferred to ensure scene is fully ready
	main_game.call_deferred("start_battle", config)

func _on_battle_complete(winner: String, encounter_type: int) -> void:
	is_in_battle = false
	
	var player_won := winner == MainGame.OWNER_PLAYER
	
	# Mark node as completed
	run_map.complete_current_node()
	
	# Hide battle scene
	if main_game != null:
		main_game.visible = false
	
	# Check if run is over
	if run_map.is_map_completed():
		run_completed.emit(player_won)
		_show_run_end_screen(player_won)
	else:
		# Return to map
		visible = true
		selected_node_id = ""
		_setup_map_button()
		info_label.text = "Select your next destination"
		info_label.remove_theme_color_override("font_color")
		_refresh_map_ui()

func _setup_map_button() -> void:
	confirm_button.text = "Enter Encounter"
	confirm_button.disabled = true
	# Safely disconnect any existing connections
	for conn in confirm_button.pressed.get_connections():
		confirm_button.pressed.disconnect(conn.callable)
	confirm_button.pressed.connect(_on_confirm_button_pressed)

func _setup_new_run_button() -> void:
	confirm_button.text = "Start New Run"
	confirm_button.disabled = false
	# Safely disconnect any existing connections
	for conn in confirm_button.pressed.get_connections():
		confirm_button.pressed.disconnect(conn.callable)
	confirm_button.pressed.connect(_on_new_run_pressed)

func _on_new_run_pressed() -> void:
	_start_new_run()

func _show_run_end_screen(victory: bool) -> void:
	visible = true
	# Hide map, show end screen
	for child in map_container.get_children():
		child.visible = false
	
	info_label.text = "Victory! Run Complete!" if victory else "Defeated... Run Over"
	info_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3) if victory else Color(0.8, 0.3, 0.3))
	
	_setup_new_run_button()

func get_current_run_state() -> Dictionary:
	if run_map == null:
		return {}
	return run_map.to_dict()

func load_run_state(data: Dictionary) -> void:
	run_map = RunMap.new(data.get("max_layers", 4))
	run_map.from_dict(data)
	_refresh_map_ui()
