class_name EncounterConfig

enum AIType {
	DECK_BASED,      # Standard PvP AI with cards and mana
	RULE_BASED,      # Static encounters - spawn units each turn
	ELITE,           # Elite encounters - stronger rule-based enemies
	BOSS             # Boss controller - unique abilities and phases
}

# Core encounter info
var encounter_type: EncounterType.Type
var ai_type: AIType
var encounter_name: String
var description: String

# Enemy setup
var enemy_deck: Array[CardData] = []  # For DECK_BASED AI
var spawn_rules: Array[SpawnRule] = []  # For RULE_BASED/ELITE/BOSS AI
var enemy_life: int = 20

# Turn rules
var player_draw_per_turn: int = 1
var player_mana_per_turn: int = 3
var enemy_draw_per_turn: int = 1
var enemy_mana_per_turn: int = 3

# Special rules
var spawn_enemy_each_turn: bool = false
var spawn_pattern: String = ""  # e.g., "zombie", "random", "elite"
var max_enemy_creatures: int = 6

# Boss specific
var boss_data: BossData = null

# Victory conditions
var victory_condition: String = "defeat_all"  # "defeat_all", "defeat_boss", "survive_turns"
var turns_to_survive: int = 0


func _init(p_type: EncounterType.Type = EncounterType.Type.PVP_ENCOUNTER) -> void:
	encounter_type = p_type
	_configure_from_type()


func _configure_from_type() -> void:
	match encounter_type:
		EncounterType.Type.PVP_ENCOUNTER:
			ai_type = AIType.DECK_BASED
			encounter_name = "Battle"
			description = "Face an AI opponent with their own deck and strategy."
			enemy_life = 20
			enemy_mana_per_turn = 3
			
		EncounterType.Type.STATIC_ENCOUNTER:
			ai_type = AIType.RULE_BASED
			encounter_name = "Horde"
			description = "Endless waves of enemies spawn each turn. Survive!"
			spawn_enemy_each_turn = true
			spawn_pattern = "zombie"
			max_enemy_creatures = 4
			enemy_life = 15
			# No mana for enemy - they spawn instead
			enemy_mana_per_turn = 0
			
		EncounterType.Type.ELITE_ENCOUNTER:
			ai_type = AIType.ELITE
			encounter_name = "Elite"
			description = "Powerful elite enemies with enhanced stats."
			spawn_enemy_each_turn = false
			enemy_life = 25
			enemy_mana_per_turn = 0
			
		EncounterType.Type.BOSS_ENCOUNTER:
			ai_type = AIType.BOSS
			encounter_name = "Boss"
			description = "A powerful boss with unique abilities and phases."
			victory_condition = "defeat_boss"
			enemy_life = 40
			enemy_mana_per_turn = 0
			boss_data = BossData.new()


static func from_node(node: EncounterNode) -> EncounterConfig:
	var config := EncounterConfig.new(node.type)
	
	# Layer scaling - deeper layers = harder
	var layer_multiplier := 1.0 + (node.layer_index * 0.15)
	
	match node.type:
		EncounterType.Type.PVP_ENCOUNTER:
			config.enemy_deck = _generate_deck_for_layer(node.layer_index)
			
		EncounterType.Type.STATIC_ENCOUNTER:
			config.spawn_rules.append(SpawnRule.new("zombie", 2, 1))  # 2 zombies, turn 1
			config.max_enemy_creatures = int(4 * layer_multiplier)
			
		EncounterType.Type.ELITE_ENCOUNTER:
			config.spawn_rules.append(SpawnRule.new("elite_knight", 1, 0))
			config.spawn_rules.append(SpawnRule.new("archer", 2, 0))
			
		EncounterType.Type.BOSS_ENCOUNTER:
			config.boss_data.max_phases = 3
			config.boss_data.phase_thresholds = [0.7, 0.4]  # HP % to change phase
			config.spawn_rules.append(SpawnRule.new("minion", 1, 2, true))  # Spawn every 2 turns
	
	config.enemy_life = int(config.enemy_life * layer_multiplier)
	return config


static func _generate_deck_for_layer(layer: int) -> Array[CardData]:
	var deck: Array[CardData] = []
	var cards_per_layer := 5 + layer * 2
	
	for i in range(cards_per_layer):
		if i % 3 == 0:
			deck.append(GameManager.get_card("zombie"))
		elif i % 3 == 1:
			deck.append(GameManager.get_card("knight"))
		else:
			deck.append(GameManager.get_card("archer"))
	
	return deck


# Spawn Rule for rule-based encounters
class SpawnRule:
	var creature_id: String
	var count: int
	var turn: int  # Turn to spawn (0 = start)
	var repeat: bool  # Repeat every 'turn' turns
	var spawned: bool = false
	
	func _init(p_creature_id: String, p_count: int, p_turn: int, p_repeat: bool = false) -> void:
		creature_id = p_creature_id
		count = p_count
		turn = p_turn
		repeat = p_repeat


# Boss data container
class BossData:
	var max_phases: int = 1
	var current_phase: int = 1
	var phase_thresholds: Array[float] = []  # HP % thresholds
	var abilities: Array[String] = []
	var boss_creature_id: String = "boss_general"
