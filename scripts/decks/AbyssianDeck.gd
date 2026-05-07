extends RefCounted
class_name AbyssianDeck

# Abyssian Faction: Fragile hero + inefficient but scalable army
# Identity: Death-based value, attrition warfare, inevitable swarm

static func build_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	
	# Hero Unit (1x)
	deck.append(_create_hero())
	
	# Core Units - Fixed counts, no randomness
	# Wraithling - Swarm unit (6x)
	for i in range(6):
		deck.append(_create_wraithling())
	
	# Shadowdancer - Sacrifice engine (4x)
	for i in range(4):
		deck.append(_create_shadowdancer())
	
	# Soulshatter - Burst/risk unit (3x)
	for i in range(3):
		deck.append(_create_soulshatter())
	
	# Void Hunter - Removal unit (3x)
	for i in range(3):
		deck.append(_create_void_hunter())
	
	# Dark Ritual - Utility spell (8x)
	for i in range(8):
		deck.append(_create_dark_ritual())
	
	return deck

static func _create_hero() -> CardData:
	var card := CardData.new()
	card.display_name = "Cassyva, Soul Weaver"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 4
	card.attack = 3
	card.health = 5
	card.movement = 2
	card.description = "Dark Pact (2 mana, once/turn): Summon Wraithling adjacent. Only if damaged this turn."
	card.sprite_frames_path = "res://assets/duelyst/f4_general.tres"
	return card

static func _create_shadowdancer() -> CardData:
	var card := CardData.new()
	card.display_name = "Shadowdancer"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 2
	card.attack = 2
	card.health = 2
	card.movement = 2
	card.description = "Sacrifice: Destroy this + another friendly. Draw 1 card, gain 1 mana crystal (+2 max)."
	card.sprite_frames_path = "res://assets/duelyst/f4_shadowdancer.tres"
	return card

static func _create_wraithling() -> CardData:
	var card := CardData.new()
	card.display_name = "Wraithling"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 1
	card.attack = 1
	card.health = 1
	card.movement = 2
	card.description = "Death Rattle: If 3rd Wraithling dies this turn, summon Shadowling (1/1) at hero."
	card.sprite_frames_path = "res://assets/duelyst/f4_wraithling.tres"
	return card

static func _create_soulshatter() -> CardData:
	var card := CardData.new()
	card.display_name = "Soulshatter"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 3
	card.attack = 4
	card.health = 1
	card.movement = 2
	card.description = "Volatile: When dies, deal 3 damage to all adjacent units (friends included)."
	card.sprite_frames_path = "res://assets/duelyst/f4_soulshatter.tres"
	return card

static func _create_void_hunter() -> CardData:
	var card := CardData.new()
	card.display_name = "Void Hunter"
	card.card_type = CardData.CardType.CREATURE
	card.cost = 3
	card.attack = 3
	card.health = 3
	card.movement = 2
	card.description = "Hunt: Can attack enemies 2 cells away, but deals -1 damage when doing so."
	card.sprite_frames_path = "res://assets/duelyst/f4_hunter.tres"
	return card

static func _create_dark_ritual() -> CardData:
	var card := CardData.new()
	card.display_name = "Dark Ritual"
	card.card_type = CardData.CardType.SPELL
	card.cost = 2
	card.spell_damage = 2
	card.description = "Deal 2 damage to any unit. Heal Cassyva for 1."
	card.sprite_frames_path = "res://assets/duelyst/f4_ritual.tres"
	return card
