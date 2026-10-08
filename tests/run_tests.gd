extends SceneTree
## Headless test runner. Exit code = number of failed tests (0 = all passed).
##
## Usage: godot --headless --path . --script res://tests/run_tests.gd [-- --filter=<text>]
## Finds every `*_test.gd` under tests/unit and tests/sim, runs each `test_*` method on a fresh
## instance, and prints one line per failure.
## Tests run on the first process frame, not in _init, so scene tests can add nodes to `root` and
## get `_ready` (T003).
## A script or engine error during a test fails it. Without this, a test that aborts on an error
## records no failure and counts as passed.

const TEST_DIRS: PackedStringArray = ["res://tests/unit", "res://tests/sim"]

var _error_log := ErrorLog.new()


func _init() -> void:
	OS.add_logger(_error_log)


func _process(_delta: float) -> bool:
	_run_all()
	return true


func _run_all() -> void:
	var filter: String = _read_filter()
	var passed: int = 0
	var failed: int = 0
	for path: String in _find_test_files():
		_error_log.take()
		var script: GDScript = load(path)
		# A parse error still returns a script object, just one with no test methods.
		var load_errors: PackedStringArray = _error_log.take()
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			failed += 1
			printerr("FAIL %s does not load: %s" % [path.get_file(), " | ".join(load_errors)])
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if (
				not name.begins_with("test_")
				or (filter != "" and not (path + name).contains(filter))
			):
				continue
			var test_case: TestCase = script.new()
			test_case.begin(name)
			_error_log.take()
			test_case.call(name)
			for error: String in _error_log.take():
				test_case.failures.append("%s: engine error: %s" % [name, error])
			if test_case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for line: String in test_case.failures:
					printerr("FAIL %s %s" % [path.get_file(), line])
	print("%d passed, %d failed" % [passed, failed])
	OS.remove_logger(_error_log)
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


## Collects every error and script error the engine reports. Warnings are ignored: rules code
## warns on purpose (for example a rejected action). Errors can arrive from any thread.
class ErrorLog:
	extends Logger

	var _errors: PackedStringArray = PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = rationale if rationale != "" else code
		_mutex.lock()
		_errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
		_mutex.unlock()

	## Returns the errors logged since the last call and clears them.
	func take() -> PackedStringArray:
		_mutex.lock()
		var taken: PackedStringArray = _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return taken
