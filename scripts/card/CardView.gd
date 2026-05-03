extends Control
class_name CardView

signal card_clicked(card_view: CardView, card_data: CardData)

var card_data: CardData
var selected := false

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/Margin/VBox/Header/NameLabel
@onready var type_label: Label = $Panel/Margin/VBox/TypeLabel
@onready var cost_label: Label = $Panel/Margin/VBox/Header/CostLabel
@onready var body_label: Label = $Panel/Margin/VBox/BodyLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_visuals_mouse_filter_ignore(panel)
	pivot_offset = custom_minimum_size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


func setup(data: CardData) -> void:
	card_data = data
	if is_inside_tree():
		_refresh()


func _set_visuals_mouse_filter_ignore(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_visuals_mouse_filter_ignore(child)


func _refresh() -> void:
	if card_data == null or not is_inside_tree():
		return
	name_label.text = card_data.display_name
	type_label.text = card_data.type_name()
	cost_label.text = str(card_data.cost)
	body_label.text = card_data.rules_text()
	stats_label.text = card_data.stats_line()

	var style := StyleBoxFlat.new()
	style.bg_color = card_data.accent_color.darkened(0.18)
	style.border_color = Color(0.88, 0.82, 0.62, 0.95)
	style.set_border_width_all(2)
	if selected:
		style.border_color = Color(1.0, 0.92, 0.32, 1)
		style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1))
	type_label.add_theme_color_override("font_color", Color(0.83, 0.78, 0.62, 1))
	cost_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1))
	body_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84, 1))
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.66, 1))
	name_label.add_theme_font_size_override("font_size", 15)
	cost_label.add_theme_font_size_override("font_size", 15)
	type_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_font_size_override("font_size", 13)


func set_selected(value: bool) -> void:
	selected = value
	if selected:
		scale = Vector2(1.08, 1.08)
		z_index = 30
	else:
		scale = Vector2.ONE
		z_index = 0
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(self, card_data)
		get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	if not selected:
		scale = Vector2(1.06, 1.06)
		z_index = 20


func _on_mouse_exited() -> void:
	if not selected:
		scale = Vector2.ONE
		z_index = 0
