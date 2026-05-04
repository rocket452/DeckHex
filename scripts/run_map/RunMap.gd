class_name RunMap

signal node_completed(node_id: String)
signal layer_advanced(old_layer: int, new_layer: int)
signal map_completed

var all_nodes: Dictionary = {}  # id -> EncounterNode
var current_node_id: String = ""
var current_layer_index: int = 0
var max_layers: int = 4
var is_completed: bool = false

const LAYER_SIZES := [1, 2, 3, 2, 1]  # Number of nodes per layer (including start and boss)

func _init(p_max_layers: int = 4) -> void:
	max_layers = p_max_layers
	_generate_map()

func _generate_map() -> void:
	all_nodes.clear()
	current_layer_index = 0
	is_completed = false
	
	# Generate nodes for each layer
	for layer in range(max_layers + 1):  # +1 for boss layer
		var layer_size: int = LAYER_SIZES[mini(layer, LAYER_SIZES.size() - 1)]
		for pos in range(layer_size):
			var node_id := _make_node_id(layer, pos)
			var node_type := _determine_node_type(layer)
			var node := EncounterNode.new(node_id, node_type, layer, pos)
			all_nodes[node_id] = node
	
	# Create connections between layers
	_connect_layers()
	
	# Set start node
	current_node_id = _make_node_id(0, 0)
	get_current_node().completed = true

func _make_node_id(layer: int, position: int) -> String:
	return "node_%d_%d" % [layer, position]

func _determine_node_type(layer: int) -> EncounterType.Type:
	if layer == 0:
		return EncounterType.Type.START
	elif layer == max_layers:
		return EncounterType.Type.BOSS_ENCOUNTER
	else:
		# Random encounter types for middle layers
		var roll := randf()
		if roll < 0.5:
			return EncounterType.Type.PVP_ENCOUNTER
		elif roll < 0.8:
			return EncounterType.Type.STATIC_ENCOUNTER
		else:
			return EncounterType.Type.ELITE_ENCOUNTER

func _connect_layers() -> void:
	for layer in range(max_layers):
		var current_layer_size: int = LAYER_SIZES[mini(layer, LAYER_SIZES.size() - 1)]
		var next_layer_size: int = LAYER_SIZES[mini(layer + 1, LAYER_SIZES.size() - 1)]
		
		for pos in range(current_layer_size):
			var from_id := _make_node_id(layer, pos)
			var from_node: EncounterNode = all_nodes[from_id]
			
			# Connect to nodes in next layer
			# Each node connects to 1-2 nodes in the next layer
			var connections_count := mini(next_layer_size, 2)
			for i in range(connections_count):
				var target_pos := mini(pos + i, next_layer_size - 1)
				var to_id := _make_node_id(layer + 1, target_pos)
				from_node.add_connection(to_id)

func get_current_node() -> EncounterNode:
	return all_nodes.get(current_node_id, null)

func get_node(node_id: String) -> EncounterNode:
	return all_nodes.get(node_id, null)

func get_nodes_in_layer(layer: int) -> Array[EncounterNode]:
	var result: Array[EncounterNode] = []
	for node in all_nodes.values():
		if node.layer_index == layer:
			result.append(node)
	result.sort_custom(func(a, b): return a.position_in_layer < b.position_in_layer)
	return result

func get_reachable_nodes() -> Array[EncounterNode]:
	var current := get_current_node()
	if current == null:
		return []
	
	var result: Array[EncounterNode] = []
	for conn_id in current.connections:
		var node := get_node(conn_id)
		if node != null and not node.completed:
			result.append(node)
	return result

func can_select_node(node_id: String) -> bool:
	var node := get_node(node_id)
	if node == null or node.completed:
		return false
	
	var current := get_current_node()
	if current == null:
		return false
	
	return node.id in current.connections

func select_node(node_id: String) -> bool:
	if not can_select_node(node_id):
		return false
	
	current_node_id = node_id
	return true

func complete_current_node() -> void:
	var node := get_current_node()
	if node == null:
		return
	
	node.mark_completed()
	node_completed.emit(node.id)
	
	# Check if we need to advance layer
	if node.layer_index > current_layer_index:
		var old_layer := current_layer_index
		current_layer_index = node.layer_index
		layer_advanced.emit(old_layer, current_layer_index)
	
	# Check if map is completed (boss defeated)
	if node.type == EncounterType.Type.BOSS_ENCOUNTER:
		is_completed = true
		map_completed.emit()

func is_map_completed() -> bool:
	return is_completed

func to_dict() -> Dictionary:
	var nodes_data := {}
	for id in all_nodes.keys():
		nodes_data[id] = all_nodes[id].to_dict()
	
	return {
		"current_node_id": current_node_id,
		"current_layer_index": current_layer_index,
		"max_layers": max_layers,
		"is_completed": is_completed,
		"nodes": nodes_data
	}

func from_dict(data: Dictionary) -> void:
	current_node_id = data.get("current_node_id", "")
	current_layer_index = data.get("current_layer_index", 0)
	max_layers = data.get("max_layers", 4)
	is_completed = data.get("is_completed", false)
	
	all_nodes.clear()
	var nodes_data: Dictionary = data.get("nodes", {})
	for id in nodes_data.keys():
		all_nodes[id] = EncounterNode.from_dict(nodes_data[id])

func reset() -> void:
	_generate_map()
