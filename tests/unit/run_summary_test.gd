extends TestCase
## The run's history entry and the end of a run (T020, PRD §12.3, D32).

const GAME_SCRIPT = preload("res://src/run/game.gd")
const TEST_DIR: String = "user://test_summary/"


func test_build_entry_has_four_moves_and_relics() -> void:
	var run: RunState = RunState.start("KITTY-7731", TuningData.new())
	run.act = 2
	run.position = Vector2i(9, 3)
	run.equipped[0].modifier_ids = [&"sharpened"]
	run.relics = [&"loaded_die"]
	run.stats.duration_s = 1900
	var entry: Dictionary = RunSummary.build_entry(run, false, "2026-10-07")
	assert_eq(entry["seed"], "KITTY-7731")
	assert_eq(entry["result"], "lost")
	assert_eq([entry["act"], entry["row"], entry["duration_s"]], [2, 9, 1900])
	var build: Array = entry["build"]
	assert_eq(build.size(), 4)
	assert_eq(build[0], {"move_id": "scratch", "modifier_ids": ["sharpened"]})
	assert_eq(entry["relics"], ["loaded_die"])
	assert_eq(entry["date"], "2026-10-07")


func test_build_entry_result_strings() -> void:
	var run: RunState = RunState.start("X", TuningData.new())
	assert_eq(RunSummary.build_entry(run, true, "d")["result"], "won")
	assert_eq(RunSummary.build_entry(run, false, "d")["result"], "lost")


func test_history_keeps_20_and_drops_oldest() -> void:
	var meta := MetaState.new()
	for index: int in 21:
		meta.append_history({"seed": "S-%d" % index})
	assert_eq(meta.history.size(), 20)
	assert_eq(meta.history[0]["seed"], "S-1")


func test_continue_refused_after_run_end() -> void:
	_clear()
	var game := GAME_SCRIPT.new()
	game.save_store.base_dir = TEST_DIR
	_root().add_child(game)
	game._start_run("KITTY-7731")
	var entry: Dictionary = game.end_run(false)
	assert_eq(entry["result"], "lost")
	assert_true(game.run == null, "the run is over")
	assert_true(not FileAccess.file_exists(TEST_DIR + "run.json"), "run.json deleted (D32)")
	assert_true(not FileAccess.file_exists(TEST_DIR + "run.json.bak"), "and its backup")
	assert_eq(game.meta.history.size(), 1, "history written")
	assert_true(not game.continue_run())
	_root().remove_child(game)
	game.free()
	_clear()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _clear() -> void:
	for file: String in ["run.json", "run.json.bak", "meta.json", "meta.json.bak"]:
		DirAccess.remove_absolute(TEST_DIR + file)
