extends TestCase
## Game: starting a run writes run.json, a fresh seed is generated when none is typed, and
## continue_run restores a saved run or refuses one it cannot use (T006). Files go under
## user://test_game/ only, and each test clears them first and last.

const GAME_SCRIPT = preload("res://src/run/game.gd")
const TEST_DIR: String = "user://test_game/"
const RUN_FILE: String = "run.json"
const META_FILE: String = "meta.json"


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


func test_abandon_writes_lost_and_deletes_run() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	game.abandon_run()
	var saved_meta: Dictionary = game.save_store.read_json(META_FILE)
	var history: Array = saved_meta["history"]
	var last_entry: Dictionary = history[-1]
	assert_eq(last_entry["result"], "lost")
	assert_true(not FileAccess.file_exists(TEST_DIR.path_join(RUN_FILE)), "run.json is gone")
	assert_true(game.run == null, "no run after abandoning")
	assert_true(not game.continue_run())
	_free_game(game)


func test_save_and_quit_keeps_run_for_continue() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	game.run.hp = 33
	game.save_and_quit()
	assert_true(game.run == null, "the run is cleared on the way to the title")
	assert_true(game.continue_run())
	assert_eq(game.run.run_seed, "KITTY-7731")
	assert_eq(game.run.hp, 33)
	_free_game(game)


func test_import_refused_during_run() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	var code: String = game.save_code()
	assert_eq(game.import_save_code(code), SaveCode.Error.BAD_CODE)
	assert_true(not FileAccess.file_exists(TEST_DIR.path_join(META_FILE)), "nothing was written")
	_free_game(game)


func test_import_writes_both_saves() -> void:
	_clear_files()
	var source := GAME_SCRIPT.new()
	source.save_store.base_dir = TEST_DIR
	_root().add_child(source)
	source._start_run("KITTY-7731")
	var code: String = source.save_code()
	_free_game(source)
	_clear_files()
	var target := GAME_SCRIPT.new()
	target.save_store.base_dir = TEST_DIR
	_root().add_child(target)
	assert_eq(target.import_save_code(code), SaveCode.Error.NONE)
	assert_true(target.continue_run())
	assert_eq(target.run.run_seed, "KITTY-7731")
	_free_game(target)


func test_import_without_run_deletes_the_old_run() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	var meta_only: String = SaveCode.export_code({}, game.meta.to_dict())
	game.run = null
	assert_eq(game.import_save_code(meta_only), SaveCode.Error.NONE)
	assert_true(not game.continue_run(), "a code with no run leaves no run to continue")
	_free_game(game)


func test_import_bad_code_changes_nothing() -> void:
	_clear_files()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	assert_eq(game.import_save_code("CC1:garbage:00000000"), SaveCode.Error.BAD_CODE)
	assert_true(not FileAccess.file_exists(TEST_DIR.path_join(META_FILE)), "nothing was written")
	_free_game(game)


func _free_game(game: Node) -> void:
	_root().remove_child(game)
	game.free()
	_clear_files()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _clear_files() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for file_name: String in [RUN_FILE, META_FILE]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var path := TEST_DIR.path_join(file_name + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _write_raw(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()
