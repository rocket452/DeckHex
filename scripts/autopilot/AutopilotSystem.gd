extends Node
class_name AutopilotSystem

signal simulation_complete(winner: String, turns: int, data: Dictionary)
signal turn_completed(turn_number: int, player_actions: Array)

var main_game: MainGame = null
var is_running := false
var turn_delay := 1.0  # Delay between turns in seconds
var action_delay := 0.5  # Delay between actions
var simulation_data := {
	"turns": [],
	"player_mana_history": [],
	"enemy_mana_history": [],
	"card_plays": [],
	"creature_positions": {},
	"winner": "",
	"total_turns": 0
}

enum ActionType {
	PLAY_CREATURE,
	PLAY_SPELL,
	MOVE_CREATURE,
	ATTACK,
	END_TURN
}

class AutopilotAction:
	var type: ActionType
	var card: CardData
	var target_cell: Vector2i
	var target_creature: Creature
	var source_creature: Creature
	
	func _init(p_type: ActionType) -> void:
		type = p_type

func _ready() -> void:
	set_process(false)

func start_simulation(game: MainGame) -> void:
	main_game = game
	is_running = true
	simulation_data = {
		"turns": [],
		"player_mana_history": [],
		"enemy_mana_history": [],
		"card_plays": [],
		"creature_positions": {},
		"winner": "",
		"total_turns": 0
	}
	set_process(true)
	print("Autopilot: Simulation started")

func stop_simulation() -> void:
	is_running = false
	set_process(false)
	print("Autopilot: Simulation stopped")

func _process(delta: float) -> void:
	if not is_running or main_game == null:
		return
	
	# Only act during player turn
	if TurnManager.is_enemy_turn():
		return
	
	# Check if we can act
	if not main_game.player.can_play_cards() and main_game.player.hand.is_empty():
		# End turn if nothing to do
		_end_player_turn()
		return

func _execute_player_turn() -> void:
	print("Autopilot: Executing player turn %d" % TurnManager.current_turn)
	
	var actions := _decide_actions()
	
	for action in actions:
		if not is_running:
			return
		
		match action.type:
			ActionType.PLAY_CREATURE:
				_play_creature_card(action.card, action.target_cell)
			ActionType.PLAY_SPELL:
				_play_spell_card(action.card, action.target_creature)
			ActionType.MOVE_CREATURE:
				_move_creature(action.source_creature, action.target_cell)
			ActionType.ATTACK:
				_attack_with_creature(action.source_creature, action.target_creature)
			ActionType.END_TURN:
				_end_player_turn()
				return
		
		await get_tree().create_timer(action_delay).timeout
		_record_state()
	
	# End turn after all actions
	_end_player_turn()

func _decide_actions() -> Array:
	var actions: Array[AutopilotAction] = []
	
	if main_game == null or main_game.player == null:
		return actions
	
	var available_mana := main_game.player.current_mana
	var playable_cards := _get_playable_cards(available_mana)
	
	# Strategy: Play highest cost cards first
	playable_cards.sort_custom(func(a, b): return a.cost > b.cost)
	
	for card in playable_cards:
		if card.cost > available_mana:
			continue
		
		if card.card_type == CardData.CardType.CREATURE:
			var spawn_cell := _find_best_spawn_cell()
			if spawn_cell != Vector2i(-1, -1):
				var action := AutopilotAction.new(ActionType.PLAY_CREATURE)
				action.card = card
				action.target_cell = spawn_cell
				actions.append(action)
				available_mana -= card.cost
		
		elif card.card_type == CardData.CardType.SPELL:
			var target := _find_spell_target(card)
			if target != null:
				var action := AutopilotAction.new(ActionType.PLAY_SPELL)
				action.card = card
				action.target_creature = target
				actions.append(action)
				available_mana -= card.cost
	
	# Move creatures if possible
	for creature in main_game.get_player_creatures():
		if creature.moved_this_turn or creature.attacked_this_turn:
			continue
		
		var move_target := _find_best_move_target(creature)
		if move_target != Vector2i(-1, -1) and move_target != creature.cell:
			var action := AutopilotAction.new(ActionType.MOVE_CREATURE)
			action.source_creature = creature
			action.target_cell = move_target
			actions.append(action)
	
	# Attack with creatures if possible
	for creature in main_game.get_player_creatures():
		if creature.attacked_this_turn:
			continue
		
		var attack_target := _find_attack_target(creature)
		if attack_target != null:
			var action := AutopilotAction.new(ActionType.ATTACK)
			action.source_creature = creature
			action.target_creature = attack_target
			actions.append(action)
	
	# Always end turn
	actions.append(AutopilotAction.new(ActionType.END_TURN))
	
	return actions

func _get_playable_cards(mana: int) -> Array[CardData]:
	var playable: Array[CardData] = []
	for card in main_game.player.hand:
		if card.cost <= mana:
			playable.append(card)
	return playable

func _find_best_spawn_cell() -> Vector2i:
	# Find a spawn cell near the enemy
	var enemy_hero := main_game.get_enemy_hero()
	var spawn_cells := main_game.grid.get_player_summon_cells()
	
	if spawn_cells.is_empty():
		return Vector2i(-1, -1)
	
	# Prefer cells closer to enemy hero
	var best_cell := spawn_cells[0]
	var best_distance := 9999
	
	for cell in spawn_cells:
		if main_game.get_creature_at_cell(cell) != null:
			continue
		
		var dist := main_game.grid.hex_distance(cell, enemy_hero.cell) if enemy_hero != null else 0
		if dist < best_distance:
			best_distance = dist
			best_cell = cell
	
	return best_cell

func _find_spell_target(spell_card: CardData) -> Creature:
	# Find best target for spell
	if spell_card.spell_damage > 0:
		# Target enemy hero if possible
		var enemy_hero := main_game.get_enemy_hero()
		if enemy_hero != null:
			return enemy_hero
		
		# Otherwise target any enemy creature
		for creature in main_game.get_enemy_creatures():
			return creature
	
	return null

func _find_best_move_target(creature: Creature) -> Vector2i:
	# Find cell closer to enemy
	var enemy_hero := main_game.get_enemy_hero()
	if enemy_hero == null:
		return Vector2i(-1, -1)
	
	var reachable := main_game.grid.get_reachable_cells(
		creature.cell, 
		creature.movement,
		main_game._get_blocked_cells()
	)
	
	var best_cell := creature.cell
	var best_distance := main_game.grid.hex_distance(creature.cell, enemy_hero.cell)
	
	for cell in reachable:
		if main_game.get_creature_at_cell(cell) != null:
			continue
		
		var dist := main_game.grid.hex_distance(cell, enemy_hero.cell)
		if dist < best_distance:
			best_distance = dist
			best_cell = cell
	
	return best_cell

func _find_attack_target(creature: Creature) -> Creature:
	# Find adjacent enemy to attack
	var neighbors := main_game.grid.get_neighbors(creature.cell)
	
	for neighbor in neighbors:
		var target := main_game.get_creature_at_cell(neighbor)
		if target != null and target.owner_id != creature.owner_id:
			return target
	
	return null

func _play_creature_card(card: CardData, cell: Vector2i) -> void:
	print("Autopilot: Playing creature %s at %s" % [card.display_name, str(cell)])
	main_game.play_card(card, cell)
	
	simulation_data.card_plays.append({
		"turn": TurnManager.current_turn,
		"player": "player",
		"card": card.display_name,
		"type": "creature",
		"cell": str(cell),
		"mana_cost": card.cost
	})

func _play_spell_card(card: CardData, target: Creature) -> void:
	print("Autopilot: Playing spell %s on %s" % [card.display_name, target.name])
	# Spell casting logic would go here
	
	simulation_data.card_plays.append({
		"turn": TurnManager.current_turn,
		"player": "player",
		"card": card.display_name,
		"type": "spell",
		"target": target.name,
		"mana_cost": card.cost
	})

func _move_creature(creature: Creature, cell: Vector2i) -> void:
	print("Autopilot: Moving %s to %s" % [creature.name, str(cell)])
	main_game.move_creature_to_cell(creature, cell)

func _attack_with_creature(creature: Creature, target: Creature) -> void:
	print("Autopilot: %s attacking %s" % [creature.name, target.name])
	main_game._resolve_combat(creature, target)

func _end_player_turn() -> void:
	print("Autopilot: Ending player turn")
	TurnManager.end_player_turn()
	_record_state()

func _record_state() -> void:
	if main_game == null:
		return
	
	var state := {
		"turn": TurnManager.current_turn,
		"phase": "player" if not TurnManager.is_enemy_turn() else "enemy",
		"player_mana": main_game.player.current_mana if main_game.player != null else 0,
		"player_max_mana": main_game.player.max_mana if main_game.player != null else 0,
		"player_hand_size": main_game.player.hand.size() if main_game.player != null else 0,
		"player_deck_size": main_game.player.deck.size() if main_game.player != null else 0,
		"player_creatures": main_game.get_player_creatures().size(),
		"enemy_creatures": main_game.get_enemy_creatures().size(),
		"player_hero_health": main_game.hero.current_health if main_game.hero != null else 0,
		"enemy_hero_health": main_game.get_enemy_hero().current_health if main_game.get_enemy_hero() != null else 0
	}
	
	simulation_data.turns.append(state)
	
	# Track creature positions
	for creature in main_game.creatures:
		if is_instance_valid(creature):
			simulation_data.creature_positions[creature.name] = {
				"cell": str(creature.cell),
				"health": creature.current_health,
				"max_health": creature.card_data.health,
				"attack": creature.attack
			}

func export_simulation_data() -> Dictionary:
	return simulation_data.duplicate(true)

func get_summary() -> String:
	var summary := "Simulation Summary:\n"
	summary += "Total Turns: %d\n" % simulation_data.total_turns
	summary += "Winner: %s\n" % simulation_data.winner
	summary += "Cards Played: %d\n" % simulation_data.card_plays.size()
	return summary
