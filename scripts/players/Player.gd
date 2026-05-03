extends RefCounted
class_name Player

signal life_changed(value: int)
signal mana_changed(current: int, maximum: int)
signal hand_changed
signal deck_changed(count: int)

var display_name := "Player"
var life := 20
var max_mana := 0
var current_mana := 0
var mana_bonus := 0
var played_land_this_turn := false
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []


func setup(actor_name: String, starting_deck: Array[CardData], starting_life: int, starting_hand_size: int) -> void:
	display_name = actor_name
	life = starting_life
	max_mana = 0
	current_mana = 0
	mana_bonus = 0
	played_land_this_turn = false
	deck = starting_deck.duplicate()
	hand.clear()
	discard.clear()
	deck.shuffle()
	draw_cards(starting_hand_size)
	_emit_all()


func begin_turn(turn_number: int) -> void:
	played_land_this_turn = false
	max_mana = turn_number + mana_bonus
	current_mana = max_mana
	emit_signal("mana_changed", current_mana, max_mana)
	draw_cards(1)


func draw_cards(amount: int) -> void:
	for _i in amount:
		if deck.is_empty():
			return
		hand.append(deck.pop_back())
	emit_signal("hand_changed")
	emit_signal("deck_changed", deck.size())


func can_pay(cost: int) -> bool:
	return current_mana >= cost


func pay_mana(cost: int) -> bool:
	if not can_pay(cost):
		return false
	current_mana -= cost
	emit_signal("mana_changed", current_mana, max_mana)
	return true


func refund_mana(amount: int) -> void:
	current_mana = min(current_mana + amount, max_mana)
	emit_signal("mana_changed", current_mana, max_mana)


func play_land(card: CardData) -> bool:
	if played_land_this_turn or card == null or not card.is_land():
		return false
	if not remove_from_hand(card):
		return false
	var bonus: int = max(1, card.mana_bonus)
	mana_bonus += bonus
	max_mana += bonus
	current_mana += bonus
	played_land_this_turn = true
	discard.append(card)
	emit_signal("mana_changed", current_mana, max_mana)
	return true


func remove_from_hand(card: CardData) -> bool:
	var index := hand.find(card)
	if index == -1:
		return false
	hand.remove_at(index)
	emit_signal("hand_changed")
	return true


func discard_card(card: CardData) -> void:
	discard.append(card)


func take_damage(amount: int) -> void:
	life = max(0, life - amount)
	emit_signal("life_changed", life)


func heal(amount: int) -> void:
	life += amount
	emit_signal("life_changed", life)


func _emit_all() -> void:
	emit_signal("life_changed", life)
	emit_signal("mana_changed", current_mana, max_mana)
	emit_signal("hand_changed")
	emit_signal("deck_changed", deck.size())
