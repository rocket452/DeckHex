extends TileMap
class_name GridManager

const INVALID_CELL := Vector2i(-9999, -9999)

@export var columns := 8
@export var rows := 7
@export var hex_size := 59.0

var board_cells: Array[Vector2i] = []
var highlight_cells := {}
var enemy_movement_highlight_cells := {}
var hover_cell := INVALID_CELL
var astar_grid := AStarGrid2D.new()


func _ready() -> void:
	setup_board()


func setup_board() -> void:
	_create_simple_hex_tileset()
	clear()
	board_cells.clear()
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			board_cells.append(cell)
			set_cell(0, cell, 0, Vector2i.ZERO, 0)
	_setup_astar_grid()
	queue_redraw()


func _setup_astar_grid() -> void:
	astar_grid.region = Rect2i(0, 0, columns, rows)
	astar_grid.cell_size = Vector2.ONE
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar_grid.update()


func _create_simple_hex_tileset() -> void:
	if tile_set != null:
		return
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.001))
	var texture := ImageTexture.create_from_image(image)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(96, 96)
	source.create_tile(Vector2i.ZERO)

	var new_tile_set := TileSet.new()
	new_tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	new_tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	new_tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	new_tile_set.tile_size = Vector2i(96, 96)
	new_tile_set.add_source(source, 0)
	tile_set = new_tile_set


func cell_to_local(cell: Vector2i) -> Vector2:
	var hex_width := sqrt(3.0) * hex_size
	var row_offset := 0.0
	if posmod(cell.y, 2) == 1:
		row_offset = hex_width * 0.5
	return Vector2(
		cell.x * hex_width + row_offset + hex_width * 0.5,
		cell.y * hex_size * 1.5 + hex_size + 4.0
	)


func local_to_cell(local_position: Vector2) -> Vector2i:
	for cell in board_cells:
		if Geometry2D.is_point_in_polygon(local_position, get_hex_corners(cell)):
			return cell
	return INVALID_CELL


func get_hex_corners(cell: Vector2i) -> PackedVector2Array:
	var center := cell_to_local(cell)
	var corners := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		corners.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return corners


func get_board_bounds() -> Rect2:
	var first := true
	var bounds := Rect2()
	for cell in board_cells:
		for corner in get_hex_corners(cell):
			if first:
				bounds = Rect2(corner, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(corner)
	return bounds.grow(8.0)


func get_board_size() -> Vector2:
	return get_board_bounds().size


func set_hover_cell(cell: Vector2i) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	queue_redraw()


func clear_highlights() -> void:
	highlight_cells.clear()
	queue_redraw()


func add_highlights(cells: Array, color: Color) -> void:
	for cell in cells:
		if is_valid_cell(cell):
			highlight_cells[cell] = color
	queue_redraw()


func set_enemy_movement_highlights(cells: Array, color: Color) -> void:
	enemy_movement_highlight_cells.clear()
	for cell in cells:
		if is_valid_cell(cell):
			enemy_movement_highlight_cells[cell] = color
	queue_redraw()


func clear_enemy_movement_highlights() -> void:
	enemy_movement_highlight_cells.clear()
	queue_redraw()


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


func is_player_summon_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x <= 1


func is_enemy_summon_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x >= columns - 2


func get_player_summon_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in board_cells:
		if is_player_summon_cell(cell):
			cells.append(cell)
	return cells


func get_enemy_summon_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in board_cells:
		if is_enemy_summon_cell(cell):
			cells.append(cell)
	return cells


func get_enemy_home_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows:
		cells.append(Vector2i(columns - 1, y))
	return cells


func get_player_home_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows:
		cells.append(Vector2i(0, y))
	return cells


func is_enemy_home_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x == columns - 1


func is_player_home_cell(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and cell.x == 0


func get_player_hero_spawn_cell() -> Vector2i:
	return Vector2i(0, int(rows / 2))


func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
	]
	if posmod(cell.y, 2) == 1:
		offsets.append_array([
			Vector2i(1, -1),
			Vector2i(0, -1),
			Vector2i(1, 1),
			Vector2i(0, 1),
		])
	else:
		offsets.append_array([
			Vector2i(0, -1),
			Vector2i(-1, -1),
			Vector2i(0, 1),
			Vector2i(-1, 1),
		])

	var neighbors: Array[Vector2i] = []
	for offset in offsets:
		var next: Vector2i = cell + offset
		if is_valid_cell(next):
			neighbors.append(next)
	return neighbors


func offset_to_cube(cell: Vector2i) -> Vector3i:
	var parity := posmod(cell.y, 2)
	var cube_x := cell.x - int((cell.y - parity) / 2)
	var cube_z := cell.y
	var cube_y := -cube_x - cube_z
	return Vector3i(cube_x, cube_y, cube_z)


func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return max(abs(ac.x - bc.x), max(abs(ac.y - bc.y), abs(ac.z - bc.z)))


func get_cells_in_range(origin: Vector2i, range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in board_cells:
		if cell != origin and hex_distance(origin, cell) <= range:
			cells.append(cell)
	return cells


func get_reachable_cells(origin: Vector2i, movement: int, blocked_cells: Dictionary) -> Array[Vector2i]:
	_update_astar_solids(blocked_cells, origin)
	var astar_reachable: Array[Vector2i] = []
	for cell in board_cells:
		if cell == origin or blocked_cells.has(cell):
			continue
		if hex_distance(origin, cell) > movement:
			continue
		var path := get_astar_id_path(origin, cell)
		if path.size() > 1 and _hex_steps_in_path(path) <= movement:
			astar_reachable.append(cell)
	if not astar_reachable.is_empty():
		return astar_reachable
	return _get_reachable_cells_by_hex_bfs(origin, movement, blocked_cells)


func get_astar_id_path(origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var raw_path := astar_grid.get_id_path(origin, target)
	var path: Array[Vector2i] = []
	for point in raw_path:
		path.append(point)
	return path


func _update_astar_solids(blocked_cells: Dictionary, origin: Vector2i) -> void:
	for cell in board_cells:
		astar_grid.set_point_solid(cell, blocked_cells.has(cell) and cell != origin)


func _hex_steps_in_path(path: Array[Vector2i]) -> int:
	if path.size() < 2:
		return 0
	var steps := 0
	for index in range(1, path.size()):
		var previous := path[index - 1]
		var current := path[index]
		if previous == current:
			continue
		if hex_distance(previous, current) != 1:
			steps += hex_distance(previous, current)
		else:
			steps += 1
	return steps


func _get_reachable_cells_by_hex_bfs(origin: Vector2i, movement: int, blocked_cells: Dictionary) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [origin]
	var cost_by_cell := {origin: 0}
	var index := 0

	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for next in get_neighbors(current):
			if blocked_cells.has(next) and next != origin:
				continue
			var next_cost: int = cost_by_cell[current] + 1
			if next_cost <= movement and not cost_by_cell.has(next):
				cost_by_cell[next] = next_cost
				frontier.append(next)

	var reachable: Array[Vector2i] = []
	for cell in cost_by_cell.keys():
		if cell != origin:
			reachable.append(cell)
	return reachable


func distance_to_home(cell: Vector2i, home_owner: String) -> int:
	var homes := get_enemy_home_cells()
	if home_owner == "player":
		homes = get_player_home_cells()
	var best := 999
	for home_cell in homes:
		best = min(best, hex_distance(cell, home_cell))
	return best


func _draw() -> void:
	for cell in board_cells:
		var base_color := Color(0.18, 0.22, 0.24, 0.82)
		if is_player_summon_cell(cell):
			base_color = Color(0.16, 0.24, 0.27, 0.88)
		elif is_enemy_summon_cell(cell):
			base_color = Color(0.25, 0.18, 0.20, 0.88)

		var corners := get_hex_corners(cell)
		draw_colored_polygon(corners, base_color)

		if enemy_movement_highlight_cells.has(cell):
			draw_colored_polygon(corners, enemy_movement_highlight_cells[cell])

		if highlight_cells.has(cell):
			draw_colored_polygon(corners, highlight_cells[cell])

		if cell == hover_cell:
			draw_colored_polygon(corners, Color(1.0, 0.96, 0.72, 0.12))

		draw_polyline(_closed_polygon(corners), Color(0.73, 0.67, 0.48, 0.7), 2.0, true)


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array()
	for point in points:
		closed.append(point)
	if points.size() > 0:
		closed.append(points[0])
	return closed
