class_name RuleBasedAI
extends AIController

# Static encounter AI - spawns creatures each turn, no deck/mana
# Simple AI: move toward hero, attack if adjacent

var spawned_this_turn: bool = false


func start_turn() -> void:
	spawned_this_turn = false
	
	# Spawn creatures based on rules
	if config.spawn_enemy_each_turn:
		await _spawn_wave()
	else:
		# Check spawn rules
		for rule in config.spawn_rules:
			if _should_spawn(rule):
				await _spawn_from_rule(rule)


func _execute_turn_logic() -> void:
	await _move_and_attack()


func _spawn_wave() -> void:
	var current_enemy_count := get_enemy_creatures().size()
	if current_enemy_count >= config.max_enemy_creatures:
		return
	
	# Determine what to spawn based on pattern
	var creature_id := _get_spawn_creature_id()
	var spawn_count: int = min(2, config.max_enemy_creatures - current_enemy_count)
	
	for i in range(spawn_count):
		var spawn_cell := find_spawn_position_near_hero(4)
		if spawn_cell != GridManager.INVALID_CELL:
			var creature := spawn_creature(creature_id, spawn_cell)
			if creature != null:
				game.log_event("A %s emerges from the shadows!" % creature.card_data.display_name)
				await game.pause(0.2)
	
	spawned_this_turn = true


func _should_spawn(rule: EncounterConfig.SpawnRule) -> bool:
	if rule.spawned and not rule.repeat:
		return false
	
	var current_turn := TurnManager.turn_number
	if rule.repeat:
		return current_turn > 0 and current_turn % rule.turn == 0
	else:
		return current_turn >= rule.turn


func _spawn_from_rule(rule: EncounterConfig.SpawnRule) -> void:
	var current_enemy_count := get_enemy_creatures().size()
	if current_enemy_count >= config.max_enemy_creatures:
		return
	
	for i in range(rule.count):
		if get_enemy_creatures().size() >= config.max_enemy_creatures:
			break
		
		var spawn_cell := find_spawn_position_near_hero(4)
		if spawn_cell != GridManager.INVALID_CELL:
			var creature := spawn_creature(rule.creature_id, spawn_cell)
			if creature != null:
				game.log_event("A %s appears!" % creature.card_data.display_name)
				await game.pause(0.2)
	
	rule.spawned = true


func _get_spawn_creature_id() -> String:
	match config.spawn_pattern:
		"zombie":
			return "zombie"
		"random":
			var options := ["zombie", "goblin", "archer"]
			return options[randi() % options.size()]
		"elite":
			return "knight"
		_:
			return "zombie"


func _move_and_attack() -> void:
	# Simple AI: move toward hero, attack if possible
	if not is_instance_valid(game.hero):
		return
	
	var hero_cell := game.hero.cell
	var actors: Array[Creature] = get_enemy_creatures()
	
	for creature in actors:
		if not is_instance_valid(creature) or TurnManager.is_game_over():
			continue
		
		# Move toward hero
		if creature.can_move(TurnManager.turn_number):
			await move_toward_target(creature, hero_cell)
		
		# Attack if possible
		if creature.can_attack(TurnManager.turn_number):
			await attack_if_possible(creature)
