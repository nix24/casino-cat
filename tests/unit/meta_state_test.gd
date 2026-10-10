extends TestCase
## MetaState: defaults, unlock and history rules, and the arch §6 meta.json example.

## arch §6 meta.json v1 example with the "…" placeholders replaced by concrete valid JSON. The
## placeholders in the doc are not JSON, so this copy is the test's own (T005 R7 note).
const ARCH_META_JSON: String = """
{"version":1,"unlocked_signatures":["dumpster_dive"],
"seen":{"moves":[],"relics":[],"items":[],"enemies":[]},"used":{},"beaten_enemies":[],
"gamble_outcomes":{"dice":{"cold":3,"fair":5}},
"history":[{"seed":"KITTY-7731","result":"lost","act":2,"row":9,"build":["scratch","swipe"],
"relics":["loaded_die"],"duration_s":1900,"date":"2026-10-07"}]}
"""


func test_new_defaults() -> void:
	var meta := MetaState.new()
	assert_eq(meta.version, 1)
	assert_true(meta.unlocked_signatures.is_empty())
	assert_true(meta.history.is_empty())
	assert_eq(MetaState.HISTORY_LIMIT, 20)


func test_round_trip_through_json_text() -> void:
	var meta := MetaState.new()
	assert_true(meta.unlock_signature(&"dumpster_dive"))
	meta.seen_moves.append(&"scratch")
	meta.used[&"scratch"] = 2
	meta.gamble_outcomes[&"dice"] = {&"fair": 5}
	meta.append_history({"seed": "KITTY-7731", "result": "won"})
	var back := MetaState.from_dict(_parse_object(JSON.stringify(meta.to_dict())))
	assert_true(back != null, "from_dict rejected meta.json text")
	if back == null:
		return
	assert_eq(back.to_dict(), meta.to_dict())


func test_arch_example_parses() -> void:
	var meta := MetaState.from_dict(_parse_object(ARCH_META_JSON))
	assert_true(meta != null, "from_dict rejected the arch §6 example")
	if meta == null:
		return
	assert_eq(meta.unlocked_signatures, [&"dumpster_dive"])
	assert_eq(meta.gamble_outcomes[&"dice"][&"fair"], 5)
	assert_eq(meta.history.size(), 1)


func test_history_capped_at_20() -> void:
	var meta := MetaState.new()
	for i: int in 25:
		meta.append_history({"seed": "S%d" % i})
	assert_eq(meta.history.size(), 20)
	assert_eq(meta.history[0]["seed"], "S5")
	assert_eq(meta.history[19]["seed"], "S24")


func test_unlock_signature_once() -> void:
	var meta := MetaState.new()
	assert_true(meta.unlock_signature(&"dumpster_dive"))
	assert_true(not meta.unlock_signature(&"dumpster_dive"))
	assert_eq(meta.unlocked_signatures.size(), 1)


func test_missing_key_returns_null() -> void:
	var data := _parse_object(ARCH_META_JSON)
	data.erase("used")
	assert_true(MetaState.from_dict(data) == null)


func _parse_object(text: String) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "test JSON text must parse")
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var object: Dictionary = parsed
	return object
