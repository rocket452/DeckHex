class_name EliteAI
extends AIController

# Elite encounter AI - stronger rule-based enemies with enhanced stats
# Elite creatures spawn at start and have improved AI

func start_turn() -> void:
	# Spawn initial elite group on first turn
	if TurnManager.turn_number == 1:
		await _spawn_elite_group()


func _execute_turn_logic() -> void:
	await _elite_move_and_attack()


func _spawn_elite_group() -> void:
	game.log_event("Elite forces appear!")
	
	for rule in config.spawn_rules:
		for i in range(rule.count):
			var spawn_cell := find_spawn_position_near_hero(5)
			if spawn_cell != GridManager.INVALID_CELL:
				var creature := spawn_creature(rule.creature_id, spawn_cell)
				if creature != null:
					# Apply elite buffs
					_apply_elite_buffs(creature)
					await game.pause(0.3)


func _apply_elite_buffs(creature: Creature) -> void:
	# Enhanced stats for elite enemies
	creature.attack += 2
	creature.max_health += 5
	creature.current_health = creature.max_health
	
	# Elite enemies can move and attack same turn
	creature.movement += 1


func _elite_move_and_attack() -> void:
	# Smarter AI that coordinates attacks
	if not is_instance_valid(game.hero):
		return
	
	var hero_cell := game.hero.cell
	var actors: Array[Creature] = get_enemy_creatures()
	
	# Sort by distance to hero - closest act first
	actors.sort_custom(func(a, b): 
		var dist_a: int = game.grid.get_cell_distance(a.cell, hero_cell)
		var dist_b: int = game.grid.get_cell_distance(b.cell, hero_cell)
		return dist_a < dist_b
	)
	
	for creature in actors:
		if not is_instance_valid(creature) or TurnManager.is_game_over():
			continue
		
		# Elite AI: If adjacent to hero, attack. Otherwise move closer.
		var dist_to_hero: int = game.grid.get_cell_distance(creature.cell, hero_cell)
		
		if dist_to_hero <= 1 and creature.can_attack(TurnManager.turn_number):
			# Already adjacent - attack
			await attack_if_possible(creature)
		elif creature.can_move(TurnManager.turn_number):
			# Try to flank or surround
			var flank_cell := _find_flanking_position(creature, hero_cell)
			if flank_cell != GridManager.INVALID_CELL:
				game.move_creature(creature, flank_cell)
				await game.pause(0.22)
				# Attack after moving if now adjacent
				if creature.can_attack(TurnManager.turn_number):
					var new_dist: int = game.grid.get_cell_distance(creature.cell, hero_cell)
					if new_dist <= 1:
						await attack_if_possible(creature)
			else:
				# Just move toward hero
				await move_toward_target(creature, hero_cell)
				if creature.can_attack(TurnManager.turn_number):
					await attack_if_possible(creature)


func _find_flanking_position(creature: Creature, target: Vector2i) -> Vector2i:
	# Try to find a position adjacent to target that's not already occupied by another enemy
	var neighbors := game.grid.get_neighbors(target)
	
	for cell in neighbors:
		if not game.grid.is_valid_cell(cell):
			continue
		if game.get_creature_at(cell) != null:
			continue
		if game.grid.get_cell_distance(creature.cell, cell) <= creature.movement:
			return cell
	
	return GridManager.INVALID_CELL
