extends Node
class_name EncounterManager

# Central manager for encounter configuration and AI instantiation
# Bridges RunMap system with Battle system

# Current encounter state
var current_config: EncounterConfig = null
var current_ai_controller: AIController = null

# Factory method: Convert EncounterNode to EncounterConfig
func create_config_from_node(node: EncounterNode) -> EncounterConfig:
	var config := EncounterConfig.from_node(node)
	return config


# Factory method: Create appropriate AI controller for config
func create_ai_controller(game: MainGame, config: EncounterConfig) -> AIController:
	match config.ai_type:
		EncounterConfig.AIType.DECK_BASED:
			return DeckBasedAI.new(game, config)
		EncounterConfig.AIType.RULE_BASED:
			return RuleBasedAI.new(game, config)
		EncounterConfig.AIType.ELITE:
			return EliteAI.new(game, config)
		EncounterConfig.AIType.BOSS:
			return BossAI.new(game, config)
		_:
			return DeckBasedAI.new(game, config)


# Setup a battle from an encounter node
func setup_encounter(game: MainGame, node: EncounterNode) -> void:
	# Generate config from node
	current_config = create_config_from_node(node)
	
	# Create AI controller
	current_ai_controller = create_ai_controller(game, current_config)
	
	# Apply config to game
	_apply_config_to_game(game, current_config)


# Apply encounter configuration to the game
func _apply_config_to_game(game: MainGame, config: EncounterConfig) -> void:
	# Set enemy life
	game.enemy.life = config.enemy_life
	
	# Setup deck-based enemy
	if config.ai_type == EncounterConfig.AIType.DECK_BASED:
		_setup_deck_enemy(game, config)
	else:
		# Rule-based enemies don't draw cards or use mana
		_setup_rule_based_enemy(game, config)


func _setup_deck_enemy(game: MainGame, config: EncounterConfig) -> void:
	# Clear existing deck and hand
	game.enemy.deck.clear()
	game.enemy.hand.clear()
	
	# Populate deck
	for card in config.enemy_deck:
		game.enemy.deck.append(card)
	
	game.enemy.deck.shuffle()
	
	# Draw starting hand
	for i in range(GameManager.STARTING_HAND_SIZE):
		game.enemy.draw_cards(1)
	
	game.log_event("Enemy draws %d cards." % GameManager.STARTING_HAND_SIZE)


func _setup_rule_based_enemy(game: MainGame, config: EncounterConfig) -> void:
	# Rule-based enemies don't have decks, but need basic setup
	game.enemy.setup(game.enemy.choose_display_name(), [], config.enemy_life, 0)
	
	# Initial spawns happen in AI start_turn
	game.log_event("Enemy forces approach!")


# Get the current AI controller for taking turns
func get_ai_controller() -> AIController:
	return current_ai_controller


# Check if encounter has special victory condition
func check_victory_condition(game: MainGame) -> String:
	if current_config == null:
		return ""
	
	match current_config.victory_condition:
		"defeat_boss":
			# Check if boss creature is defeated
			if current_config.ai_type == EncounterConfig.AIType.BOSS:
				var boss_ai := current_ai_controller as BossAI
				if boss_ai != null and (boss_ai.boss_creature == null or not is_instance_valid(boss_ai.boss_creature)):
					return MainGame.OWNER_PLAYER
			return ""
		
		"survive_turns":
			if TurnManager.turn_number >= current_config.turns_to_survive:
				return MainGame.OWNER_PLAYER
			return ""
		
		_:
			# Default: check normal game over conditions
			return ""


# Get encounter info for UI
func get_encounter_info() -> Dictionary:
	if current_config == null:
		return {
			"name": "Unknown",
			"description": "",
			"type": EncounterType.Type.PVP_ENCOUNTER
		}
	
	return {
		"name": current_config.encounter_name,
		"description": current_config.description,
		"type": current_config.encounter_type,
		"ai_type": current_config.ai_type
	}


# Cleanup after encounter ends
func clear_encounter() -> void:
	current_config = null
	current_ai_controller = null
