extends Node
class_name SimulationRunner

signal simulation_started
signal simulation_finished(results: Dictionary)
signal turn_started(turn_number: int, player: String)
signal turn_ended(turn_number: int, player: String)

var autopilot: AutopilotSystem = null
var main_game: MainGame = null
var is_simulation_running := false
var simulation_count := 0
var max_simulations := 1
var current_results := {}

# Configuration
var config := {
	"player_faction": "lyonar",
	"enemy_faction": "abyssian",
	"simulation_speed": 1.0,  # Multiplier for delays
	"max_turns": 50,  # Max turns before auto-draw
	"enable_logging": true,
	"export_format": "json"  # json, csv, or text
}

func _ready() -> void:
	autopilot = AutopilotSystem.new()
	add_child(autopilot)
	autopilot.simulation_complete.connect(_on_simulation_complete)

func run_single_simulation(p_main_game: MainGame, p_config: Dictionary = {}) -> void:
	main_game = p_main_game
	
	# Merge config
	for key in p_config:
		config[key] = p_config[key]
	
	is_simulation_running = true
	simulation_count = 0
	max_simulations = 1
	
	_start_simulation()

func run_batch_simulations(count: int, p_main_game: MainGame, p_config: Dictionary = {}) -> void:
	main_game = p_main_game
	max_simulations = count
	simulation_count = 0
	
	# Merge config
	for key in p_config:
		config[key] = p_config[key]
	
	is_simulation_running = true
	_run_next_simulation()

func _run_next_simulation() -> void:
	if simulation_count >= max_simulations:
		is_simulation_running = false
		print("Batch simulation complete: %d runs finished" % max_simulations)
		return
	
	simulation_count += 1
	print("Starting simulation %d/%d" % [simulation_count, max_simulations])
	_start_simulation()

func _start_simulation() -> void:
	simulation_started.emit()
	
	# Reset game state for new simulation
	main_game._start_battle()
	
	# Start autopilot
	autopilot.start_simulation(main_game)
	
	# Connect to turn signals
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.enemy_turn_started.connect(_on_enemy_turn_started)
	TurnManager.game_over.connect(_on_game_over)

func stop_simulation() -> void:
	is_simulation_running = false
	autopilot.stop_simulation()
	
	TurnManager.player_turn_started.disconnect(_on_player_turn_started)
	TurnManager.enemy_turn_started.disconnect(_on_enemy_turn_started)
	TurnManager.game_over.disconnect(_on_game_over)

func _on_player_turn_started(turn_number: int) -> void:
	turn_started.emit(turn_number, "player")
	
	# Let autopilot handle the turn
	autopilot._execute_player_turn()
	
	# Check max turns
	if turn_number >= config.max_turns:
		print("Max turns reached, ending simulation")
		_end_simulation("draw")

func _on_enemy_turn_started(turn_number: int) -> void:
	turn_started.emit(turn_number, "enemy")
	turn_ended.emit(turn_number - 1, "player")

func _on_game_over(winner: String) -> void:
	_end_simulation(winner)

func _on_simulation_complete(winner: String, turns: int, data: Dictionary) -> void:
	current_results = {
		"winner": winner,
		"turns": turns,
		"data": data,
		"config": config.duplicate()
	}
	
	simulation_finished.emit(current_results)
	
	# Save results to file
	if config.enable_logging:
		_save_results()
	
	# Run next simulation if batch mode
	if is_simulation_running and simulation_count < max_simulations:
		await get_tree().create_timer(1.0).timeout
		_run_next_simulation()

func _end_simulation(winner: String) -> void:
	autopilot.stop_simulation()
	
	TurnManager.player_turn_started.disconnect(_on_player_turn_started)
	TurnManager.enemy_turn_started.disconnect(_on_enemy_turn_started)
	TurnManager.game_over.disconnect(_on_game_over)
	
	var total_turns: int = TurnManager.current_turn
	var data := autopilot.export_simulation_data()
	data["winner"] = winner
	data["total_turns"] = total_turns
	
	autopilot.simulation_complete.emit(winner, total_turns, data)

func _save_results() -> void:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename := "simulation_%s_%d" % [timestamp, simulation_count]
	
	match config.export_format:
		"json":
			_save_json(filename)
		"csv":
			_save_csv(filename)
		_:
			_save_text(filename)

func _save_json(filename: String) -> void:
	var path := "user://simulations/%s.json" % filename
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("simulations"):
		dir.make_dir("simulations")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_results, "\t"))
		file.close()
		print("Results saved to: %s" % path)

func _save_csv(filename: String) -> void:
	var path := "user://simulations/%s.csv" % filename
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("simulations"):
		dir.make_dir("simulations")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		# Header
		file.store_line("turn,phase,player_mana,player_creatures,enemy_creatures,player_hero_health,enemy_hero_health")
		
		# Data rows
		for state in current_results.data.turns:
			var line := "%d,%s,%d,%d,%d,%d,%d" % [
				state.turn,
				state.phase,
				state.player_mana,
				state.player_creatures,
				state.enemy_creatures,
				state.player_hero_health,
				state.enemy_hero_health
			]
			file.store_line(line)
		file.close()
		print("Results saved to: %s" % path)

func _save_text(filename: String) -> void:
	var path := "user://simulations/%s.txt" % filename
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("simulations"):
		dir.make_dir("simulations")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line("Simulation Results")
		file.store_line("==================")
		file.store_line("")
		file.store_line("Winner: %s" % current_results.winner)
		file.store_line("Turns: %d" % current_results.turns)
		file.store_line("")
		file.store_line("Cards Played:")
		for play in current_results.data.card_plays:
			file.store_line("  Turn %d: %s (%s) - Cost: %d" % [play.turn, play.card, play.type, play.mana_cost])
		file.close()
		print("Results saved to: %s" % path)

func get_current_stats() -> Dictionary:
	return {
		"simulation_running": is_simulation_running,
		"current_simulation": simulation_count,
		"total_simulations": max_simulations,
		"current_turn": TurnManager.current_turn if is_simulation_running else 0,
		"current_winner": current_results.get("winner", "")
	}
