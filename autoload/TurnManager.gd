extends Node

signal phase_changed(phase_name: String)
signal player_turn_started(turn_number: int)
signal enemy_turn_started(turn_number: int)
signal game_over(winner: String)

enum Phase { SETUP, PLAYER_TURN, ENEMY_TURN, GAME_OVER }

var phase := Phase.SETUP
var turn_number := 0


func start_game() -> void:
	phase = Phase.SETUP
	turn_number = 0
	start_player_turn()


func start_player_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	turn_number += 1
	phase = Phase.PLAYER_TURN
	emit_signal("phase_changed", "Player Turn")
	emit_signal("player_turn_started", turn_number)


func start_enemy_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	phase = Phase.ENEMY_TURN
	emit_signal("phase_changed", "Enemy Turn")
	emit_signal("enemy_turn_started", turn_number)


func finish_enemy_turn() -> void:
	if phase == Phase.GAME_OVER:
		return
	start_player_turn()


func end_game(winner: String) -> void:
	if phase == Phase.GAME_OVER:
		return
	phase = Phase.GAME_OVER
	emit_signal("phase_changed", "Game Over")
	emit_signal("game_over", winner)


func is_player_turn() -> bool:
	return phase == Phase.PLAYER_TURN


func is_enemy_turn() -> bool:
	return phase == Phase.ENEMY_TURN


func is_game_over() -> bool:
	return phase == Phase.GAME_OVER

