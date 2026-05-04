class_name EncounterNode

var id: String
var type: EncounterType.Type
var layer_index: int
var connections: Array[String] = []
var completed: bool = false
var position_in_layer: int = 0

func _init(p_id: String, p_type: EncounterType.Type, p_layer: int = 0, p_position: int = 0) -> void:
	id = p_id
	type = p_type
	layer_index = p_layer
	position_in_layer = p_position

func add_connection(target_id: String) -> void:
	if target_id not in connections:
		connections.append(target_id)

func mark_completed() -> void:
	completed = true

func is_selectable(current_layer: int) -> bool:
	return not completed and layer_index == current_layer

func is_reachable(from_node: EncounterNode) -> bool:
	return from_node != null and id in from_node.connections

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"layer_index": layer_index,
		"position_in_layer": position_in_layer,
		"connections": connections.duplicate(),
		"completed": completed
	}

static func from_dict(data: Dictionary) -> EncounterNode:
	var node := EncounterNode.new(data["id"], data["type"], data["layer_index"], data.get("position_in_layer", 0))
	node.connections = data.get("connections", []).duplicate()
	node.completed = data.get("completed", false)
	return node
