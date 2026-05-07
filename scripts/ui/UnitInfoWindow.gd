extends Control
class_name UnitInfoWindow

var card_data: CardData = null
var creature: Creature = null

# Label references
var title_label: Label
var cost_label: Label
var combat_label: Label
var movement_label: Label
var type_label: Label
var description_label: Label
var health_status: Label
var position_status: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow input to pass through when hidden
	z_index = 100  # Ensure popup is on top
	_build_window()

func _build_window() -> void:
	# Set window size
	custom_minimum_size = Vector2(300, 200)
	size = Vector2(320, 220)
	
	# Background panel
	var background := Panel.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(background)
	
	# Main container
	var main_container := VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Add margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	main_container.add_child(margin)
	
	var content_container := VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 8)
	margin.add_child(content_container)
	
	# Title label
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	content_container.add_child(title_label)
	
	# Stats container
	var stats_container := HBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 20)
	content_container.add_child(stats_container)
	
	# Cost
	cost_label = Label.new()
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	stats_container.add_child(cost_label)
	
	# Attack/Health
	combat_label = Label.new()
	combat_label.add_theme_font_size_override("font_size", 16)
	combat_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	stats_container.add_child(combat_label)
	
	# Movement
	movement_label = Label.new()
	movement_label.add_theme_font_size_override("font_size", 16)
	movement_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	stats_container.add_child(movement_label)
	
	# Type label
	type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content_container.add_child(type_label)
	
	# Description
	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(250, 0)
	content_container.add_child(description_label)
	
	# Current status (if creature exists)
	var status_container := VBoxContainer.new()
	status_container.name = "status_container"
	status_container.add_theme_constant_override("separation", 4)
	content_container.add_child(status_container)
	
	var status_title := Label.new()
	status_title.text = "Current Status:"
	status_title.add_theme_font_size_override("font_size", 14)
	status_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	status_container.add_child(status_title)
	
	health_status = Label.new()
	health_status.add_theme_font_size_override("font_size", 12)
	health_status.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	status_container.add_child(health_status)
	
	position_status = Label.new()
	position_status.add_theme_font_size_override("font_size", 12)
	position_status.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	status_container.add_child(position_status)

func show_unit_info(unit_creature: Creature) -> void:
	print("UnitInfoWindow: show_unit_info called")
	creature = unit_creature
	
	if creature == null:
		print("UnitInfoWindow: creature is null!")
		return
		
	card_data = creature.card_data
	
	if card_data == null:
		print("UnitInfoWindow: card_data is null, hiding")
		hide()
		return
	
	print("UnitInfoWindow: Showing info for %s" % card_data.display_name)
	_update_display()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block input when visible
	
	# Position window near the selected unit
	_position_near_unit()
	print("UnitInfoWindow: Window positioned at %s" % str(global_position))

func hide_info() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow input when hidden
	creature = null
	card_data = null

func _update_display() -> void:
	if card_data == null:
		return
	
	# Update title
	title_label.text = card_data.display_name
	
	# Update stats
	cost_label.text = "Cost: %d" % card_data.cost
	combat_label.text = "%d/%d" % [card_data.attack, card_data.health]
	movement_label.text = "Move: %d" % card_data.movement
	
	# Update type
	type_label.text = "Type: %s" % card_data.type_name()
	
	# Update description
	description_label.text = card_data.description
	
	# Update status if creature exists
	if creature != null:
		health_status.text = "Health: %d/%d" % [creature.current_health, creature.card_data.health]
		position_status.text = "Position: (%d, %d)" % [creature.cell.x, creature.cell.y]
	else:
		health_status.text = ""
		position_status.text = ""

func _position_near_unit() -> void:
	if creature == null:
		return
	
	# Get unit's screen position
	var unit_pos = creature.global_position
	
	# Use minimum size if actual size not yet calculated
	var window_size := size
	if window_size.x < 10:
		window_size = custom_minimum_size
	
	var screen_size = get_viewport().get_visible_rect().size
	
	# Set window position (offset to avoid covering the unit)
	var pos_x = unit_pos.x + 60
	var pos_y = unit_pos.y - window_size.y / 2
	
	# Keep window on screen
	if pos_x + window_size.x > screen_size.x:
		pos_x = unit_pos.x - window_size.x - 60
	if pos_y < 10:
		pos_y = 10
	if pos_y + window_size.y > screen_size.y - 10:
		pos_y = screen_size.y - window_size.y - 10
	
	global_position = Vector2(pos_x, pos_y)

func _input(event: InputEvent) -> void:
	# Hide window when clicking outside or pressing ANY key
	if visible:
		if event is InputEventMouseButton and event.pressed:
			if not get_global_rect().has_point(event.global_position):
				hide_info()
		elif event is InputEventKey and event.pressed:
			# Any key press dismisses the popup
			hide_info()
			# Don't consume the event so other handlers can process it if needed

func _create_panel_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.55, 0.4, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	return style
