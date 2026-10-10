extends TestCase
## RunState: start values, the run.json shape, and the arch §6 run.json example.

## arch §6 run.json v1 example, copied as written. Its stats keys match RunStats (T005 R6).
const ARCH_RUN_JSON: String = """
{"version":1,"seed":"KITTY-7731","act":1,"position":[6,3],"hp":41,"max_hp":60,"purrls":132,
"equipped":[{"move_id":"scratch","modifier_ids":["sharpened"]},
{"move_id":"swipe","modifier_ids":[]},{"move_id":"paw_roll","modifier_ids":[]},
{"move_id":"curl_up","modifier_ids":[]}],"bag":[],
"pouch":["fish_snack","",""],"relics":["loaded_die"],"due":{"dice":1},"next_battle_mp_bonus":0,
"rng_states":{"map":123,"battle":456,"gamble":789,"reward":12,"shop":34,"event":56},
"map":{"act":1,"nodes":[{"row":1,"col":0,"type":"battle","next":[[2,0],[2,1]]}]},
"node_state":"MAP","node_payload":{},"action_log":[],
"stats":{"turns":31,"damage_dealt":402,"damage_taken":97,"gambles":{"dice":6},"duration_s":845}}
"""


func test_start_values() -> void:
	var tuning := TuningData.new()
	var run := RunState.start("KITTY-7731", tuning)
	assert_eq(run.run_seed, "KITTY-7731")
	assert_eq(run.hp, tuning.cat_max_hp)
	assert_eq(run.max_hp, 60)
	assert_eq(run.purrls, 50)
	assert_eq(run.position, Vector2i.ZERO)
	assert_eq(run.node_state, RunState.NodeState.MAP)
	assert_eq(run.equipped.size(), 4)
	assert_eq(run.equipped[0].move_id, &"scratch")
	assert_eq(run.pouch.size(), 3)
	assert_eq(run.pouch[0], &"")


func test_start_rng_states_match_rng_set() -> void:
	var run := RunState.start("KITTY-7731", TuningData.new())
	assert_eq(run.rng_states, RngSet.for_seed("KITTY-7731").to_states())


func test_round_trip() -> void:
	var run := RunState.start("KITTY-7731", TuningData.new())
	var data := run.to_dict()
	var back := RunState.from_dict(data)
	assert_true(back != null, "from_dict rejected its own to_dict output")
	if back == null:
		return
	assert_eq(back.to_dict(), data)


func test_round_trip_through_json_text() -> void:
	var run := RunState.start("KITTY-7731", TuningData.new())
	var back := RunState.from_dict(_parse_object(JSON.stringify(run.to_dict())))
	assert_true(back != null, "from_dict rejected run.json text")
	if back == null:
		return
	assert_eq(back.to_dict(), run.to_dict())


func test_arch_example_parses() -> void:
	var run := RunState.from_dict(_parse_object(ARCH_RUN_JSON))
	assert_true(run != null, "from_dict rejected the arch §6 example")
	if run == null:
		return
	assert_eq(run.hp, 41)
	assert_eq(run.position, Vector2i(6, 3))
	assert_eq(run.equipped[0].modifier_ids, [&"sharpened"])
	assert_eq(run.pouch[0], &"fish_snack")
	assert_eq(run.due[&"dice"], 1)
	assert_eq(run.rng_states[&"map"], 123)
	assert_eq(run.node_state, RunState.NodeState.MAP)
	assert_eq(run.stats.turns, 31)


func test_missing_key_returns_null() -> void:
	var data := _parse_object(ARCH_RUN_JSON)
	data.erase("hp")
	assert_true(RunState.from_dict(data) == null)


func test_wrong_type_returns_null() -> void:
	var data := _parse_object(ARCH_RUN_JSON)
	data["hp"] = "lots"
	assert_true(RunState.from_dict(data) == null)


func test_fractional_number_returns_null() -> void:
	var data := _parse_object(ARCH_RUN_JSON)
	data["hp"] = 41.5
	assert_true(RunState.from_dict(data) == null)


func test_unknown_node_state_returns_null() -> void:
	var data := _parse_object(ARCH_RUN_JSON)
	data["node_state"] = "CASINO"
	assert_true(RunState.from_dict(data) == null)


func test_to_dict_is_plain() -> void:
	var run := RunState.start("KITTY-7731", TuningData.new())
	assert_true(SaveStore.is_plain(run.to_dict()))


func test_run_stats_round_trip() -> void:
	var stats := RunStats.new()
	stats.turns = 4
	stats.damage_dealt = 20
	stats.damage_taken = 9
	stats.duration_s = 300
	stats.gambles[&"dice"] = 3
	var back := RunStats.from_dict(stats.to_dict())
	assert_true(back != null, "RunStats.from_dict rejected its own to_dict output")
	if back == null:
		return
	assert_eq(back.gambles[&"dice"], 3)
	assert_eq(back.to_dict(), stats.to_dict())


func _parse_object(text: String) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "test JSON text must parse")
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var object: Dictionary = parsed
	return object
