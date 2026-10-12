extends TestCase
## The rest site (T016, PRD §10.1, D3, D15).

const SLOT_SCRATCH: int = 0
const SLOT_PAW_ROLL: int = 2
const SLOT_CURL_UP: int = 3


func test_nap_heals_30_percent() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	run.hp = 41
	assert_eq(RestRules.nap(run, db.tuning()), 18)
	assert_eq(run.hp, 59)
	run.max_hp = 61
	run.hp = 1
	assert_eq(RestRules.nap(run, db.tuning()), 18, "18.3 → 18")
	run.max_hp = 65
	run.hp = 1
	assert_eq(RestRules.nap(run, db.tuning()), 20, "19.5 rounds half up (D15)")


func test_nap_capped_at_max_hp() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	run.hp = 50
	assert_eq(RestRules.nap(run, db.tuning()), 10)
	assert_eq(run.hp, 60)


func test_practice_attaches_sharpened_to_basic_with_free_slot() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	assert_true(RestRules.practice(run, SLOT_SCRATCH, db))
	assert_eq(run.equipped[SLOT_SCRATCH].modifier_ids, [&"sharpened"])


func test_practice_attaches_cheap_to_gamble() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	assert_true(RestRules.practice(run, SLOT_PAW_ROLL, db))
	assert_eq(run.equipped[SLOT_PAW_ROLL].modifier_ids, [&"cheap"])


func test_practice_rejects_utility_and_duplicates() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	assert_true(not RestRules.practice(run, SLOT_CURL_UP, db), "utility")
	RestRules.practice(run, SLOT_SCRATCH, db)
	assert_true(not RestRules.practice(run, SLOT_SCRATCH, db), "no second Sharpened (D3)")
	assert_eq(RestRules.practice_targets(run, db), [1, SLOT_PAW_ROLL])


func test_practice_targets_empty_when_all_slots_full() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	for instance: MoveInstance in run.equipped:
		instance.modifier_ids = [&"thorny", &"quick_draw"]
	assert_eq(RestRules.practice_targets(run, db), [])


func test_rest_completes_the_node() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	assert_true(not RunRules.rest(run, false, SLOT_CURL_UP, db))
	assert_eq(run.node_state, RunState.NodeState.REST, "a refused Practice keeps the node open")
	assert_true(RunRules.rest(run, true, -1, db))
	assert_eq(run.node_state, RunState.NodeState.MAP)


func test_rearrange_keeps_node_open() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db)
	var bagged := MoveInstance.new()
	bagged.move_id = &"loaded_paws"
	run.bag.append(bagged)
	assert_true(RunRules.swap_equipped_with_bag(run, SLOT_PAW_ROLL, 0))
	assert_eq(run.node_state, RunState.NodeState.REST)


func _run(db: ContentDb) -> RunState:
	var run: RunState = RunState.start("REST", db.tuning())
	run.node_state = RunState.NodeState.REST
	return run
