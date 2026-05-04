class_name AIController
extends RefCounted

# Base class for all AI controllers
# Subclasses implement specific behaviors for different encounter types

var game: MainGame
var config: EncounterConfig

func _init(p_game: MainGame, p_config: EncounterConfig) -> void:
	game = p_game
	config = p_config


# Called at the start of enemy turn
func start_turn() -> void:
	pass


# Main turn logic - subclasses override this
func take_turn() -> void:
	if TurnManager.is_game_over():
		return
	await game.pause(0.35)
	await _execute_turn_logic()
	await game.pause(0.25)
	if not TurnManager.is_game_over():
		game.log_event("Enemy ends turn.")
		TurnManager.finish_enemy_turn()


# Override this in subclasses
func _execute_turn_logic() -> void:
	pass


# Helper: Get all enemy creatures
func get_enemy_creatures() -> Array[Creature]:
	return game.get_enemy_creatures()


# Helper: Move creature toward target
func move_toward_target(creature: Creature, target_pos: Vector2i) -> void:
	if not creature.can_move(TurnManager.turn_number):
		return
	var best_cell: Vector2i = game.get_best_reachable_cell_toward(creature, target_pos)
	if best_cell != creature.cell:
		game.move_creature(creature, best_cell)
		await game.pause(0.22)


# Helper: Attack if possible
func attack_if_possible(creature: Creature) -> void:
	if not creature.can_attack(TurnManager.turn_number):
		return
	var target: Creature = game.find_best_attack_target(creature, "player")
	if target != null:
		await game.creature_attack_creature(creature, target)
		await game.pause(0.28)
	elif game.can_attack_leader(creature, "player"):
		await game.creature_attack_leader(creature, "player")
		await game.pause(0.28)


# Helper: Find spawn position near hero
func find_spawn_position_near_hero(distance: int = 3) -> Vector2i:
	if not is_instance_valid(game.hero):
		return GridManager.INVALID_CELL
	
	var hero_cell := game.hero.cell
	var candidates: Array[Vector2i] = []
	
	for dx in range(-distance, distance + 1):
		for dy in range(-distance, distance + 1):
			var check_cell := hero_cell + Vector2i(dx, dy)
			if game.grid.is_valid_cell(check_cell) and game.get_creature_at(check_cell) == null:
				candidates.append(check_cell)
	
	if candidates.is_empty():
		return game.find_enemy_summon_cell()
	
	# Pick random candidate
	return candidates[randi() % candidates.size()]


# Helper: Spawn a creature
func spawn_creature(creature_id: String, cell: Vector2i) -> Creature:
	var card := GameManager.get_card(creature_id)
	if card == null:
		return null
	return game.summon_enemy_creature(card, cell)
