extends Resource
class_name CardData

enum CardType { LAND, CREATURE, SPELL }

@export var id := ""
@export var display_name := "Card"
@export var card_type := CardType.CREATURE
@export var cost := 0
@export_multiline var description := ""
@export var attack := 0
@export var health := 0
@export var movement := 0
@export var attack_range := 1
@export var spell_damage := 0
@export var mana_bonus := 0
@export var keywords: PackedStringArray = PackedStringArray()
@export var accent_color := Color(0.25, 0.3, 0.34, 1.0)
@export var sprite_frames_path := ""


func is_land() -> bool:
	return card_type == CardType.LAND


func is_creature() -> bool:
	return card_type == CardType.CREATURE


func is_spell() -> bool:
	return card_type == CardType.SPELL


func type_name() -> String:
	match card_type:
		CardType.LAND:
			return "Land"
		CardType.CREATURE:
			return "Creature"
		CardType.SPELL:
			return "Spell"
	return "Card"


func stats_line() -> String:
	if is_creature():
		return "%d ATK / %d HP  Move %d  Range %d" % [attack, health, movement, attack_range]
	if is_spell():
		return "%d damage" % spell_damage
	if is_land():
		return "+%d max mana" % mana_bonus
	return ""


func rules_text() -> String:
	var text := description
	if keywords.size() > 0:
		if not text.is_empty():
			text += "\n"
		text += "Keywords: " + ", ".join(keywords)
	return text.strip_edges()

