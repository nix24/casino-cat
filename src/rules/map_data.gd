class_name MapData
extends RefCounted
## One act's map: only the nodes that lie on a walk (PRD §3.1). Saved inside run.json (arch §6).

const SAVE_CONTEXT: String = "run.json map"

var act: int = 1
## Sorted by row, then column.
var nodes: Array[MapNode] = []


## The node at ([param row], [param col]), or null if that cell is empty.
func node_at(row: int, col: int) -> MapNode:
	for node: MapNode in nodes:
		if node.row == row and node.col == col:
			return node
	return null


## Every node on [param row], left to right.
func row_nodes(row: int) -> Array[MapNode]:
	var found: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.row == row:
			found.append(node)
	return found


## Nodes on row - 1 with an edge into [param node].
func parents_of(node: MapNode) -> Array[MapNode]:
	var found: Array[MapNode] = []
	for candidate: MapNode in row_nodes(node.row - 1):
		if candidate.next.has(node.cell()):
			found.append(candidate)
	return found


func to_dict() -> Dictionary:
	var plain_nodes: Array[Dictionary] = []
	for node: MapNode in nodes:
		var plain_next: Array[Array] = []
		for cell: Vector2i in node.next:
			plain_next.append([cell.x, cell.y])
		var entry: Dictionary = {
			"row": node.row,
			"col": node.col,
			"type": MapNode.type_name(node.type),
			"next": plain_next,
			"payload": node.payload.duplicate(),
		}
		plain_nodes.append(entry)
	return {"act": act, "nodes": plain_nodes}


## Returns null (after a warning) on a bad shape: a missing key, a wrong type, an unknown node
## type, or an edge that isn't a [row, col] pair. "payload" is optional (maps saved before T009
## carried none).
static func from_dict(d: Dictionary) -> MapData:
	var reader := SaveReader.new(d, SAVE_CONTEXT)
	var map := MapData.new()
	map.act = reader.int_at("act")
	var entries: Array[Dictionary] = reader.dicts_at("nodes")
	if not reader.ok():
		reader.warn()
		return null
	for entry: Dictionary in entries:
		var node: MapNode = _node_from(entry)
		if node == null:
			return null
		map.nodes.append(node)
	return map


static func _node_from(entry: Dictionary) -> MapNode:
	var reader := SaveReader.new(entry, SAVE_CONTEXT + " node")
	var node := MapNode.new(reader.int_at("row"), reader.int_at("col"))
	var type_text: String = reader.string_at("type")
	var edges: Array = reader.array_at("next")
	var payload: Dictionary = reader.dict_at("payload") if entry.has("payload") else {}
	if not reader.ok():
		reader.warn()
		return null
	var type_index: int = MapNode.type_from_name(type_text)
	if type_index < 0:
		push_warning("%s node: type: unknown value" % SAVE_CONTEXT)
		return null
	node.type = type_index as MapNode.Type
	for edge: Variant in edges:
		var pair := SaveReader.new({"next": edge}, SAVE_CONTEXT + " node")
		var cell: Array[int] = pair.ints_at("next", 2)
		if not pair.ok():
			pair.warn()
			return null
		node.next.append(Vector2i(cell[0], cell[1]))
	for key: Variant in payload:
		if not (key is String and payload[key] is String):
			push_warning("%s node: payload: wrong type" % SAVE_CONTEXT)
			return null
		node.payload[key] = payload[key]
	return node
