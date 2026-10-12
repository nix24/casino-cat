class_name MapSim
extends RefCounted
## Shared seed sweeps for the map sims (T009). Seeds are "SIM-%05d".

## Rows where every weighted type is allowed by row (D52); the frequency gate looks only here.
const FREQUENCY_ROWS: Array[int] = [5, 6, 7, 9, 10, 11, 12]
const TOLERANCE_POINTS: float = 3.0


## Generates [param seeds] maps per act and asserts each validates.
static func assert_valid(test: TestCase, seeds: int) -> void:
	var tuning := TuningData.new()
	for act: int in [1, 2, 3]:
		for i: int in seeds:
			var map: MapData = MapGen.generate(act, tuning, SeededRng.new("SIM-%05d" % i))
			var problems: PackedStringArray = MapGen.validate(map)
			test.assert_true(problems.is_empty(), "act %d seed %d: %s" % [act, i, problems])
			if not problems.is_empty():
				return


## Asserts the share of each type among freely sampled nodes on FREQUENCY_ROWS is within
## TOLERANCE_POINTS of its PRD §3.1 weight. Returns the printed table.
static func assert_frequencies(test: TestCase, seeds: int) -> String:
	var tuning := TuningData.new()
	var table: String = ""
	for act: int in [1, 2, 3]:
		var counts: Dictionary[MapNode.Type, int] = {}
		var total: int = 0
		for i: int in seeds:
			var map: MapData = MapGen.generate(act, tuning, SeededRng.new("SIM-%05d" % i))
			for node: MapNode in map.nodes:
				if node.forced or not FREQUENCY_ROWS.has(node.row):
					continue
				counts[node.type] = counts.get(node.type, 0) + 1
				total += 1
		var line: String = "act %d (%d nodes):" % [act, total]
		for i: int in MapGen.WEIGHT_TYPES.size():
			var node_type: MapNode.Type = MapGen.WEIGHT_TYPES[i]
			var weight: float = MapGen.WEIGHTS[act][i]
			var share: float = 100.0 * counts.get(node_type, 0) / maxi(total, 1)
			line += " %s %.1f (w %d)" % [MapNode.type_name(node_type), share, weight]
			test.assert_almost_eq(
				share, weight, TOLERANCE_POINTS, "act %d %s" % [act, MapNode.type_name(node_type)]
			)
		table += line + "\n"
	return table
