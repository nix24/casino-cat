extends TestCase
## Which map nodes the cat can step to next (T010, arch §5: row 0 is before row 1).


func test_start_reaches_all_row1() -> void:
	var map: MapData = _map()
	var reached: Array[Vector2i] = _cells(MapNavigation.next_nodes(map, Vector2i(0, 0)))
	assert_eq(reached, [Vector2i(1, 0), Vector2i(1, 2), Vector2i(1, 4)])
	assert_eq(MapNavigation.start_position(), Vector2i(0, 0))


func test_next_nodes_follow_edges() -> void:
	var reached: Array[Vector2i] = _cells(MapNavigation.next_nodes(_map(), Vector2i(1, 2)))
	assert_eq(reached, [Vector2i(2, 1), Vector2i(2, 2)])


func test_missing_node_returns_empty() -> void:
	assert_eq(MapNavigation.next_nodes(_map(), Vector2i(3, 6)).size(), 0)


func test_is_reachable_matches_next_nodes() -> void:
	var map: MapData = MapGen.generate(1, TuningData.new(), SeededRng.new("NAV-1"))
	var positions: Array[Vector2i] = [MapNavigation.start_position()]
	for node: MapNode in map.nodes:
		positions.append(node.cell())
	for position: Vector2i in positions:
		var next: Array[Vector2i] = _cells(MapNavigation.next_nodes(map, position))
		for node: MapNode in map.nodes:
			assert_eq(
				MapNavigation.is_reachable(map, position, node.row, node.col),
				next.has(node.cell()),
				"from %s to %s" % [position, node.cell()]
			)


## Row 1 at cols 0, 2, 4; (1, 2) leads to (2, 1) and (2, 2), listed out of order on purpose.
func _map() -> MapData:
	var map := MapData.new()
	for col: int in [4, 0, 2]:
		map.nodes.append(MapNode.new(1, col))
	map.node_at(1, 2).next = [Vector2i(2, 2), Vector2i(2, 1)]
	map.nodes.append(MapNode.new(2, 1))
	map.nodes.append(MapNode.new(2, 2))
	return map


func _cells(nodes: Array[MapNode]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for node: MapNode in nodes:
		cells.append(node.cell())
	return cells
