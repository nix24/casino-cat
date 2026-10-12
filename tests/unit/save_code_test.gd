extends TestCase
## SaveCode: the bundle of run.json and meta.json as one save code (T047, PRD §17.4, D55).


func test_round_trip_run_and_meta() -> void:
	var run_dict := {"version": 1, "seed": "KITTY-7731", "hp": 41}
	var meta_dict := {"version": 1, "unlocked_signatures": ["pounce"]}
	var imported := SaveCode.import_code(SaveCode.export_code(run_dict, meta_dict))
	assert_eq(imported.error, SaveCode.Error.NONE)
	assert_eq(imported.run["seed"], "KITTY-7731")
	assert_eq(imported.run["hp"], 41.0)
	assert_eq(imported.meta["unlocked_signatures"], ["pounce"])


func test_round_trip_meta_only_gives_empty_run() -> void:
	var imported := SaveCode.import_code(SaveCode.export_code({}, {"version": 1}))
	assert_eq(imported.error, SaveCode.Error.NONE)
	assert_true(imported.run.is_empty(), "no run in the code means an empty run")
	assert_eq(imported.meta["version"], 1.0)


func test_surrounding_whitespace_is_ignored() -> void:
	var code := SaveCode.export_code({}, {"version": 1})
	assert_eq(SaveCode.import_code("  %s\n" % code).error, SaveCode.Error.NONE)


func test_bad_crc_is_bad_code() -> void:
	var code := SaveCode.export_code({"version": 1}, {"version": 1})
	var flipped := "A" if code[6] != "A" else "B"
	var tampered := code.substr(0, 6) + flipped + code.substr(7)
	assert_eq(SaveCode.import_code(tampered).error, SaveCode.Error.BAD_CODE)


func test_garbage_is_bad_code() -> void:
	assert_eq(SaveCode.import_code("not a save code").error, SaveCode.Error.BAD_CODE)
	assert_eq(SaveCode.import_code("").error, SaveCode.Error.BAD_CODE)


func test_missing_meta_is_bad_code() -> void:
	var code := SaveStore.encode_save_code({"run": null})
	assert_eq(SaveCode.import_code(code).error, SaveCode.Error.BAD_CODE)


func test_run_of_wrong_type_is_bad_code() -> void:
	var code := SaveStore.encode_save_code({"run": "oops", "meta": {"version": 1}})
	assert_eq(SaveCode.import_code(code).error, SaveCode.Error.BAD_CODE)


func test_part_without_version_is_bad_code() -> void:
	var code := SaveStore.encode_save_code({"run": null, "meta": {"hp": 1}})
	assert_eq(SaveCode.import_code(code).error, SaveCode.Error.BAD_CODE)


func test_newer_version_is_too_new() -> void:
	var newer: int = SaveMigrations.CURRENT_VERSION + 1
	var in_meta := SaveCode.export_code({}, {"version": newer})
	assert_eq(SaveCode.import_code(in_meta).error, SaveCode.Error.TOO_NEW)
	var in_run := SaveCode.export_code({"version": newer}, {"version": 1})
	assert_eq(SaveCode.import_code(in_run).error, SaveCode.Error.TOO_NEW)
