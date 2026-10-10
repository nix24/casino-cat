extends TestCase
## Game: starting a run writes run.json, a fresh seed is generated when none is typed, and
## continue_run restores a saved run or refuses one it cannot use (T006). Files go under
## user://test_game/ only, and each test clears them first and last.

const GAME_SCRIPT = preload("res://src/run/game.gd")
const TEST_DIR: String = "user://test_game/"
const RUN_FILE: String = "run.json"


func test_new_run_writes_run_json() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	assert_eq(game.run.run_seed, "KITTY-7731")
	var saved: Dictionary = game.save_store.read_json(RUN_FILE)
	assert_eq(saved.get("seed"), "KITTY-7731")
	_root().remove_child(game)
	game.free()
	_clear_files()


func test_new_run_generates_seed_when_empty() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("")
	var pattern := RegEx.create_from_string("^[A-Z]+-\\d{4}$")
	var seed_text: String = game.run.run_seed
	assert_true(pattern.search(seed_text) != null, "generated seed: %s" % seed_text)
	_root().remove_child(game)
	game.free()
	_clear_files()


func test_continue_run_restores_seed_and_hp() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	game.run.hp = 41
	game.save_now()
	game.run = null
	assert_true(game.continue_run())
	assert_eq(game.run.run_seed, "KITTY-7731")
	assert_eq(game.run.hp, 41)
	_root().remove_child(game)
	game.free()
	_clear_files()


func test_continue_run_false_when_unreadable() -> void:
	_clear_files()
	_write_raw(RUN_FILE, '{"oops')
	_write_raw(RUN_FILE + ".bak", '{"oops')
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	assert_true(not game.continue_run())
	assert_true(game.run == null, "no run is loaded from unreadable files")
	_root().remove_child(game)
	game.free()
	_clear_files()


func test_continue_run_false_for_ended_run() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	game.run.node_state = RunState.NodeState.DEFEAT
	game.save_now()
	game.run = null
	assert_true(not game.continue_run())
	_root().remove_child(game)
	game.free()
	_clear_files()


func test_continue_run_false_for_unknown_move() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	game.run.equipped[0].move_id = &"no_such_move"
	game.save_now()
	game.run = null
	assert_true(not game.continue_run())
	_root().remove_child(game)
	game.free()
	_clear_files()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _clear_files() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := TEST_DIR.path_join(RUN_FILE + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write_raw(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()
