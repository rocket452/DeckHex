class_name EncounterType

enum Type {
	PVP_ENCOUNTER,
	STATIC_ENCOUNTER,
	ELITE_ENCOUNTER,
	BOSS_ENCOUNTER,
	START,
	EMPTY
}

const TYPE_NAMES := {
	Type.PVP_ENCOUNTER: "Battle",
	Type.STATIC_ENCOUNTER: "Encounter",
	Type.ELITE_ENCOUNTER: "Elite",
	Type.BOSS_ENCOUNTER: "Boss",
	Type.START: "Start",
	Type.EMPTY: "Empty"
}

const TYPE_COLORS := {
	Type.PVP_ENCOUNTER: Color(0.4, 0.6, 1.0),
	Type.STATIC_ENCOUNTER: Color(0.6, 0.8, 0.4),
	Type.ELITE_ENCOUNTER: Color(0.9, 0.5, 0.2),
	Type.BOSS_ENCOUNTER: Color(0.9, 0.2, 0.2),
	Type.START: Color(0.5, 0.5, 0.5),
	Type.EMPTY: Color(0.3, 0.3, 0.3)
}

static func get_display_name(type: Type) -> String:
	return TYPE_NAMES.get(type, "Unknown")

static func get_display_color(type: Type) -> Color:
	return TYPE_COLORS.get(type, Color.WHITE)
