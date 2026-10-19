extends TestCase
## The dev console's parser and value helpers (T007 R8, decisions D36). Pure, so no scene is needed.


func test_parse_splits_args() -> void:
	var parsed: Dictionary = DebugCommands.parse("give move scratch")
	var is_ok: bool = parsed["ok"]
	assert_true(is_ok, "known command parses")
	assert_eq(parsed["name"], "give", "command name")
	assert_eq(parsed["args"], PackedStringArray(["move", "scratch"]), "args")


func test_unknown_command_error() -> void:
	var parsed: Dictionary = DebugCommands.parse("fly")
	var is_ok: bool = parsed["ok"]
	assert_true(not is_ok, "unknown command fails")
	assert_eq(parsed["error"], "unknown command: fly", "error text")


func test_empty_line_error() -> void:
	var parsed: Dictionary = DebugCommands.parse("   ")
	var is_ok: bool = parsed["ok"]
	assert_true(not is_ok, "blank line fails")
	assert_eq(parsed["error"], "empty command", "error text")


func test_table_has_every_18_1_command() -> void:
	var required: PackedStringArray = [
		"seed",
		"give",
		"purrls",
		"hp",
		"mp",
		"force",
		"goto",
		"node",
		"enemy",
		"god",
		"log",
		"replay",
	]
	for command_name: String in required:
		var parsed: Dictionary = DebugCommands.parse(command_name)
		var is_ok: bool = parsed["ok"]
		assert_true(is_ok, "%s is a known command" % command_name)


func test_clamp_hp() -> void:
	assert_eq(DebugCommands.clamp_hp(999, 60), 60, "above max clamps to max")
	assert_eq(DebugCommands.clamp_hp(0, 60), 1, "zero clamps to 1")


func test_parse_dice_faces() -> void:
	assert_eq(DebugCommands.parse_dice_faces("3,4"), [3, 4], "valid faces")
	assert_eq(DebugCommands.parse_dice_faces("7,1"), [], "face above 6")
	assert_eq(DebugCommands.parse_dice_faces("a"), [], "not a number")
	assert_eq(DebugCommands.parse_dice_faces(""), [], "empty text")


func test_sandbox_is_a_command() -> void:
	var parsed: Dictionary = DebugCommands.parse("sandbox fight sewer_rat")
	var is_ok: bool = parsed["ok"]
	assert_true(is_ok, "sandbox is a known command")


func test_sandbox_equips_named_moves() -> void:
	var setup := DebugCommands.parse_sandbox(["curl_up,curl_up,scratch,high_card"], _db())
	assert_eq(setup.error, "", "valid loadout")
	assert_eq(setup.run.equipped.size(), 4, "four moves equipped")
	assert_eq(setup.run.equipped[1].move_id, &"curl_up", "duplicates allowed")
	assert_eq(setup.run.run_seed, DebugCommands.SANDBOX_SEED, "default seed")
	assert_eq(setup.mp, -1, "normal MP start")


func test_sandbox_unknown_ids_fail() -> void:
	var db := _db()
	var cases: Dictionary[String, PackedStringArray] = {
		"unknown move: zap": ["scratch,zap"],
		"unknown mod: zap": ["scratch", "mods", "scratch:zap"],
		"unknown relic: zap": ["scratch", "relics", "zap"],
		"unknown sandbox option: zap": ["scratch", "zap", "1"],
		"no such move in the sandbox loadout: swipe": ["scratch", "mods", "swipe:thorny"],
		"sandbox moves: name 1 to 4 moves": ["scratch,swipe,curl_up,high_card,scratch"],
	}
	for expected: String in cases:
		assert_eq(DebugCommands.parse_sandbox(cases[expected], db).error, expected, expected)


func test_sandbox_mods_by_move_or_slot() -> void:
	var db := _db()
	var by_move := DebugCommands.parse_sandbox(["curl_up,scratch", "mods", "curl_up:thorny"], db)
	assert_eq(by_move.run.equipped[0].modifier_ids, [&"thorny"] as Array[StringName], "move id")
	var by_slot := DebugCommands.parse_sandbox(["curl_up,scratch", "mods", "2:thorny"], db)
	assert_eq(by_slot.run.equipped[1].modifier_ids, [&"thorny"] as Array[StringName], "slot 2")
	assert_true(by_slot.run.equipped[0].modifier_ids.is_empty(), "slot 1 untouched")


func test_sandbox_numbers_and_relics() -> void:
	var db := _db()
	var setup := DebugCommands.parse_sandbox(
		["scratch", "hp", "999", "mp", "500", "relics", "pit_boss"], db
	)
	assert_eq(setup.error, "", "valid options")
	assert_eq(setup.run.hp, setup.run.max_hp, "hp clamps to max")
	assert_eq(setup.mp, db.tuning().mp_max, "mp clamps to max")
	assert_eq(setup.run.relics, [&"pit_boss"] as Array[StringName], "relic added")
	var bad := DebugCommands.parse_sandbox(["scratch", "hp", "x"], db)
	assert_eq(bad.error, "sandbox hp: not a number: x", "non-number")
	var missing := DebugCommands.parse_sandbox(["scratch", "mp"], db)
	assert_eq(missing.error, "sandbox mp: missing value", "missing value")


func test_sandbox_lists() -> void:
	var db := _db()
	assert_true(DebugCommands.sandbox_ids("enemies", db).has("sewer_rat"), "enemies listed")
	assert_true(DebugCommands.sandbox_ids("bogus", db).is_empty(), "unknown kind is empty")


func _db() -> ContentDb:
	return ContentDb.load_all()
