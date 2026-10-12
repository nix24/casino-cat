extends TestCase
## MapGen validation, crossing math, and the map save shape (T009, PRD §3.1, D31). The fallback
## template is the hand-built valid map; each test breaks one rule on a copy of it.


func test_edges_cross_worked_example() -> void:
	assert_true(MapGen.edges_cross(2, 3, 3, 2), "3→2 then 2→3 cross")
	assert_true(not MapGen.edges_cross(2, 1, 3, 2), "3→2 then 2→1 don't cross")
	assert_true(not MapGen.edges_cross(3, 3, 3, 2), "a shared start never crosses")


func test_validate_accepts_fixed_rows_only_example() -> void:
	var map: MapData = MapGen.fallback(1)
	assert_eq(MapGen.validate(map), PackedStringArray(), "fallback template")
	map.node_at(8, 3).type = MapNode.Type.BATTLE
	_assert_problem(map, "row 8 must be treasure")


func test_validate_rejects_crossing_edges() -> void:
	var map: MapData = MapGen.fallback(1)
	map.node_at(3, 1).next.append(Vector2i(4, 3))
	map.node_at(3, 3).next.append(Vector2i(4, 1))
	_assert_problem(map, "cross")


func test_validate_rejects_elite_before_row5() -> void:
	var map: MapData = MapGen.fallback(1)
	map.node_at(4, 5).type = MapNode.Type.ELITE
	_assert_problem(map, "row 4 col 5: elite before row 5")


func test_validate_rejects_two_shops_in_a_row() -> void:
	var map: MapData = MapGen.fallback(1)
	map.node_at(5, 1).type = MapNode.Type.SHOP
	_assert_problem(map, "row 5 col 1: two shop nodes in a row")


func test_validate_rejects_missing_rest_on_one_path() -> void:
	var map: MapData = MapGen.fallback(1)
	map.node_at(10, 3).type = MapNode.Type.BATTLE
	_assert_problem(map, "path through col 3 has no REST before row 14")
	assert_eq(MapGen.validate(map).size(), 1, "only lane 3 lacks a rest")


func test_validate_rejects_one_elite() -> void:
	var map: MapData = MapGen.fallback(1)
	for node: MapNode in map.nodes:
		if node.type == MapNode.Type.ELITE and node.cell() != Vector2i(7, 1):
			node.type = MapNode.Type.BATTLE
	_assert_problem(map, "map has 1 elites, needs 2")


func test_validate_rejects_rest_on_row_13() -> void:
	var map: MapData = MapGen.fallback(1)
	map.node_at(13, 1).type = MapNode.Type.REST
	_assert_problem(map, "row 13 col 1: rest on row 13")


func test_node_type_names_round_trip() -> void:
	var map: MapData = MapGen.fallback(2)
	map.node_at(7, 1).payload["elite_id"] = "twin_dealers"
	var plain: Dictionary = map.to_dict()
	var elite_entry: Dictionary = {}
	for entry: Dictionary in plain["nodes"]:
		if entry["row"] == 7 and entry["col"] == 1:
			elite_entry = entry
	assert_eq(elite_entry.get("type"), "elite", "save name")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(plain))
	var back: MapData = MapData.from_dict(parsed)
	assert_true(back != null, "parses its own JSON")
	if back == null:
		return
	assert_eq(back.to_dict(), map.to_dict(), "round trip")
	assert_eq(back.node_at(7, 1).type, MapNode.Type.ELITE, "type back")
	assert_eq(back.node_at(7, 1).payload, {"elite_id": "twin_dealers"}, "payload back")


func test_from_dict_without_payload_reads() -> void:
	var plain: Dictionary = {
		"act": 1, "nodes": [{"row": 1, "col": 0, "type": "battle", "next": [[2, 0], [2, 1]]}]
	}
	var map: MapData = MapData.from_dict(plain)
	assert_true(map != null and map.node_at(1, 0).next == [Vector2i(2, 0), Vector2i(2, 1)])


func test_from_dict_bad_shape_returns_null() -> void:
	assert_eq(MapData.from_dict({"act": 1}), null, "no nodes")
	assert_eq(MapData.from_dict({"act": 1, "nodes": [{"row": 1}]}), null, "node without keys")
	var unknown := {"act": 1, "nodes": [{"row": 1, "col": 0, "type": "casino", "next": []}]}
	assert_eq(MapData.from_dict(unknown), null, "unknown type")
	var bad_edge := {"act": 1, "nodes": [{"row": 1, "col": 0, "type": "battle", "next": [[2]]}]}
	assert_eq(MapData.from_dict(bad_edge), null, "edge not a pair")


func test_generate_is_valid_and_has_payloads() -> void:
	var tuning := TuningData.new()
	for act: int in [1, 2, 3]:
		var map: MapData = MapGen.generate(act, tuning, SeededRng.new("KITTY-7731"))
		assert_eq(MapGen.validate(map), PackedStringArray(), "act %d" % act)
		for node: MapNode in map.nodes:
			var elite_id: String = node.payload.get("elite_id", "")
			match node.type:
				MapNode.Type.ELITE:
					assert_true(
						MapGen.ELITE_IDS[act].has(StringName(elite_id)), "elite id act %d" % act
					)
				MapNode.Type.TREASURE:
					assert_true(MapGen.RARITIES.has(node.payload.get("treasure_rarity", "")))
				MapNode.Type.SHOP:
					assert_true(MapGen.RARITIES.has(node.payload.get("shop_relic_rarity", "")))


func test_run_state_saves_the_map() -> void:
	var tuning := TuningData.new()
	var run: RunState = RunState.start("KITTY-7731", tuning)
	assert_eq(run.to_dict()["map"], {}, "no map yet")
	run.map = MapGen.generate(1, tuning, SeededRng.new("KITTY-7731"))
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	var back: RunState = RunState.from_dict(parsed)
	assert_true(back != null and back.map != null, "loads")
	if back == null or back.map == null:
		return
	assert_eq(back.map.to_dict(), run.map.to_dict(), "map round trip")


func _assert_problem(map: MapData, expected: String) -> void:
	var problems: PackedStringArray = MapGen.validate(map)
	for problem: String in problems:
		if problem.contains(expected):
			return
	assert_true(false, "no problem containing '%s' in %s" % [expected, problems])
