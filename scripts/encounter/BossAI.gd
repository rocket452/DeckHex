class_name BossAI
extends AIController

# Boss encounter AI - powerful boss with phases and special abilities

var boss_creature: Creature = null
var abilities_used_this_turn: int = 0
const MAX_ABILITIES_PER_TURN := 1

func start_turn() -> void:
	abilities_used_this_turn = 0
	
	# Check for phase transition
	if boss_creature != null and is_instance_valid(boss_creature):
		_check_phase_transition()
	
	# Spawn initial boss if needed
	if boss_creature == null or not is_instance_valid(boss_creature):
		await _spawn_boss()
	
	# Spawn minions periodically
	if TurnManager.turn_number % 3 == 0:
		await _spawn_minions()


func _execute_turn_logic() -> void:
	await _boss_turn()


func _spawn_boss() -> void:
	game.log_event("The boss emerges!")
	
	var boss_id := config.boss_data.boss_creature_id if config.boss_data != null else "boss_general"
	var spawn_cell := find_spawn_position_near_hero(6)
	
	# Try to spawn at a good distance
	if spawn_cell == GridManager.INVALID_CELL:
		spawn_cell = game.find_enemy_summon_cell()
	
	if spawn_cell != GridManager.INVALID_CELL:
		var creature := spawn_creature(boss_id, spawn_cell)
		if creature != null:
			boss_creature = creature
			_apply_boss_stats(creature)
			await game.pause(0.5)


func _apply_boss_stats(creature: Creature) -> void:
	# Boss is significantly stronger
	creature.attack += 4
	creature.max_health = config.enemy_life
	creature.current_health = creature.max_health
	creature.movement += 1
	
	# Boss can act multiple times (conceptually - implemented via special abilities)
	game.log_event("The boss radiates overwhelming power!")


func _spawn_minions() -> void:
	if get_enemy_creatures().size() >= config.max_enemy_creatures:
		return
	
	game.log_event("The boss summons minions!")
	
	var minion_count: int = min(2, config.max_enemy_creatures - get_enemy_creatures().size())
	
	for i in range(minion_count):
		var spawn_cell := find_spawn_position_near_hero(4)
		if spawn_cell != GridManager.INVALID_CELL:
			var creature := spawn_creature("zombie", spawn_cell)
			if creature != null:
				await game.pause(0.2)


func _check_phase_transition() -> void:
	if config.boss_data == null:
		return
	
	var health_percent := float(boss_creature.current_health) / float(boss_creature.max_health)
	var new_phase := config.boss_data.current_phase
	
	# Check thresholds
	for i in range(config.boss_data.phase_thresholds.size()):
		if health_percent <= config.boss_data.phase_thresholds[i]:
			new_phase = i + 2  # Phase 2, 3, etc.
	
	if new_phase != config.boss_data.current_phase:
		config.boss_data.current_phase = new_phase
		_game_enter_phase(new_phase)


func _game_enter_phase(phase: int) -> void:
	game.log_event("The boss enters Phase %d!" % phase)
	
	# Apply phase-specific effects
	match phase:
		2:
			# Phase 2: Boss becomes more aggressive
			if boss_creature != null:
				boss_creature.attack += 2
			game.log_event("The boss's rage intensifies!")
		3:
			# Phase 3: Desperate mode - boss can act twice
			if boss_creature != null:
				boss_creature.attack += 3
				boss_creature.movement += 1
			game.log_event("The boss fights desperately!")


func _boss_turn() -> void:
	if not is_instance_valid(boss_creature):
		return
	
	var hero_cell := game.hero.cell if is_instance_valid(game.hero) else Vector2i.ZERO
	
	# Boss priority:
	# 1. Use special ability if available
	# 2. Attack if adjacent
	# 3. Move toward hero
	
	await _use_boss_ability()
	
	# Boss can attack and move
	if boss_creature.can_attack(TurnManager.turn_number):
		await attack_if_possible(boss_creature)
	
	if boss_creature.can_move(TurnManager.turn_number):
		await move_toward_target(boss_creature, hero_cell)
		# Try to attack after moving
		if boss_creature.can_attack(TurnManager.turn_number):
			await attack_if_possible(boss_creature)
	
	# Other minions act
	await _minion_turn()


func _use_boss_ability() -> void:
	if abilities_used_this_turn >= MAX_ABILITIES_PER_TURN:
		return
	
	# Simple ability: Heal self when low
	var health_percent := float(boss_creature.current_health) / float(boss_creature.max_health)
	if health_percent < 0.5 and boss_creature.current_health < boss_creature.max_health:
		var heal_amount := 3
		boss_creature.current_health = min(boss_creature.max_health, boss_creature.current_health + heal_amount)
		game.log_event("The boss regenerates %d health!" % heal_amount)
		abilities_used_this_turn += 1
		await game.pause(0.3)


func _minion_turn() -> void:
	# Minions use simple AI
	var hero_cell := game.hero.cell if is_instance_valid(game.hero) else Vector2i.ZERO
	var actors: Array[Creature] = get_enemy_creatures()
	
	for creature in actors:
		if not is_instance_valid(creature) or creature == boss_creature:
			continue
		if TurnManager.is_game_over():
			break
		
		if creature.can_move(TurnManager.turn_number):
			await move_toward_target(creature, hero_cell)
		
		if creature.can_attack(TurnManager.turn_number):
			await attack_if_possible(creature)
