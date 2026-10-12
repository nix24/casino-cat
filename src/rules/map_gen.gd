class_name MapGen
extends RefCounted
## Builds and checks act maps (PRD §3.1, arch §7, decisions D31 and D52). Pure: every random
## choice comes from the map stream passed in, so a seed always makes the same maps.

const MAX_ATTEMPTS: int = 50
## Column re-picks for one step before the walk restarts from row 1 (D31).
const MAX_PICKS: int = 10
## Walk restarts before the whole attempt is thrown away.
const MAX_WALK_RESTARTS: int = 10
## Weighted type re-samples after the first draw before falling back to BATTLE (D31).
const MAX_RESAMPLES: int = 20

const FIRST_ROW: int = 1
const TREASURE_ROW: int = 8
const REST_ROW: int = 14
const BOSS_ROW: int = 15
const BOSS_COL: int = 3
## Elites and rests may not appear on rows before this one.
const EARLIEST_ELITE_REST_ROW: int = 5
## Last-chance forcing rows (D52). Row 13 can't be a rest, so the rest is forced one row earlier.
const FORCE_REST_ROW: int = 12
const FORCE_SHOP_ROW: int = 13
const MIN_ELITES: int = 2

## Weighted-row odds per act, in PRD §3.1 table order. Each act sums to 100.
const WEIGHT_TYPES: Array[MapNode.Type] = [
	MapNode.Type.BATTLE,
	MapNode.Type.EVENT,
	MapNode.Type.ELITE,
	MapNode.Type.REST,
	MapNode.Type.SHOP
]
const WEIGHTS: Dictionary[int, Array] = {
	1: [50, 22, 8, 12, 8],
	2: [45, 22, 11, 12, 10],
	3: [42, 22, 14, 12, 10],
}
## Each act's elites (PRD §9.3). One is pre-rolled onto every ELITE node (D31).
const ELITE_IDS: Dictionary[int, Array] = {
	1: [&"bouncer_bulldog", &"card_sharp_weasel"],
	2: [&"pit_boss_gorilla", &"twin_dealers"],
	3: [&"bodyguard_bear", &"heiress_persian"],
}
const RARITIES: Array[String] = ["common", "uncommon", "rare"]
## Relic rarity odds in percent: treasure chests (PRD §10.4) and the shop relic (PRD §10.2).
const TREASURE_RARITY_ODDS: Array[int] = [50, 35, 15]
const SHOP_RARITY_ODDS: Array[int] = [70, 25, 5]

## The fallback lanes (D31): three straight columns with this type on rows 1-14.
const FALLBACK_COLS: Array[int] = [1, 3, 5]
const FALLBACK_ROWS: Array[MapNode.Type] = [
	MapNode.Type.BATTLE,
	MapNode.Type.EVENT,
	MapNode.Type.BATTLE,
	MapNode.Type.SHOP,
	MapNode.Type.BATTLE,
	MapNode.Type.EVENT,
	MapNode.Type.ELITE,
	MapNode.Type.TREASURE,
	MapNode.Type.BATTLE,
	MapNode.Type.REST,
	MapNode.Type.EVENT,
	MapNode.Type.SHOP,
	MapNode.Type.ELITE,
	MapNode.Type.REST,
]

## Path flag bits tracked per node: which of shop and rest a path has passed.
const HAS_SHOP: int = 1
const HAS_REST: int = 2
## Bit sets of path masks (bit m = mask m reaches the node) that lack a shop or a rest.
const LACKS_SHOP: int = (1 << 0) | (1 << HAS_REST)
const LACKS_REST: int = (1 << 0) | (1 << HAS_SHOP)


## A valid map for [param act] (1-3), drawn from [param rng] (the run's map stream). After
## MAX_ATTEMPTS invalid tries it logs an error and returns [method fallback].
static func generate(act: int, tuning: TuningData, rng: SeededRng) -> MapData:
	assert(WEIGHTS.has(act), "act must be 1-3")
	assert(tuning.map_rows == BOSS_ROW, "fixed rows assume a 15-row map")
	var map: MapData = null
	for _attempt: int in MAX_ATTEMPTS:
		var candidate: MapData = _attempt_map(act, tuning, rng)
		if candidate != null and validate(candidate).is_empty():
			map = candidate
			break
	if map == null:
		push_error("map fallback used, act %d" % act)
		map = fallback(act)
	_roll_payloads(map, rng)
	return map


## Every broken PRD §3.1 rule on [param map], one message each; empty when the map is valid.
static func validate(map: MapData) -> PackedStringArray:
	var problems := PackedStringArray()
	_check_shape(map, problems)
	_check_crossings(map, problems)
	_check_types(map, problems)
	_check_paths(map, problems)
	return problems


## The hand-written map used when generation fails (D31), without payloads.
static func fallback(act: int) -> MapData:
	var map := MapData.new()
	map.act = act
	for row: int in range(FIRST_ROW, REST_ROW + 1):
		for col: int in FALLBACK_COLS:
			var node := MapNode.new(row, col, FALLBACK_ROWS[row - FIRST_ROW])
			node.next.append(Vector2i(row + 1, BOSS_COL if row == REST_ROW else col))
			map.nodes.append(node)
	map.nodes.append(MapNode.new(BOSS_ROW, BOSS_COL, MapNode.Type.BOSS))
	return map


## True when edge [param a]→[param b] crosses edge [param c]→[param d] between the same rows.
## Shared endpoints never cross.
static func edges_cross(a: int, b: int, c: int, d: int) -> bool:
	return (a - c) * (b - d) < 0


static func _attempt_map(act: int, tuning: TuningData, rng: SeededRng) -> MapData:
	# edges[r] holds Vector2i(from_col, to_col) for the edges from row r to row r + 1.
	var edges: Array[Array] = []
	for _row: int in BOSS_ROW + 1:
		edges.append([])
	for start: int in _distinct_starts(tuning.map_cols, tuning.map_walks, rng):
		var walk: Array[Vector3i] = _walk(start, edges, tuning.map_cols, rng)
		if walk.is_empty():
			return null
		for step: Vector3i in walk:
			var edge := Vector2i(step.y, step.z)
			if not edges[step.x].has(edge):
				edges[step.x].append(edge)
	var map: MapData = _build_nodes(act, edges)
	_assign_types(map, rng)
	return map


## [param count] distinct columns, sampled without replacement (D31).
static func _distinct_starts(cols: int, count: int, rng: SeededRng) -> Array[int]:
	var pool: Array[int] = []
	for col: int in cols:
		pool.append(col)
	for i: int in count:
		var j: int = rng.range_int(i, cols - 1)
		var swap: int = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	return pool.slice(0, count)


## One walk from [param start] on row 1 to the boss, as Vector3i(row, from_col, to_col) steps.
## A step that keeps crossing restarts the walk (D31). Empty when every restart failed.
static func _walk(start: int, edges: Array[Array], cols: int, rng: SeededRng) -> Array[Vector3i]:
	for _restart: int in MAX_WALK_RESTARTS:
		var steps: Array[Vector3i] = []
		var col: int = start
		for row: int in range(FIRST_ROW, REST_ROW):
			var picked: int = _pick_step(row, col, edges, cols, rng)
			if picked < 0:
				break
			steps.append(Vector3i(row, col, picked))
			col = picked
		if steps.size() == REST_ROW - FIRST_ROW:
			steps.append(Vector3i(REST_ROW, col, BOSS_COL))
			return steps
	return []


## The next column from [param col] that crosses no edge already on [param row], or -1.
static func _pick_step(row: int, col: int, edges: Array[Array], cols: int, rng: SeededRng) -> int:
	var choices: Array[int] = []
	for next_col: int in [col - 1, col, col + 1]:
		if next_col >= 0 and next_col < cols:
			choices.append(next_col)
	for _pick: int in MAX_PICKS:
		var next_col: int = choices[rng.range_int(0, choices.size() - 1)]
		var crosses: bool = false
		for edge: Vector2i in edges[row]:
			if edges_cross(col, next_col, edge.x, edge.y):
				crosses = true
				break
		if not crosses:
			return next_col
	return -1


static func _build_nodes(act: int, edges: Array[Array]) -> MapData:
	var by_cell: Dictionary[Vector2i, MapNode] = {}
	for row: int in edges.size():
		for edge: Vector2i in edges[row]:
			var from: MapNode = _node_for(by_cell, Vector2i(row, edge.x))
			var to: MapNode = _node_for(by_cell, Vector2i(row + 1, edge.y))
			if not from.next.has(to.cell()):
				from.next.append(to.cell())
	var map := MapData.new()
	map.act = act
	for node: MapNode in by_cell.values():
		node.next.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
		map.nodes.append(node)
	map.nodes.sort_custom(_before)
	return map


static func _node_for(by_cell: Dictionary[Vector2i, MapNode], cell: Vector2i) -> MapNode:
	if not by_cell.has(cell):
		by_cell[cell] = MapNode.new(cell.x, cell.y)
	return by_cell[cell]


static func _before(a: MapNode, b: MapNode) -> bool:
	return a.row < b.row or (a.row == b.row and a.col < b.col)


## Types in row order: fixed rows, then last-chance forcing (D52), then weighted sampling.
static func _assign_types(map: MapData, rng: SeededRng) -> void:
	var reach: Dictionary[Vector2i, int] = {}
	for node: MapNode in map.nodes:
		var parents: Array[MapNode] = map.parents_of(node)
		var incoming: int = _incoming(node, parents, reach)
		reach[node.cell()] = incoming
		var fixed: int = _fixed_type(node.row)
		if fixed >= 0:
			node.type = fixed as MapNode.Type
		elif _must_force(node.row, incoming, parents, MapNode.Type.REST):
			node.type = MapNode.Type.REST
			node.forced = true
		elif _must_force(node.row, incoming, parents, MapNode.Type.SHOP):
			node.type = MapNode.Type.SHOP
			node.forced = true
		else:
			node.type = _sample_type(map.act, node.row, parents, rng)


## The fixed type of [param row], or -1 for a weighted row.
static func _fixed_type(row: int) -> int:
	match row:
		FIRST_ROW:
			return MapNode.Type.BATTLE
		TREASURE_ROW:
			return MapNode.Type.TREASURE
		REST_ROW:
			return MapNode.Type.REST
		BOSS_ROW:
			return MapNode.Type.BOSS
	return -1


static func _must_force(
	row: int, incoming: int, parents: Array[MapNode], node_type: MapNode.Type
) -> bool:
	var force_row: int = FORCE_REST_ROW if node_type == MapNode.Type.REST else FORCE_SHOP_ROW
	var lacking: int = LACKS_REST if node_type == MapNode.Type.REST else LACKS_SHOP
	return row == force_row and incoming & lacking != 0 and not _has_parent_type(parents, node_type)


static func _sample_type(
	act: int, row: int, parents: Array[MapNode], rng: SeededRng
) -> MapNode.Type:
	var weights: Array = WEIGHTS[act]
	for _draw: int in MAX_RESAMPLES + 1:
		var roll: int = rng.range_int(1, 100)
		var node_type: MapNode.Type = WEIGHT_TYPES[0]
		var cumulative: int = 0
		for i: int in WEIGHT_TYPES.size():
			cumulative += weights[i]
			if roll <= cumulative:
				node_type = WEIGHT_TYPES[i]
				break
		if _allowed(node_type, row, parents):
			return node_type
	return MapNode.Type.BATTLE


## The PRD §3.1 weighted-row constraints for [param node_type] at [param row].
static func _allowed(node_type: MapNode.Type, row: int, parents: Array[MapNode]) -> bool:
	var is_elite_or_rest: bool = node_type == MapNode.Type.ELITE or node_type == MapNode.Type.REST
	if is_elite_or_rest and row < EARLIEST_ELITE_REST_ROW:
		return false
	if node_type == MapNode.Type.REST and row == REST_ROW - 1:
		return false
	if _no_repeat(node_type) and _has_parent_type(parents, node_type):
		return false
	return true


static func _no_repeat(node_type: MapNode.Type) -> bool:
	return node_type in [MapNode.Type.SHOP, MapNode.Type.REST, MapNode.Type.ELITE]


static func _has_parent_type(parents: Array[MapNode], node_type: MapNode.Type) -> bool:
	for parent: MapNode in parents:
		if parent.type == node_type:
			return true
	return false


## The set of path masks reaching [param node] before its own type counts. Bit m is set when
## some path from row 1 arrives with flags m (HAS_SHOP, HAS_REST).
static func _incoming(
	node: MapNode, parents: Array[MapNode], reach: Dictionary[Vector2i, int]
) -> int:
	if node.row == FIRST_ROW:
		return 1 << 0
	var incoming: int = 0
	for parent: MapNode in parents:
		var flag: int = 0
		if parent.type == MapNode.Type.SHOP:
			flag = HAS_SHOP
		elif parent.type == MapNode.Type.REST:
			flag = HAS_REST
		var masks: int = reach.get(parent.cell(), 0)
		for mask: int in 4:
			if masks & (1 << mask) != 0:
				incoming |= 1 << (mask | flag)
	return incoming


static func _roll_payloads(map: MapData, rng: SeededRng) -> void:
	for node: MapNode in map.nodes:
		match node.type:
			MapNode.Type.ELITE:
				var elites: Array = ELITE_IDS[map.act]
				var elite_id: StringName = elites[rng.range_int(0, elites.size() - 1)]
				node.payload["elite_id"] = String(elite_id)
			MapNode.Type.TREASURE:
				node.payload["treasure_rarity"] = _roll_rarity(TREASURE_RARITY_ODDS, rng)
			MapNode.Type.SHOP:
				node.payload["shop_relic_rarity"] = _roll_rarity(SHOP_RARITY_ODDS, rng)


static func _roll_rarity(odds: Array[int], rng: SeededRng) -> String:
	var roll: int = rng.range_int(1, 100)
	var cumulative: int = 0
	for i: int in odds.size():
		cumulative += odds[i]
		if roll <= cumulative:
			return RARITIES[i]
	return RARITIES[RARITIES.size() - 1]


static func _check_shape(map: MapData, problems: PackedStringArray) -> void:
	var bosses: Array[MapNode] = map.row_nodes(BOSS_ROW)
	if bosses.size() != 1 or bosses[0].type != MapNode.Type.BOSS or bosses[0].col != BOSS_COL:
		problems.append("row 15 must be one BOSS node in col 3")
	for node: MapNode in map.nodes:
		var at: String = "row %d col %d" % [node.row, node.col]
		if node.row < FIRST_ROW or node.row > BOSS_ROW:
			problems.append("%s: outside rows 1-15" % at)
			continue
		if node.row > FIRST_ROW and map.parents_of(node).is_empty():
			problems.append("%s: no path leads here" % at)
		if node.row == BOSS_ROW:
			continue
		if node.next.is_empty():
			problems.append("%s: leads nowhere" % at)
		for cell: Vector2i in node.next:
			if cell.x != node.row + 1 or map.node_at(cell.x, cell.y) == null:
				problems.append("%s: edge to missing node %s" % [at, cell])
		if node.row == REST_ROW and node.next != [Vector2i(BOSS_ROW, BOSS_COL)]:
			problems.append("%s: must lead only to the boss" % at)


static func _check_crossings(map: MapData, problems: PackedStringArray) -> void:
	for row: int in range(FIRST_ROW, BOSS_ROW):
		var edges: Array[Vector2i] = []
		for node: MapNode in map.row_nodes(row):
			for cell: Vector2i in node.next:
				edges.append(Vector2i(node.col, cell.y))
		for i: int in edges.size():
			for j: int in range(i + 1, edges.size()):
				if edges_cross(edges[i].x, edges[i].y, edges[j].x, edges[j].y):
					problems.append(
						(
							"row %d: edges %d→%d and %d→%d cross"
							% [row, edges[i].x, edges[i].y, edges[j].x, edges[j].y]
						)
					)


static func _check_types(map: MapData, problems: PackedStringArray) -> void:
	var elites: int = 0
	for node: MapNode in map.nodes:
		var at: String = "row %d col %d" % [node.row, node.col]
		var type_text: String = MapNode.type_name(node.type)
		if node.type == MapNode.Type.ELITE:
			elites += 1
		var fixed: int = _fixed_type(node.row)
		if fixed >= 0:
			if node.type != fixed:
				problems.append(
					(
						"%s: row %d must be %s, not %s"
						% [at, node.row, MapNode.type_name(fixed as MapNode.Type), type_text]
					)
				)
			continue
		if node.type == MapNode.Type.TREASURE or node.type == MapNode.Type.BOSS:
			problems.append("%s: %s only belongs on its fixed row" % [at, type_text])
		var is_elite_or_rest: bool = (
			node.type == MapNode.Type.ELITE or node.type == MapNode.Type.REST
		)
		if is_elite_or_rest and node.row < EARLIEST_ELITE_REST_ROW:
			problems.append("%s: %s before row 5" % [at, type_text])
		if node.type == MapNode.Type.REST and node.row == REST_ROW - 1:
			problems.append("%s: rest on row 13" % at)
		if _no_repeat(node.type) and _has_parent_type(map.parents_of(node), node.type):
			problems.append("%s: two %s nodes in a row" % [at, type_text])
	if elites < MIN_ELITES:
		problems.append("map has %d elites, needs %d" % [elites, MIN_ELITES])


## Every path from row 1 must pass a shop and a rest before row 14, checked by tracking path
## flags per node rather than enumerating paths.
static func _check_paths(map: MapData, problems: PackedStringArray) -> void:
	var ordered: Array[MapNode] = map.nodes.duplicate()
	ordered.sort_custom(_before)
	var reach: Dictionary[Vector2i, int] = {}
	for node: MapNode in ordered:
		reach[node.cell()] = _incoming(node, map.parents_of(node), reach)
	for node: MapNode in map.row_nodes(REST_ROW):
		var masks: int = reach[node.cell()]
		if masks & LACKS_SHOP != 0:
			problems.append("path through col %d has no SHOP before row 14" % node.col)
		if masks & LACKS_REST != 0:
			problems.append("path through col %d has no REST before row 14" % node.col)
