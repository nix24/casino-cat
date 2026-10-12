extends TestCase
## Boss rewards, signature unlocks, and the act transition (T019, PRD §3.2, §10.6, §12.1, D27,
## D30, D51).


func test_signature_granted_on_first_kill_only() -> void:
	var db: ContentDb = ContentDb.load_all()
	var meta := MetaState.new()
	var run: RunState = _boss_run(db)
	var reward: RunRules.BossReward = RunRules.finish_boss(
		run, _won(db, 20), db, meta, SeededRng.new("b")
	)
	assert_eq(reward.signature_id, &"dumpster_dive")
	assert_eq(run.bag[0].move_id, &"dumpster_dive", "equipped full, so the bag (D27)")
	assert_eq(meta.unlocked_signatures, [&"dumpster_dive"])
	var second_run: RunState = _boss_run(db)
	var again: RunRules.BossReward = RunRules.finish_boss(
		second_run, _won(db, 20), db, meta, SeededRng.new("b")
	)
	assert_eq(again.signature_id, &"", "already unlocked: not granted again (PRD §12.1)")
	assert_eq(second_run.bag.size(), 0)
	assert_eq(meta.unlocked_signatures, [&"dumpster_dive"], "written once")


func test_boss_reward_offers_three_unowned_relics_and_70_purrls() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _boss_run(db)
	run.relics = [&"loaded_die"]
	var reward: RunRules.BossReward = RunRules.finish_boss(
		run, _won(db, 20), db, MetaState.new(), SeededRng.new("b")
	)
	assert_eq(reward.purrls, 70)
	assert_eq(reward.relic_offers.size(), 3)
	for relic: RelicData in reward.relic_offers:
		assert_true(relic.id != &"loaded_die", "unowned only")
		assert_eq(reward.relic_offers.count(relic), 1, "distinct")
	assert_eq(run.node_state, RunState.NodeState.BOSS_REWARD)
	var back: RunRules.BossReward = RunRules.BossReward.from_payload(run.node_payload, db)
	assert_true(back != null and back.to_payload() == reward.to_payload(), "survives a reload")


func test_boss_heal_50_percent_capped() -> void:
	var db: ContentDb = ContentDb.load_all()
	var cases: Dictionary[int, int] = {20: 50, 40: 60}
	for start_hp: int in cases:
		var run: RunState = _boss_run(db)
		var reward: RunRules.BossReward = RunRules.finish_boss(
			run, _won(db, start_hp), db, MetaState.new(), SeededRng.new("b")
		)
		RunRules.take_boss_reward(run, reward, -1, db, SeededRng.new("m"))
		assert_eq(run.hp, cases[start_hp], "from %d" % start_hp)


func test_boss_reward_skip_gives_40_purrls() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _boss_run(db)
	var reward: RunRules.BossReward = RunRules.finish_boss(
		run, _won(db, 20), db, MetaState.new(), SeededRng.new("b")
	)
	RunRules.take_boss_reward(run, reward, -1, db, SeededRng.new("m"))
	assert_eq(run.purrls, 50 + 70 + 40)
	assert_eq(run.relics.size(), 0)
	var taken: RunState = _boss_run(db)
	var reward_two: RunRules.BossReward = RunRules.finish_boss(
		taken, _won(db, 20), db, MetaState.new(), SeededRng.new("b")
	)
	RunRules.take_boss_reward(taken, reward_two, 1, db, SeededRng.new("m"))
	assert_eq(taken.purrls, 50 + 70)
	assert_eq(taken.relics, [reward_two.relic_offers[1].id])


func test_start_act_generates_next_map() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _boss_run(db)
	var reward: RunRules.BossReward = RunRules.finish_boss(
		run, _won(db, 20), db, MetaState.new(), SeededRng.new("b")
	)
	RunRules.take_boss_reward(run, reward, -1, db, SeededRng.new("m"))
	assert_eq(run.act, 2)
	assert_eq(run.node_state, RunState.NodeState.MAP)
	assert_eq(run.position, Vector2i.ZERO)
	assert_true(run.map != null and run.map.act == 2, "act 2 map")
	assert_eq(MapGen.validate(run.map), PackedStringArray())


func test_boss_node_enters_big_lou() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _boss_run(db)
	var entry: RunRules.NodeEntry = RunRules.enter_node(
		run, MapNode.new(15, 3, MapNode.Type.BOSS), db, SeededRng.new("e")
	)
	assert_eq(entry.enemy_id, &"big_lou")


func _boss_run(db: ContentDb) -> RunState:
	return RunState.start("BOSS", db.tuning())


func _won(db: ContentDb, cat_hp: int) -> BattleState:
	var state := BattleState.new()
	state.enemy_data = db.enemy(&"big_lou")
	state.enemy.max_hp = 120
	state.cat.max_hp = 60
	state.cat.hp = cat_hp
	state.outcome = BattleState.Outcome.WON
	return state
