extends Node

const STARTING_LIFE := 20
const STARTING_HAND_SIZE := 5

const CARD_PATHS := {
	"hero": "res://resources/cards/hero.tres",
	"basic_land": "res://resources/cards/basic_land.tres",
	"forest_land": "res://resources/cards/forest_land.tres",
	"mountain_land": "res://resources/cards/mountain_land.tres",
	"knight": "res://resources/cards/knight.tres",
	"archer": "res://resources/cards/archer.tres",
	"goblin": "res://resources/cards/goblin.tres",
	"defender": "res://resources/cards/defender.tres",
	"firebolt": "res://resources/cards/firebolt.tres",
	"zombie": "res://resources/cards/zombie.tres",
}

var cards := {}


func _ready() -> void:
	load_cards()


func load_cards() -> void:
	if not cards.is_empty():
		return
	for id in CARD_PATHS.keys():
		cards[id] = load(CARD_PATHS[id])


func get_card(id: String) -> CardData:
	load_cards()
	return cards.get(id)


func build_player_deck() -> Array[CardData]:
	return _cards_from_ids([
		"goblin", "goblin", "goblin", "goblin",
		"archer", "archer", "archer", "archer",
		"knight", "knight", "knight", "knight",
		"defender", "defender", "defender",
		"firebolt", "firebolt", "firebolt", "firebolt", "firebolt",
	])


func build_enemy_deck() -> Array[CardData]:
	return []


func _cards_from_ids(ids: Array[String]) -> Array[CardData]:
	var deck: Array[CardData] = []
	for id in ids:
		var card := get_card(id)
		if card != null:
			deck.append(card)
	return deck
