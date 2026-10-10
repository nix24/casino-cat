extends TestCase
## BattleContext.from_run: a battle gets its own copy of the loadout and Due, so the battle can
## change them without touching the run until it ends (T006).


func test_from_run_copies_loadout_and_due() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("KITTY-7731", db.tuning())
	run.due[&"dice"] = 2

	var ctx := BattleContext.from_run(run, db)
	assert_eq(ctx.loadout.size(), run.equipped.size(), "one loadout entry per equipped move")
	assert_eq(ctx.loadout[0].move_id, run.equipped[0].move_id, "slot 0 move id")
	assert_true(ctx.loadout[0] != run.equipped[0], "loadout entries are copies")
	assert_true(ctx.moves.has(run.equipped[0].move_id), "move content is loaded for slot 0")
	assert_eq(ctx.due, run.due, "due is copied")

	ctx.due[&"dice"] = 5
	assert_eq(run.due[&"dice"], 2, "battle changes to due do not reach the run")
