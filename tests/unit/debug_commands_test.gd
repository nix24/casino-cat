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
