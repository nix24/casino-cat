extends SceneTree
## Headless test runner. Exit code = number of failed tests (0 = all passed).
##
## Usage: godot --headless --path . --script res://tests/run_tests.gd [-- --filter=<text>]
## Finds every `*_test.gd` under tests/unit and tests/sim, runs each `test_*` method on a fresh
## instance, and prints one line per failure.

const TEST_DIRS: PackedStringArray = ["res://tests/unit", "res://tests/sim"]


func _init() -> void:
	var filter: String = _read_filter()
	var passed: int = 0
	var failed: int = 0
	for path: String in _find_test_files():
		var script: GDScript = load(path)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if (
				not name.begins_with("test_")
				or (filter != "" and not (path + name).contains(filter))
			):
				continue
			var test_case: TestCase = script.new()
			test_case.begin(name)
			test_case.call(name)
			if test_case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for line: String in test_case.failures:
					printerr("FAIL %s %s" % [path.get_file(), line])
	print("%d passed, %d failed" % [passed, failed])
	quit(failed)


func _find_test_files() -> Array[String]:
	var found: Array[String] = []
	for dir_path: String in TEST_DIRS:
		for file: String in DirAccess.get_files_at(dir_path):
			if file.ends_with("_test.gd"):
				found.append(dir_path.path_join(file))
	return found


func _read_filter() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""
