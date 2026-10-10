extends TestCase
## SaveStore: atomic writes, .bak fallback, save codes, CRC-32, and the plain-data check. Files go
## under user://test_saves/ only, and each test clears its own file names first (T005 R10).

const TEST_DIR: String = "user://test_saves/"


func test_atomic_write_keeps_bak() -> void:
	var file_name := "atomic.json"
	_clear_files(file_name)
	var store := _store()
	# Worked example: hp 60, then hp 41. Steps 4-5 move the hp 60 file to .bak.
	assert_eq(store.write_json(file_name, {"version": 1, "hp": 60}), SaveStore.Result.OK)
	assert_eq(store.write_json(file_name, {"version": 1, "hp": 41}), SaveStore.Result.OK)
	var bak_path := TEST_DIR.path_join(file_name) + ".bak"
	assert_true(FileAccess.file_exists(bak_path), "second write should keep the old file as .bak")
	var previous := _parse_object(FileAccess.get_file_as_string(bak_path))
	assert_eq(previous["hp"], 60.0)
	assert_eq(store.read_json(file_name)["hp"], 41.0)
	assert_true(not FileAccess.file_exists(TEST_DIR.path_join(file_name) + ".tmp"))


func test_read_falls_back_to_bak_when_main_is_corrupt() -> void:
	var file_name := "fallback.json"
	_clear_files(file_name)
	var store := _store()
	store.write_json(file_name, {"version": 1, "hp": 60})
	store.write_json(file_name, {"version": 1, "hp": 41})
	_write_raw(file_name, '{"oops')
	var back := store.read_json(file_name)
	assert_eq(back.get("hp"), 60.0)
	assert_eq(store.last_result, SaveStore.Result.OK)


func test_both_unreadable_returns_unreadable() -> void:
	var file_name := "unreadable.json"
	_clear_files(file_name)
	_write_raw(file_name, "{not json")
	_write_raw(file_name + ".bak", "{not json")
	var store := _store()
	assert_true(store.read_json(file_name).is_empty())
	assert_eq(store.last_result, SaveStore.Result.UNREADABLE)


func test_missing_returns_missing() -> void:
	var file_name := "missing.json"
	_clear_files(file_name)
	var store := _store()
	assert_true(store.read_json(file_name).is_empty())
	assert_eq(store.last_result, SaveStore.Result.MISSING)


func test_too_new_file_is_reported_and_kept() -> void:
	var file_name := "too_new.json"
	_clear_files(file_name)
	_write_raw(file_name, JSON.stringify({"version": 2, "a": 1}))
	var store := _store()
	assert_eq(store.write_json(file_name, {"version": 1, "a": 9}), SaveStore.Result.TOO_NEW)
	var kept := _parse_object(FileAccess.get_file_as_string(TEST_DIR.path_join(file_name)))
	assert_eq(kept["version"], 2, "the newer file must not be overwritten")
	assert_true(store.read_json(file_name).is_empty())
	assert_eq(store.last_result, SaveStore.Result.TOO_NEW)


func test_write_rejects_non_plain_data() -> void:
	var file_name := "non_plain.json"
	_clear_files(file_name)
	var store := _store()
	store.write_json(file_name, {"version": 1, "hp": 60})
	var non_plain := {"version": 1, "pos": Vector2i(1, 2)}
	assert_eq(store.write_json(file_name, non_plain), SaveStore.Result.WRITE_FAILED)
	assert_eq(store.read_json(file_name).get("hp"), 60.0, "the old file is untouched")
	assert_true(not FileAccess.file_exists(TEST_DIR.path_join(file_name) + ".tmp"))


func test_save_code_round_trip() -> void:
	var run := RunState.start("KITTY-7731", TuningData.new())
	run.hp = 41
	var code := SaveStore.encode_save_code(run.to_dict())
	var back := RunState.from_dict(SaveStore.decode_save_code(code))
	assert_true(back != null, "decoded code should load as a run")
	if back == null:
		return
	assert_eq(back.hp, 41)
	assert_eq(
		back.equipped.map(func(m: MoveInstance) -> StringName: return m.move_id),
		RunState.STARTER_MOVES
	)
	assert_eq(back.rng_states, run.rng_states)


func test_save_code_format() -> void:
	var code := SaveStore.encode_save_code({"version": 1})
	assert_true(code.begins_with("CC1:"))
	var separator := code.rfind(":")
	var body := code.substr(4, separator - 4)
	var crc_text := code.substr(separator + 1)
	assert_eq(body, Marshalls.utf8_to_base64(JSON.stringify({"version": 1})))
	assert_eq(crc_text.length(), 8)
	assert_eq(crc_text, "%08x" % SaveStore.crc32(body.to_utf8_buffer()))


func test_save_code_detects_tamper() -> void:
	var code := SaveStore.encode_save_code({"version": 1, "hp": 41})
	var replacement := "A" if code[4] != "A" else "B"
	var tampered := code.substr(0, 4) + replacement + code.substr(5)
	assert_true(SaveStore.decode_save_code(tampered).is_empty())


func test_save_code_bad_prefix() -> void:
	var code := SaveStore.encode_save_code({"version": 1})
	assert_true(SaveStore.decode_save_code("XX1:" + code.trim_prefix("CC1:")).is_empty())


func test_crc32_check_value() -> void:
	assert_eq(SaveStore.crc32("123456789".to_utf8_buffer()), 0xCBF43926)


func test_is_plain() -> void:
	assert_true(SaveStore.is_plain({"a": [1, 2.5, "x", null, true]}))
	assert_true(not SaveStore.is_plain(Vector2i.ZERO))
	assert_true(not SaveStore.is_plain(INF))
	assert_true(not SaveStore.is_plain(&"sharpened"))
	assert_true(not SaveStore.is_plain({1: "x"}))
	assert_true(not SaveStore.is_plain({"a": [Vector2i.ZERO]}))
	assert_true(not SaveStore.is_plain(RefCounted.new()))


func _store() -> SaveStore:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var store := SaveStore.new()
	store.base_dir = TEST_DIR
	return store


func _clear_files(file_name: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := TEST_DIR.path_join(file_name + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write_raw(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _parse_object(text: String) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "test JSON text must parse")
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var object: Dictionary = parsed
	return object
