extends RefCounted
class_name LyonarDeck

# Lyonar Faction: Durable, positional control
# Identity: Elite units, defensive buffs, zone control

static func build_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	
	# Hero Unit (1x)
	deck.append(_create_hero())
	
	# Core Units - Fixed counts, no randomness
	# Ironclad Guardian - Frontline tank (5x)
	for i in range(5):
		deck.append(_create_ironclad_guardian())
	
	# War Chaplain - Support buffer (4x)
	for i in range(4):
		deck.append(_create_war_chaplain())
	
	# Solar Flare - Control tool (3x)
	for i in range(3):
		deck.append(_create_solar_flare())
	
	# Sacred Aegis - Protection tool (3x)
	for i in range(3):
		deck.append(_create_sacred_aegis())
	
	# Divine Light - Utility healing (9x)
	for i in range(9):
		deck.append(_create_divine_light())
	
	return deck

static func _create_hero() -> CardData:
	var card := CardData.new()
	card.display_name = "Aurora, Shield Commander"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 4
	card.attack = 2
	card.health = 8
	card.movement = 2
	card.description = "Shield Wall (3 mana, once/turn): Grant +2 health to adjacent allies until end of next turn."
	card.sprite_frames_path = "res://assets/duelyst/f1_general.tres"
	return card

static func _create_ironclad_guardian() -> CardData:
	var card := CardData.new()
	card.display_name = "Ironclad Guardian"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 3
	card.attack = 2
	card.health = 6
	card.movement = 1
	card.description = "Fortify: Cannot be moved by enemy abilities. Adjacent enemies have -1 attack."
	card.sprite_frames_path = "res://assets/duelyst/f1_guardian.tres"
	return card

static func _create_war_chaplain() -> CardData:
	var card := CardData.new()
	card.display_name = "War Chaplain"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 2
	card.attack = 1
	card.health = 4
	card.movement = 2
	card.description = "Bless: At start of turn, grant +1 health to adjacent ally with lowest health."
	card.sprite_frames_path = "res://assets/duelyst/f1_chaplain.tres"
	return card

static func _create_solar_flare() -> CardData:
	var card := CardData.new()
	card.display_name = "Solar Flare"
	card.card_type = CardData.CardType.SPELL
	card.cost = 3
	card.spell_damage = 2
	card.description = "Deal 2 damage to target enemy and adjacent enemies. Adjacent allies gain +1 attack this turn."
	card.sprite_frames_path = "res://assets/duelyst/f1_solar.tres"
	return card

static func _create_sacred_aegis() -> CardData:
	var card := CardData.new()
	card.display_name = "Sacred Aegis"
	card.card_type = CardData.CardType.SPELL
	card.cost = 2
	card.description = "Target ally gains Shield: Prevent next 2 damage. Lasts until used."
	card.sprite_frames_path = "res://assets/duelyst/f1_aegis.tres"
	return card

static func _create_divine_light() -> CardData:
	var card := CardData.new()
	card.display_name = "Divine Light"
	card.card_type = CardData.CardType.SPELL
	card.cost = 1
	card.description = "Heal target ally for 2 health."
	card.sprite_frames_path = "res://assets/duelyst/f1_light.tres"
	return card
