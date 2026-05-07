extends Control
class_name GameLauncher

signal game_exited

var main_menu: MainMenu
var current_game: Control = null

func _ready() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	# Clear any existing game
	if current_game != null:
		current_game.queue_free()
		current_game = null
	
	# Create and show main menu
	main_menu = preload("res://scenes/MainMenu.tscn").instantiate()
	add_child(main_menu)
	main_menu.mode_selected.connect(_on_mode_selected)

func _on_mode_selected(mode: String) -> void:
	# Hide menu
	if main_menu != null:
		main_menu.queue_free()
		main_menu = null
	
	# Launch appropriate game mode
	match mode:
		"simulated_pvp":
			_launch_simulated_pvp()
		"adventure":
			_launch_adventure()
		_:
			print("Unknown mode: ", mode)
			_show_main_menu()

func _launch_simulated_pvp() -> void:
	print("Launching Simulated PvP: Lyonar vs Abyssian")
	
	# Create MainGame instance
	current_game = preload("res://scenes/MainGame.tscn").instantiate()
	add_child(current_game)
	
	# Configure for simulated PvP
	var main_game_script = current_game as MainGame
	main_game_script.set_simulated_pvp_mode()
	
	# Connect battle complete signal
	main_game_script.battle_complete.connect(_on_simulated_pvp_complete)
	
	# Start the battle with the configured setup
	main_game_script.start_battle(main_game_script.current_config)

func _launch_adventure() -> void:
	print("Launching Adventure Mode")
	
	# Create RunMapManager instance
	current_game = preload("res://scenes/RunMapManager.tscn").instantiate()
	add_child(current_game)
	
	# Connect signals
	var run_map_script = current_game as RunMapManager
	run_map_script.run_completed.connect(_on_adventure_complete)
	run_map_script.run_abandoned.connect(_on_adventure_abandoned)

func _on_simulated_pvp_complete(winner: String, encounter_type: int) -> void:
	print("Simulated PvP complete. Winner: ", winner)
	
	# Show results briefly
	await get_tree().create_timer(3.0).timeout
	
	# Return to main menu
	_show_main_menu()

func _on_adventure_complete(victory: bool) -> void:
	print("Adventure complete. Victory: ", victory)
	
	# Show results briefly
	await get_tree().create_timer(3.0).timeout
	
	# Return to main menu
	_show_main_menu()

func _on_adventure_abandoned() -> void:
	print("Adventure abandoned")
	
	# Return to main menu immediately
	_show_main_menu()

func _input(event: InputEvent) -> void:
	# ESC to return to main menu from any game
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_game != null and main_menu == null:
			print("Returning to main menu")
			_show_main_menu()
		elif main_menu != null:
			get_tree().quit()
