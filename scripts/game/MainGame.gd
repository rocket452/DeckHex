extends Control
class_name MainGame

signal battle_complete(winner: String, encounter_type: int)
signal battle_started(encounter_type: int)

const OWNER_PLAYER := "player"
const OWNER_ENEMY := "enemy"
const CARD_VIEW_SCENE := preload("res://scenes/CardView.tscn")
const CREATURE_SCENE := preload("res://scenes/Creature.tscn")

var current_encounter_type: EncounterType.Type = EncounterType.Type.PVP_ENCOUNTER

var player: Player
var enemy: Enemy
var creatures: Array[Creature] = []
var hero: Creature

var encounter_manager: EncounterManager = EncounterManager.new()
var current_config: EncounterConfig = null
var selected_creature: Creature
var selected_card: CardData
var selected_card_view: CardView
var current_move_cells: Array[Vector2i] = []
var current_attack_cells: Array[Vector2i] = []
var log_lines: Array[String] = []
var warning_serial := 0

var board_control: Control
var creature_layer: Control
var grid: GridManager
var hand_row: HBoxContainer
var combat_log: RichTextLabel
var warning_panel: PanelContainer
var warning_label: Label
var hero_health_label: Label
var enemy_health_label: Label
var hero_health_bar: ProgressBar
var enemy_health_bar: ProgressBar
var enemy_status_panel: PanelContainer
var enemy_status_label: Label
var mana_label: Label
var deck_label: Label
var turn_label: Label
var end_turn_button: Button
var end_overlay: Control
var end_title_label: Label
var end_body_label: Label
var unit_info_window: UnitInfoWindow
var simulation_runner: SimulationRunner = null


func _ready() -> void:
	randomize()
	_build_layout()
	_connect_turn_signals()
	# Note: Game no longer auto-starts. Use start_battle() to begin.


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.09, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 66)
	top_bar.add_theme_constant_override("separation", 8)
	root.add_child(top_bar)

	var hero_readout := _add_health_readout(top_bar, "Hero 25/25", Color(0.13, 0.21, 0.24, 0.94), 25)
	hero_health_label = hero_readout["label"]
	hero_health_bar = hero_readout["bar"]
	var enemy_readout := _add_health_readout(top_bar, "Nexus 20/20", Color(0.28, 0.15, 0.16, 0.94), GameManager.STARTING_LIFE)
	enemy_health_label = enemy_readout["label"]
	enemy_health_bar = enemy_readout["bar"]
	mana_label = _add_stat_pill(top_bar, "Mana 0/0", Color(0.14, 0.18, 0.32, 0.94))
	deck_label = _add_stat_pill(top_bar, "Deck 0", Color(0.18, 0.18, 0.2, 0.94))
	turn_label = _add_stat_pill(top_bar, "Turn 1", Color(0.20, 0.18, 0.13, 0.94))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(132, 44)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	top_bar.add_child(end_turn_button)

	warning_panel = PanelContainer.new()
	warning_panel.visible = false
	warning_panel.custom_minimum_size = Vector2(0, 34)
	warning_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.38, 0.16, 0.12, 0.96), Color(0.96, 0.58, 0.36, 1)))
	root.add_child(warning_panel)

	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.80, 1))
	warning_label.add_theme_font_size_override("font_size", 15)
	warning_panel.add_child(warning_label)

	var battlefield_row := HBoxContainer.new()
	battlefield_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battlefield_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield_row.add_theme_constant_override("separation", 12)
	root.add_child(battlefield_row)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.13, 0.92), Color(0.58, 0.52, 0.36, 0.8)))
	battlefield_row.add_child(board_panel)

	board_control = Control.new()
	board_control.mouse_filter = Control.MOUSE_FILTER_STOP
	board_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_control.gui_input.connect(_on_board_gui_input)
	board_control.mouse_exited.connect(_on_board_mouse_exited)
	board_panel.add_child(board_control)

	grid = GridManager.new()
	grid.name = "Grid"
	board_control.add_child(grid)

	creature_layer = Control.new()
	creature_layer.name = "CreatureLayer"
	creature_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	creature_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_control.add_child(creature_layer)
	board_control.resized.connect(_layout_board)
	
	# Add unit info window
	unit_info_window = preload("res://scenes/UnitInfoWindow.tscn").instantiate()
	unit_info_window.name = "UnitInfoWindow"
	add_child(unit_info_window)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(272, 0)
	side_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.12, 0.14, 0.94), Color(0.45, 0.43, 0.36, 0.9)))
	battlefield_row.add_child(side_panel)

	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	enemy_status_panel = PanelContainer.new()
	enemy_status_panel.custom_minimum_size = Vector2(0, 94)
	enemy_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_status_panel.gui_input.connect(_on_enemy_panel_gui_input)
	enemy_status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.29, 0.14, 0.15, 0.92), Color(0.88, 0.46, 0.40, 0.95)))
	side_box.add_child(enemy_status_panel)

	enemy_status_label = Label.new()
	enemy_status_label.text = "Enemy"
	enemy_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enemy_status_label.add_theme_font_size_override("font_size", 18)
	enemy_status_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1))
	enemy_status_panel.add_child(enemy_status_label)

	var log_title := Label.new()
	log_title.text = "Battle Log"
	log_title.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62, 1))
	log_title.add_theme_font_size_override("font_size", 18)
	side_box.add_child(log_title)

	combat_log = RichTextLabel.new()
	combat_log.fit_content = false
	combat_log.scroll_following = true
	combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log.bbcode_enabled = false
	combat_log.add_theme_color_override("default_color", Color(0.91, 0.89, 0.81, 1))
	side_box.add_child(combat_log)

	var hand_panel := PanelContainer.new()
	hand_panel.custom_minimum_size = Vector2(0, 236)
	hand_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.105, 0.115, 0.96), Color(0.46, 0.42, 0.33, 0.88)))
	root.add_child(hand_panel)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_panel.add_child(hand_scroll)

	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(hand_row)

	_build_end_overlay()


func _build_end_overlay() -> void:
	end_overlay = Control.new()
	end_overlay.visible = false
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(end_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.03, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 220)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.14, 0.16, 0.98), Color(0.86, 0.74, 0.45, 1)))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	end_title_label = Label.new()
	end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title_label.add_theme_font_size_override("font_size", 34)
	end_title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.76, 1))
	box.add_child(end_title_label)

	end_body_label = Label.new()
	end_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 1))
	box.add_child(end_body_label)

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 42)
	continue_button.pressed.connect(_on_continue_pressed)
	box.add_child(continue_button)


func _add_stat_pill(parent: Control, text: String, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(142, 50)
	panel.add_theme_stylebox_override("panel", _panel_style(color, Color(0.58, 0.52, 0.38, 0.72)))
	parent.add_child(panel)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82, 1))
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	return label


func _add_health_readout(parent: Control, text: String, color: Color, max_value: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(188, 56)
	panel.add_theme_stylebox_override("panel", _panel_style(color, Color(0.58, 0.52, 0.38, 0.72)))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82, 1))
	label.add_theme_font_size_override("font_size", 15)
	box.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	box.add_child(bar)
	return {"label": label, "bar": bar}


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _connect_turn_signals() -> void:
	if not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)
	if not TurnManager.enemy_turn_started.is_connected(_on_enemy_turn_started):
		TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	if not TurnManager.game_over.is_connected(_on_game_over):
		TurnManager.game_over.connect(_on_game_over)


func start_battle(config: EncounterConfig = null) -> void:
	if config == null:
		config = EncounterConfig.new(EncounterType.Type.PVP_ENCOUNTER)
	
	current_config = config
	current_encounter_type = config.encounter_type
	battle_started.emit(config.encounter_type)
	_start_new_game()

func set_simulated_pvp_mode() -> void:
	# Configure for simulated PvP: Lyonar vs Abyssian
	var config := EncounterConfig.new(EncounterType.Type.PVP_ENCOUNTER)
	config.player_deck = LyonarDeck.build_deck()
	config.enemy_deck = AbyssianDeck.build_deck()
	config.player_faction = "Lyonar"
	config.enemy_faction = "Abyssian"
	config.is_simulated_pvp = true
	
	# Set this as the current config
	current_config = config
	current_encounter_type = config.encounter_type

func _start_new_game() -> void:
	GameManager.load_cards()
	_clear_creatures()
	grid.setup_board()
	grid.clear_highlights()
	grid.clear_enemy_movement_highlights()
	selected_creature = null
	selected_card = null
	selected_card_view = null
	current_move_cells.clear()
	current_attack_cells.clear()
	log_lines.clear()
	end_overlay.visible = false
	hero = null

	player = Player.new()
	enemy = Enemy.new()
	
	# Use faction-specific decks if configured
	var player_deck = GameManager.build_player_deck()
	var enemy_deck = GameManager.build_enemy_deck()
	
	if current_config != null and current_config.is_simulated_pvp:
		if current_config.player_deck:
			player_deck = current_config.player_deck
		if current_config.enemy_deck:
			enemy_deck = current_config.enemy_deck
	
	player.setup("Player", player_deck, GameManager.STARTING_LIFE, GameManager.STARTING_HAND_SIZE)
	
	# Use encounter manager to setup the enemy based on encounter type
	if current_config != null:
		encounter_manager.current_config = current_config
		encounter_manager.current_ai_controller = encounter_manager.create_ai_controller(self, current_config)
		encounter_manager._apply_config_to_game(self, current_config)
	else:
		# Default setup for PvP
		enemy.setup(enemy.choose_display_name(), GameManager.build_enemy_deck(), GameManager.STARTING_LIFE, 0)
		encounter_manager.current_config = EncounterConfig.new(EncounterType.Type.PVP_ENCOUNTER)
		encounter_manager.current_ai_controller = encounter_manager.create_ai_controller(self, encounter_manager.current_config)
	
	hero = spawn_hero()
	
	# Initial spawns for rule-based encounters happen in AI start_turn
	if encounter_manager.current_config == null:
		spawn_initial_enemy_horde()
	elif encounter_manager.current_config.ai_type == EncounterConfig.AIType.DECK_BASED:
		if encounter_manager.current_config.is_simulated_pvp:
			# Spawn enemy hero for simulated PvP
			spawn_enemy_hero()
		else:
			# Spawn zombie horde for regular deck-based encounters
			spawn_initial_enemy_horde()

	log_event("Your Hero takes the left-center spawn hex.")
	log_event("Battle begins on a pointy-top hex grid.")
	_refresh_enemy_movement_highlights()
	TurnManager.start_game()
	_layout_board()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			print("MainGame: Right click detected at %s" % str(event.global_position))
			print("MainGame: unit_info_window exists: %s" % str(is_instance_valid(unit_info_window)))
			_handle_unit_selection(event.global_position)

func _handle_unit_selection(click_position: Vector2) -> void:
	# Check if clicking on a creature or hero (anywhere on their hex tile)
	var clicked_creature: Creature = null
	
	# Find which cell was clicked
	var clicked_cell := _get_cell_at_position(click_position)
	print("MainGame: Clicked cell: %s" % str(clicked_cell))
	
	# Debug: Show all creature positions
	print("MainGame: All creatures:")
	for creature in creatures:
		if is_instance_valid(creature):
			print("  - %s at cell %s, pos %s" % [creature.name, str(creature.cell), str(creature.global_position)])
	
	# Check if any creature occupies this cell
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		
		if creature.cell == clicked_cell:
			clicked_creature = creature
			print("MainGame: Found creature %s at cell %s" % [creature.name, str(creature.cell)])
			break
	
	if clicked_creature != null:
		print("MainGame: Showing info for creature: %s" % clicked_creature.name)
		unit_info_window.show_unit_info(clicked_creature)
	else:
		print("MainGame: No creature on clicked hex")
		# Only hide if not clicking on the info window itself
		if unit_info_window.visible and not unit_info_window.get_global_rect().has_point(click_position):
			unit_info_window.hide_info()

func _get_cell_at_position(pos: Vector2) -> Vector2i:
	# Use GridManager's accurate hex detection
	if not is_instance_valid(grid):
		return Vector2i(-1, -1)
	
	# Convert global position to local position within the grid
	var local_pos := pos - grid.global_position
	
	# Use GridManager's polygon-based detection
	return grid.local_to_cell(local_pos)

func _on_player_turn_started(turn_number: int) -> void:
	for creature in get_player_creatures():
		creature.begin_turn()
	player.begin_turn(turn_number)
	_clear_selection()
	_refresh_enemy_movement_highlights()
	log_event("Turn %d: you draw and refill mana." % turn_number)
	render_hand()
	update_ui()


func _on_enemy_turn_started(turn_number: int) -> void:
	call_deferred("_run_enemy_turn", turn_number)


func _run_enemy_turn(turn_number: int) -> void:
	if TurnManager.is_game_over():
		return
	_clear_selection()
	for creature in get_enemy_creatures():
		creature.begin_turn()
	
	# Get the appropriate AI controller from encounter manager
	var ai_controller := encounter_manager.get_ai_controller()
	if ai_controller == null:
		# Fallback: create default deck-based AI
		if current_config == null:
			current_config = EncounterConfig.new(EncounterType.Type.PVP_ENCOUNTER)
		ai_controller = encounter_manager.create_ai_controller(self, current_config)
	
	# Let AI prepare for turn (spawns, etc.)
	ai_controller.start_turn()
	
	# Handle deck-based vs rule-based differently
	if encounter_manager.current_config != null and encounter_manager.current_config.ai_type == EncounterConfig.AIType.DECK_BASED:
		enemy.begin_turn(turn_number)
		log_event("Enemy draws and refills mana.")
		render_hand()
	else:
		# Rule-based enemies don't draw cards
		log_event("Enemy prepares for battle.")
	
	update_ui()
	_refresh_enemy_movement_highlights()
	await ai_controller.take_turn()


func _on_game_over(winner: String) -> void:
	update_ui()
	end_overlay.visible = true
	if winner == OWNER_PLAYER:
		end_title_label.text = "Victory"
		end_body_label.text = "The enemy Nexus reached 0 health."
	else:
		end_title_label.text = "Defeat"
		end_body_label.text = "Your Hero fell in battle."
	battle_complete.emit(winner, current_encounter_type)

func _on_continue_pressed() -> void:
	end_overlay.visible = false


func render_hand() -> void:
	for child in hand_row.get_children():
		child.queue_free()
	for card in player.hand:
		var card_view: CardView = CARD_VIEW_SCENE.instantiate()
		hand_row.add_child(card_view)
		card_view.setup(card)
		card_view.card_clicked.connect(_on_card_clicked)


func update_ui() -> void:
	if player == null or enemy == null:
		return
	var hero_health := 0
	var hero_max_health := 0
	if is_instance_valid(hero):
		hero_health = hero.current_health
		hero_max_health = hero.card_data.health
	hero_health_label.text = "Hero %d/%d" % [hero_health, hero_max_health]
	hero_health_bar.max_value = hero_max_health
	hero_health_bar.value = hero_health
	enemy_health_label.text = "Nexus %d/%d" % [enemy.life, GameManager.STARTING_LIFE]
	enemy_health_bar.max_value = GameManager.STARTING_LIFE
	enemy_health_bar.value = enemy.life
	mana_label.text = "Mana %d/%d" % [player.current_mana, player.max_mana]
	deck_label.text = "Deck %d" % player.deck.size()
	var phase_text := "Player"
	if TurnManager.is_enemy_turn():
		phase_text = "Enemy"
	elif TurnManager.is_game_over():
		phase_text = "Game Over"
	turn_label.text = "Turn %d: %s" % [TurnManager.turn_number, phase_text]
	enemy_status_label.text = "%s\nNexus %d\n%d cards" % [enemy.display_name, enemy.life, enemy.hand.size()]
	end_turn_button.disabled = not TurnManager.is_player_turn()


func _on_end_turn_pressed() -> void:
	if not TurnManager.is_player_turn():
		return
	_clear_selection()
	log_event("You end the turn.")
	update_ui()
	TurnManager.start_enemy_turn()


func log_event(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 9:
		log_lines.pop_front()
	if combat_log != null:
		combat_log.text = "\n".join(PackedStringArray(log_lines))


func warn_player(message: String) -> void:
	log_event("Warning: %s" % message)
	if warning_label == null or warning_panel == null:
		return
	warning_serial += 1
	var serial := warning_serial
	warning_label.text = message
	warning_panel.visible = true
	await get_tree().create_timer(2.2).timeout
	if serial == warning_serial and warning_panel != null:
		warning_panel.visible = false


func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_card_clicked(card_view: CardView, card_data: CardData) -> void:
	if not TurnManager.is_player_turn() or card_data == null:
		warn_player("Cards can only be played during your turn.")
		return
	if selected_card_view == card_view:
		_clear_selection()
		return

	_clear_selection()
	if card_data.is_land() and player.played_land_this_turn:
		warn_player("You already played a land this turn.")
		return
	if not card_data.is_land() and not player.can_pay(card_data.cost):
		warn_player("Not enough mana for %s. Need %d, have %d." % [card_data.display_name, card_data.cost, player.current_mana])
		return

	selected_card = card_data
	selected_card_view = card_view
	selected_card_view.set_selected(true)
	_refresh_selected_card_highlights()
	if card_data.is_land():
		log_event("Selected %s. Click any board hex to play it." % card_data.display_name)
	else:
		log_event("Selected %s. Click a highlighted target." % card_data.display_name)


func _refresh_selected_card_highlights() -> void:
	grid.clear_highlights()
	if selected_card == null:
		return
	if selected_card.is_land():
		grid.add_highlights(grid.board_cells, Color(0.82, 0.70, 0.30, 0.14))
	elif selected_card.is_creature():
		var open_cells: Array[Vector2i] = []
		var occupied := get_occupied_cells()
		for cell in grid.get_player_summon_cells():
			if not occupied.has(cell):
				open_cells.append(cell)
		grid.add_highlights(open_cells, Color(0.30, 0.78, 0.42, 0.30))
	elif selected_card.is_spell():
		var target_cells: Array[Vector2i] = []
		for creature in get_enemy_creatures():
			target_cells.append(creature.cell)
		grid.add_highlights(target_cells, Color(0.94, 0.28, 0.22, 0.33))
		grid.add_highlights(grid.get_enemy_home_cells(), Color(0.94, 0.28, 0.22, 0.18))


func _try_play_selected_card_on_cell(cell: Vector2i) -> void:
	if selected_card == null:
		return
	var played := false
	if selected_card.is_land():
		played = play_player_land(selected_card)
	elif selected_card.is_creature():
		played = play_player_creature(selected_card, cell)
	elif selected_card.is_spell():
		played = play_player_spell_on_cell(selected_card, cell)

	if played:
		_clear_selection()
		render_hand()
		update_ui()
	else:
		_refresh_selected_card_highlights()


func play_player_land(card: CardData) -> bool:
	if player.played_land_this_turn:
		warn_player("You already played a land this turn.")
		return false
	if player.play_land(card):
		log_event("You play %s and gain +%d max mana." % [card.display_name, max(1, card.mana_bonus)])
		return true
	warn_player("%s is no longer in your hand." % card.display_name)
	return false


func play_player_creature(card: CardData, cell: Vector2i) -> bool:
	if not player.can_pay(card.cost):
		warn_player("Not enough mana for %s. Need %d, have %d." % [card.display_name, card.cost, player.current_mana])
		return false
	if not grid.is_player_summon_cell(cell):
		warn_player("%s is out of range. Summon on a highlighted player-side hex." % card.display_name)
		return false
	if get_creature_at_cell(cell) != null:
		warn_player("That hex is occupied.")
		return false
	if not player.pay_mana(card.cost):
		return false
	if not player.remove_from_hand(card):
		player.refund_mana(card.cost)
		return false
	spawn_creature(card, OWNER_PLAYER, cell)
	log_event("You summon %s." % card.display_name)
	return true


func play_player_spell_on_cell(card: CardData, cell: Vector2i) -> bool:
	var target := get_creature_at_cell(cell)
	var target_nexus := target == null and grid.is_enemy_home_cell(cell)
	if target != null and target.owner_id != OWNER_ENEMY:
		target = null
	if target == null and not target_nexus:
		warn_player("%s is out of range. Target a highlighted enemy or Nexus hex." % card.display_name)
		return false
	return play_player_spell_at_target(card, target, target_nexus)


func play_player_spell_at_nexus(card: CardData) -> bool:
	return play_player_spell_at_target(card, null, true)


func play_player_spell_at_target(card: CardData, target: Creature, target_nexus: bool) -> bool:
	if not player.can_pay(card.cost):
		warn_player("Not enough mana for %s. Need %d, have %d." % [card.display_name, card.cost, player.current_mana])
		return false
	if not player.pay_mana(card.cost):
		return false
	if not player.remove_from_hand(card):
		player.refund_mana(card.cost)
		return false
	player.discard_card(card)
	if is_instance_valid(target):
		log_event("You cast %s on %s for %d." % [card.display_name, target.card_data.display_name, card.spell_damage])
		target.take_damage(card.spell_damage)
	elif target_nexus:
		log_event("You cast %s at the enemy Nexus for %d." % [card.display_name, card.spell_damage])
		enemy.take_damage(card.spell_damage)
	else:
		warn_player("%s is out of range. Target a highlighted enemy or Nexus hex." % card.display_name)
		return false
	_check_game_over()
	return true


func enemy_play_land(card: CardData) -> bool:
	if enemy.play_land(card):
		log_event("Enemy plays %s." % card.display_name)
		update_ui()
		return true
	return false


func enemy_play_creature(card: CardData, cell: Vector2i) -> bool:
	if not enemy.can_pay(card.cost):
		return false
	if not grid.is_enemy_summon_cell(cell) or get_creature_at_cell(cell) != null:
		return false
	if not enemy.pay_mana(card.cost):
		return false
	if not enemy.remove_from_hand(card):
		enemy.refund_mana(card.cost)
		return false
	spawn_creature(card, OWNER_ENEMY, cell)
	log_event("Enemy summons %s." % card.display_name)
	_refresh_enemy_movement_highlights()
	update_ui()
	return true


func enemy_play_spell(card: CardData) -> bool:
	if not enemy.can_pay(card.cost):
		return false
	var target: Creature = hero
	if not is_instance_valid(target):
		target = _lowest_health_creature(get_player_creatures())
	if not enemy.pay_mana(card.cost):
		return false
	if not enemy.remove_from_hand(card):
		enemy.refund_mana(card.cost)
		return false
	enemy.discard_card(card)
	if is_instance_valid(target):
		log_event("Enemy casts %s on %s for %d." % [card.display_name, target.card_data.display_name, card.spell_damage])
		target.take_damage(card.spell_damage)
	else:
		log_event("Enemy casts %s, but finds no Hero target." % card.display_name)
	_check_game_over()
	update_ui()
	return true


func spawn_hero() -> Creature:
	var hero_card: CardData = null
	
	# Find hero card in player's deck or hand
	# Use specific keywords: "General", "Commander", or "Weaver" (unique to heroes)
	# Avoid "Soul" which matches spells like "Soulshatter"
	for card in player.deck:
		if "General" in card.display_name or "Commander" in card.display_name or "Weaver" in card.display_name:
			print("Found hero in deck: %s" % card.display_name)
			hero_card = card
			break
	
	# Check hand if not found in deck
	if hero_card == null:
		for card in player.hand:
			if "General" in card.display_name or "Commander" in card.display_name or "Weaver" in card.display_name:
				print("Found hero in hand: %s" % card.display_name)
				hero_card = card
				break
	
	# Fallback to default hero if no faction hero found
	if hero_card == null:
		print("WARNING: Faction hero not found, using default hero")
		hero_card = GameManager.get_card("hero")
	else:
		print("Spawning player hero: %s (%d/%d)" % [hero_card.display_name, hero_card.attack, hero_card.health])
	
	var spawn_cell := grid.get_player_hero_spawn_cell()
	return spawn_creature(hero_card, OWNER_PLAYER, spawn_cell, true)


func spawn_initial_enemy_horde() -> void:
	var zombie_card := GameManager.get_card("zombie")
	for cell in grid.get_enemy_summon_cells():
		if get_creature_at_cell(cell) == null:
			spawn_creature(zombie_card, OWNER_ENEMY, cell)


func spawn_enemy_hero() -> void:
	# Find the hero card in enemy's deck or hand
	var hero_card: CardData = null
	
	# Check deck first
	# Use specific keywords to avoid matching spell cards
	for card in enemy.deck:
		if "General" in card.display_name or "Commander" in card.display_name or "Weaver" in card.display_name:
			print("Found enemy hero in deck: %s" % card.display_name)
			hero_card = card
			break
	
	# Check hand if not found in deck
	if hero_card == null:
		for card in enemy.hand:
			if "General" in card.display_name or "Commander" in card.display_name or "Weaver" in card.display_name:
				print("Found enemy hero in hand: %s" % card.display_name)
				hero_card = card
				break
	
	# Fallback: use first card from deck if no hero found
	if hero_card == null and enemy.deck.size() > 0:
		hero_card = enemy.deck[0]
		print("WARNING: Enemy hero not found, using first deck card: %s" % hero_card.display_name)
	
	if hero_card:
		print("Spawning enemy hero: %s (%d/%d)" % [hero_card.display_name, hero_card.attack, hero_card.health])
		# Spawn hero at right-center position
		var hero_cell := Vector2i(grid.columns - 2, grid.rows / 2)
		if get_creature_at_cell(hero_cell) == null:
			var enemy_hero := spawn_creature(hero_card, OWNER_ENEMY, hero_cell, true)
			log_event("Enemy %s takes the right-center spawn hex." % hero_card.display_name)
		else:
			# Fallback to any enemy spawn cell
			for cell in grid.get_enemy_summon_cells():
				if get_creature_at_cell(cell) == null:
					spawn_creature(hero_card, OWNER_ENEMY, cell, true)
					log_event("Enemy %s takes a spawn position." % hero_card.display_name)
					break


func spawn_creature(card: CardData, owner_id: String, cell: Vector2i, hero_unit := false) -> Creature:
	var creature: Creature = CREATURE_SCENE.instantiate()
	creature_layer.add_child(creature)
	creature.setup(card, owner_id, cell, TurnManager.turn_number, hero_unit)
	creature.died.connect(_on_creature_died)
	creatures.append(creature)
	_position_creature(creature, false)
	_refresh_enemy_movement_highlights()
	return creature


func summon_enemy_creature(card: CardData, cell: Vector2i) -> Creature:
	# Convenience method for AI controllers to spawn enemy creatures
	var creature := spawn_creature(card, OWNER_ENEMY, cell, false)
	if creature != null:
		log_event("Enemy summons %s!" % card.display_name)
	return creature


func move_creature(creature: Creature, target_cell: Vector2i) -> bool:
	if creature == null or not grid.is_valid_cell(target_cell):
		return false
	if get_creature_at_cell(target_cell) != null:
		return false
	creature.cell = target_cell
	creature.mark_moved()
	_position_creature(creature, true)
	log_event("%s moves." % creature.card_data.display_name)
	_refresh_enemy_movement_highlights()
	return true


func creature_attack_creature(attacker: Creature, target: Creature) -> bool:
	if attacker == null or target == null:
		return false
	if attacker.owner_id == target.owner_id:
		return false
	if not attacker.can_attack(TurnManager.turn_number):
		return false
	if grid.hex_distance(attacker.cell, target.cell) > attacker.attack_range:
		return false
	attacker.mark_attacked()
	log_event("%s hits %s for %d." % [attacker.card_data.display_name, target.card_data.display_name, attacker.attack])
	await _wait_for_attack_hit(attacker)
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		_check_game_over()
		update_ui()
		return false
	target.take_damage(attacker.attack)
	_check_game_over()
	update_ui()
	return true


func creature_attack_leader(attacker: Creature, target_owner: String) -> bool:
	if attacker == null or not can_attack_leader(attacker, target_owner):
		return false
	attacker.mark_attacked()
	await _wait_for_attack_hit(attacker)
	if not is_instance_valid(attacker):
		_check_game_over()
		update_ui()
		return false
	if target_owner == OWNER_ENEMY:
		log_event("%s attacks the enemy Nexus for %d." % [attacker.card_data.display_name, attacker.attack])
		enemy.take_damage(attacker.attack)
	else:
		if not is_instance_valid(hero):
			return false
		log_event("%s attacks your Hero for %d." % [attacker.card_data.display_name, attacker.attack])
		hero.take_damage(attacker.attack)
	_check_game_over()
	update_ui()
	return true


func can_attack_leader(attacker: Creature, target_owner: String) -> bool:
	if attacker == null or not attacker.can_attack(TurnManager.turn_number):
		return false
	if target_owner == OWNER_PLAYER:
		return is_instance_valid(hero) and grid.hex_distance(attacker.cell, hero.cell) <= attacker.attack_range
	return grid.distance_to_home(attacker.cell, target_owner) <= attacker.attack_range


func find_best_attack_target(attacker: Creature, target_owner: String) -> Creature:
	if target_owner == OWNER_PLAYER and is_instance_valid(hero):
		if grid.hex_distance(attacker.cell, hero.cell) <= attacker.attack_range:
			return hero

	var candidates: Array[Creature] = []
	if target_owner == OWNER_PLAYER:
		candidates = get_player_creatures()
	else:
		candidates = get_enemy_creatures()

	var in_range: Array[Creature] = []
	for creature in candidates:
		if grid.hex_distance(attacker.cell, creature.cell) <= attacker.attack_range:
			in_range.append(creature)
	in_range.sort_custom(func(a: Creature, b: Creature) -> bool:
		if a.current_health == b.current_health:
			return a.attack > b.attack
		return a.current_health < b.current_health
	)
	if in_range.is_empty():
		return null
	return in_range[0]


func get_ai_target_cell(creature: Creature) -> Vector2i:
	if is_instance_valid(hero):
		return hero.cell
	var target_cell := grid.get_player_home_cells()[int(grid.rows / 2)]
	var best_distance := 999
	for target in get_player_creatures():
		var distance := grid.hex_distance(creature.cell, target.cell)
		if distance < best_distance:
			best_distance = distance
			target_cell = target.cell
	return target_cell


func get_best_reachable_cell_toward(creature: Creature, target_cell: Vector2i) -> Vector2i:
	var blocked := get_occupied_cells(creature)
	var reachable := grid.get_reachable_cells(creature.cell, creature.movement, blocked)
	var best_cell := creature.cell
	var best_distance := grid.hex_distance(creature.cell, target_cell)
	for cell in reachable:
		var distance := grid.hex_distance(cell, target_cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func find_enemy_summon_cell() -> Vector2i:
	var occupied := get_occupied_cells()
	var free_cells: Array[Vector2i] = []
	for cell in grid.get_enemy_summon_cells():
		if not occupied.has(cell):
			free_cells.append(cell)
	free_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _enemy_summon_score(a) < _enemy_summon_score(b))
	if free_cells.is_empty():
		return GridManager.INVALID_CELL
	return free_cells[0]


func _enemy_summon_score(cell: Vector2i) -> float:
	var center_y := float(grid.rows - 1) * 0.5
	return abs(float(cell.y) - center_y) + abs(float(cell.x) - float(grid.columns - 2)) * 3.0


func _on_board_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		grid.set_hover_cell(_cell_from_global(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_board_click(_cell_from_global(get_global_mouse_position()))


func _on_board_mouse_exited() -> void:
	grid.set_hover_cell(GridManager.INVALID_CELL)


func _handle_board_click(cell: Vector2i) -> void:
	if not TurnManager.is_player_turn() or not grid.is_valid_cell(cell):
		return

	if selected_card != null:
		_try_play_selected_card_on_cell(cell)
		return

	var clicked_creature := get_creature_at_cell(cell)
	if selected_creature != null:
		if clicked_creature == selected_creature:
			_clear_selection()
			return
		if clicked_creature != null and clicked_creature.owner_id == OWNER_ENEMY and current_attack_cells.has(cell):
			await creature_attack_creature(selected_creature, clicked_creature)
			_clear_selection()
			return
		if current_attack_cells.has(cell) and grid.is_enemy_home_cell(cell) and can_attack_leader(selected_creature, OWNER_ENEMY):
			await creature_attack_leader(selected_creature, OWNER_ENEMY)
			_clear_selection()
			return
		if current_move_cells.has(cell):
			move_creature(selected_creature, cell)
			select_creature(selected_creature)
			return
		if clicked_creature != null and clicked_creature.owner_id == OWNER_PLAYER:
			select_creature(clicked_creature)
			return
		_clear_selection()
		return

	if clicked_creature != null and clicked_creature.owner_id == OWNER_PLAYER:
		select_creature(clicked_creature)


func _on_enemy_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_card != null and TurnManager.is_player_turn():
			var played := false
			if selected_card.is_spell():
				played = play_player_spell_at_nexus(selected_card)
			elif selected_card.is_creature():
				warn_player("%s is out of range. Summon on a highlighted player-side hex." % selected_card.display_name)
			elif selected_card.is_land():
				warn_player("Lands do not target the Nexus. Click any board hex to play the selected land.")
			if played:
				_clear_selection()
				render_hand()
				update_ui()
			else:
				_refresh_selected_card_highlights()
			return
		if selected_creature != null and TurnManager.is_player_turn():
			if await creature_attack_leader(selected_creature, OWNER_ENEMY):
				_clear_selection()
			else:
				warn_player("That creature is not in range of the enemy Nexus.")


func select_creature(creature: Creature) -> void:
	if creature == null or creature.owner_id != OWNER_PLAYER:
		return
	_clear_card_selection(false)
	selected_creature = creature
	current_move_cells.clear()
	current_attack_cells.clear()
	grid.clear_highlights()
	var attack_range_cells: Array[Vector2i] = []

	if creature.can_move(TurnManager.turn_number):
		current_move_cells = grid.get_reachable_cells(creature.cell, creature.movement, get_occupied_cells(creature))
	if creature.can_attack(TurnManager.turn_number):
		attack_range_cells = grid.get_cells_in_range(creature.cell, creature.attack_range)
		for target in get_enemy_creatures():
			if grid.hex_distance(creature.cell, target.cell) <= creature.attack_range:
				current_attack_cells.append(target.cell)
		for home_cell in grid.get_enemy_home_cells():
			if grid.hex_distance(creature.cell, home_cell) <= creature.attack_range:
				current_attack_cells.append(home_cell)

	grid.add_highlights(current_move_cells, Color(0.28, 0.70, 0.42, 0.28))
	grid.add_highlights(attack_range_cells, Color(0.92, 0.20, 0.16, 0.16))
	grid.add_highlights(current_attack_cells, Color(0.95, 0.26, 0.20, 0.34))
	if creature.is_summoning_sick(TurnManager.turn_number):
		log_event("%s will be ready next turn." % creature.card_data.display_name)


func _clear_selection() -> void:
	selected_creature = null
	current_move_cells.clear()
	current_attack_cells.clear()
	_clear_card_selection(false)
	if grid != null:
		grid.clear_highlights()


func _clear_card_selection(clear_grid := true) -> void:
	if is_instance_valid(selected_card_view):
		selected_card_view.set_selected(false)
	selected_card = null
	selected_card_view = null
	if clear_grid and grid != null:
		grid.clear_highlights()


func get_occupied_cells(excluded: Creature = null) -> Dictionary:
	var occupied := {}
	for creature in creatures:
		if is_instance_valid(creature) and creature != excluded:
			occupied[creature.cell] = creature
	return occupied


func get_creature_at_cell(cell: Vector2i) -> Creature:
	for creature in creatures:
		if is_instance_valid(creature) and creature.cell == cell:
			return creature
	return null


func get_creature_at_global_position(global_position: Vector2, owner_filter := "") -> Creature:
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		if not owner_filter.is_empty() and creature.owner_id != owner_filter:
			continue
		if creature.get_global_rect().has_point(global_position):
			return creature
	return null


func get_player_creatures() -> Array[Creature]:
	var result: Array[Creature] = []
	for creature in creatures:
		if is_instance_valid(creature) and creature.owner_id == OWNER_PLAYER:
			result.append(creature)
	return result


func get_enemy_creatures() -> Array[Creature]:
	var result: Array[Creature] = []
	for creature in creatures:
		if is_instance_valid(creature) and creature.owner_id == OWNER_ENEMY:
			result.append(creature)
	return result


func _refresh_enemy_movement_highlights() -> void:
	if grid == null:
		return
	var reachable_by_cell := {}
	for enemy_creature in get_enemy_creatures():
		if enemy_creature.movement <= 0:
			continue
		var reachable: Array[Vector2i] = grid.get_reachable_cells(enemy_creature.cell, enemy_creature.movement, get_occupied_cells(enemy_creature))
		for cell in reachable:
			reachable_by_cell[cell] = true

	var cells: Array[Vector2i] = []
	for key in reachable_by_cell.keys():
		var cell: Vector2i = key
		cells.append(cell)
	grid.set_enemy_movement_highlights(cells, Color(0.95, 0.10, 0.08, 0.18))


func _lowest_health_creature(source: Array[Creature]) -> Creature:
	if source.is_empty():
		return null
	var best := source[0]
	for creature in source:
		if creature.current_health < best.current_health:
			best = creature
	return best


func _wait_for_attack_hit(attacker: Creature) -> void:
	if attacker == null:
		return
	var hit_delay := attacker.get_attack_hit_delay()
	if hit_delay > 0.0:
		await get_tree().create_timer(hit_delay).timeout


func _cell_from_global(global_position: Vector2) -> Vector2i:
	return grid.local_to_cell(grid.to_local(global_position))


func _position_creature(creature: Creature, animate: bool) -> void:
	var center := grid.position + grid.cell_to_local(creature.cell)
	var target_position := center - creature.size * 0.5
	if animate:
		var tween := create_tween()
		tween.tween_property(creature, "position", target_position, 1.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		creature.position = target_position


func _layout_board() -> void:
	if grid == null or board_control == null:
		return
	var board_size := grid.get_board_size()
	var available := board_control.size
	grid.position = (available - board_size) * 0.5 - grid.get_board_bounds().position
	for creature in creatures:
		if is_instance_valid(creature):
			_position_creature(creature, false)


func _on_creature_died(creature: Creature) -> void:
	if not creatures.has(creature):
		return
	creatures.erase(creature)
	if creature.is_hero:
		log_event("Your Hero falls.")
		hero = null
		TurnManager.end_game(OWNER_ENEMY)
	else:
		log_event("%s falls." % creature.card_data.display_name)
	if selected_creature == creature:
		_clear_selection()
	_refresh_enemy_movement_highlights()
	await creature.play_unit_death()
	if is_instance_valid(creature):
		creature.queue_free()


func _clear_creatures() -> void:
	for creature in creatures:
		if is_instance_valid(creature):
			creature.queue_free()
	creatures.clear()
	hero = null
	if grid != null:
		grid.clear_enemy_movement_highlights()


func _check_game_over() -> void:
	update_ui()
	if enemy.life <= 0:
		TurnManager.end_game(OWNER_PLAYER)
	elif not is_instance_valid(hero) or hero.current_health <= 0:
		TurnManager.end_game(OWNER_ENEMY)


# ==================== AUTOPILOT SIMULATION SYSTEM ====================

func start_autopilot_simulation(config: Dictionary = {}) -> void:
	if simulation_runner == null:
		simulation_runner = SimulationRunner.new()
		add_child(simulation_runner)
		
		# Connect to signals
		simulation_runner.simulation_started.connect(_on_simulation_started)
		simulation_runner.simulation_finished.connect(_on_simulation_finished)
		simulation_runner.turn_started.connect(_on_simulation_turn_started)
		simulation_runner.turn_ended.connect(_on_simulation_turn_ended)
	
	# Default config
	var sim_config := {
		"player_faction": "lyonar",
		"enemy_faction": "abyssian",
		"simulation_speed": 2.0,  # 2x speed
		"max_turns": 30,
		"enable_logging": true,
		"export_format": "json"
	}
	
	# Merge with provided config
	for key in config:
		sim_config[key] = config[key]
	
	print("MainGame: Starting autopilot simulation with config: %s" % str(sim_config))
	simulation_runner.run_single_simulation(self, sim_config)

func stop_autopilot_simulation() -> void:
	if simulation_runner != null and simulation_runner.is_simulation_running:
		simulation_runner.stop_simulation()
		print("MainGame: Autopilot simulation stopped")

func is_simulation_running() -> bool:
	return simulation_runner != null and simulation_runner.is_simulation_running

func _on_simulation_started() -> void:
	print("MainGame: Simulation started")

func _on_simulation_finished(results: Dictionary) -> void:
	print("MainGame: Simulation finished")
	print("  Winner: %s" % results.winner)
	print("  Turns: %d" % results.turns)
	print("  Cards Played: %d" % results.data.card_plays.size())

func _on_simulation_turn_started(turn_number: int, player: String) -> void:
	print("MainGame: Turn %d started for %s" % [turn_number, player])

func _on_simulation_turn_ended(turn_number: int, player: String) -> void:
	print("MainGame: Turn %d ended for %s" % [turn_number, player])

func run_batch_simulations(count: int, config: Dictionary = {}) -> void:
	if simulation_runner == null:
		simulation_runner = SimulationRunner.new()
		add_child(simulation_runner)
		
		simulation_runner.simulation_started.connect(_on_simulation_started)
		simulation_runner.simulation_finished.connect(_on_simulation_finished)
	
	var sim_config := {
		"player_faction": "lyonar",
		"enemy_faction": "abyssian",
		"simulation_speed": 5.0,  # 5x speed for batch
		"max_turns": 30,
		"enable_logging": true,
		"export_format": "csv"
	}
	
	for key in config:
		sim_config[key] = config[key]
	
	print("MainGame: Starting batch of %d simulations" % count)
	simulation_runner.run_batch_simulations(count, self, sim_config)

func get_simulation_stats() -> Dictionary:
	if simulation_runner == null:
		return {"error": "No simulation running"}
	return simulation_runner.get_current_stats()

# Helper function to get blocked cells for pathfinding
func _get_blocked_cells() -> Dictionary:
	var blocked := {}
	for creature in creatures:
		if is_instance_valid(creature):
			blocked[creature.cell] = true
	return blocked

# Helper to get enemy hero
func get_enemy_hero() -> Creature:
	for creature in creatures:
		if is_instance_valid(creature) and creature.is_hero and creature.owner_id == OWNER_ENEMY:
			return creature
	return null
