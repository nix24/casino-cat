class_name MapNavigation
extends RefCounted
## Which map nodes the cat can step to (PRD §3.1). Row 0 is "before row 1": the cat stands there at
## the start of an act. Pure lookups on a MapData; the map scene only asks.


## Where the cat stands when an act begins.
static func start_position() -> Vector2i:
	return Vector2i(0, 0)


## The nodes the cat can step to from [param position], left to right.
static func next_nodes(map: MapData, position: Vector2i) -> Array[MapNode]:
	var found: Array[MapNode] = []
	if position.x == 0:
		found = map.row_nodes(1)
	else:
		var here: MapNode = map.node_at(position.x, position.y)
		if here == null:
			return found
		for cell: Vector2i in here.next:
			var target: MapNode = map.node_at(cell.x, cell.y)
			if target != null:
				found.append(target)
	found.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.col < b.col)
	return found


## True when the node at ([param row], [param col]) is one of the next nodes from [param position].
static func is_reachable(map: MapData, position: Vector2i, row: int, col: int) -> bool:
	for node: MapNode in next_nodes(map, position):
		if node.row == row and node.col == col:
			return true
	return false
