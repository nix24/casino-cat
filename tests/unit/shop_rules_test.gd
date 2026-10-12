extends TestCase
## Shop stock, prices, rerolls, fairness, and the heal service (T015, PRD §10.2, D30, D31, D34).


func test_stock_composition_3_2_1_2() -> void:
	var db: ContentDb = ContentDb.load_all()
	var stock: Dictionary = _generate(db, "SHOP-1", 500)
	var kinds: Array[String] = _kinds(stock)
	# M2 content has two non-starter moves, both gambles, so slots 1-2 stay empty (D30).
	assert_eq(kinds.count(ShopRules.KIND_MOVE), 1)
	var first_id: String = _entries(stock)[0]["id"]
	assert_eq(db.move(StringName(first_id)).category, MoveData.Category.GAMBLE)
	assert_eq(kinds.count(ShopRules.KIND_RELIC), 1)
	assert_eq(kinds.count(ShopRules.KIND_MODIFIER), 2)
	assert_eq(kinds.count(ShopRules.KIND_ITEM), 2)


func test_no_duplicate_moves_or_items_in_stock() -> void:
	var db: ContentDb = ContentDb.load_all()
	for i: int in 200:
		var ids: Array[String] = []
		for entry: Dictionary in _entries(_generate(db, "SHOP-%d" % i, 500)):
			ids.append("%s:%s" % [entry["kind"], entry["id"]])
		for id: String in ids:
			assert_eq(ids.count(id), 1, "seed %d %s" % [i, id])


func test_relic_rarity_from_the_map_and_fallback() -> void:
	var db: ContentDb = ContentDb.load_all()
	var rng := SeededRng.new("RELIC")
	var rare: RelicData = ShopRules.pick_relic(db.all_relics(), [], "rare", rng)
	assert_eq(rare.id, &"maneki_paw", "the one rare relic")
	var fallback: RelicData = ShopRules.pick_relic(db.all_relics(), [&"maneki_paw"], "rare", rng)
	assert_eq(fallback.rarity, RelicData.Rarity.COMMON, "no uncommon yet, rare owned: down")
	var none: RelicData = ShopRules.pick_relic([], [], "common", rng)
	assert_eq(none, null)


func test_act1_prices() -> void:
	assert_eq(ShopRules.price(45, 1.0), 45)
	assert_eq(ShopRules.price(65, 1.0), 65)
	assert_eq(ShopRules.price(30, 1.0), 30)


func test_act2_scale_prices() -> void:
	assert_eq(ShopRules.price(45, 1.15), 50)
	assert_eq(ShopRules.price(65, 1.15), 75)
	assert_eq(ShopRules.price(120, 1.15), 140)
	assert_eq(ShopRules.price(55, 1.15), 65)


func test_act3_round_half_up() -> void:
	assert_eq(ShopRules.price(45, 1.3), 60)
	assert_eq(ShopRules.price(55, 1.3), 70)
	assert_eq(ShopRules.price(65, 1.3), 85)
	assert_eq(ShopRules.price(160, 1.3), 210)


func test_reroll_cost_steps_15_25_35() -> void:
	var tuning := TuningData.new()
	assert_eq(
		[0, 1, 2].map(func(done: int) -> int: return ShopRules.reroll_cost(done, tuning)),
		[15, 25, 35]
	)
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("SHOP", db.tuning())
	run.purrls = 40
	var stock: Dictionary = ShopRules.generate(1, run, db, "common", [], SeededRng.new("s"))
	var rng := SeededRng.new("reroll")
	var second: Dictionary = RunRules.reroll_shop(run, stock, db, "common", [], rng)
	assert_eq(run.purrls, 25)
	assert_eq(second["rerolls"], 1)
	var third: Dictionary = RunRules.reroll_shop(run, second, db, "common", [], rng)
	assert_eq(run.purrls, 0)
	assert_eq(RunRules.reroll_shop(run, third, db, "common", [], rng), {}, "35 is too much")


func test_fairness_adds_spare_die_at_25_purrls() -> void:
	var db: ContentDb = ContentDb.load_all()
	var stock: Dictionary = {
		"entries":
		[
			_raw("move", "loaded_paws", 65),
			_raw("relic", "thick_fur", 120),
			_raw("modifier", "sharpened", 55),
			_raw("modifier", "thorny", 55),
			_raw("item", "fish_snack", 30),
			_raw("item", "catnip_tea", 35),
		],
		"rerolls": 0,
	}
	var fair: Dictionary = ShopRules.ensure_affordable(stock, 25, db, 1)
	var last: Dictionary = _entries(fair)[-1]
	assert_eq(last["id"], "spare_die")
	assert_eq(last["price"], 20)
	assert_eq(ShopRules.price(20, 1.15), 25, "still ≤ 25 in act 2")
	assert_eq(ShopRules.price(20, 1.3), 25, "and act 3")


func test_fairness_skipped_below_25_purrls() -> void:
	var db: ContentDb = ContentDb.load_all()
	var stock: Dictionary = {"entries": [_raw("item", "fish_snack", 30)], "rerolls": 0}
	var before: Dictionary = stock.duplicate(true)
	assert_eq(ShopRules.ensure_affordable(stock, 24, db, 1), before)


func test_heal_service_18_for_60_max() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("SHOP", db.tuning())
	run.hp = 30
	assert_true(RunRules.heal_service(run, db.tuning()))
	assert_eq(run.hp, 48)
	assert_eq(run.purrls, 10)
	run.purrls = 100
	run.hp = 50
	assert_true(RunRules.heal_service(run, db.tuning()))
	assert_eq(run.hp, 60, "capped")
	assert_true(not RunRules.heal_service(run, db.tuning()), "full HP")


func test_buy_rules() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("SHOP", db.tuning())
	run.purrls = 1000
	var stock: Dictionary = {
		"entries":
		[
			_raw("move", "loaded_paws", 65),
			_raw("relic", "thick_fur", 120),
			_raw("modifier", "sharpened", 55),
			_raw("item", "fish_snack", 30),
		],
		"rerolls": 0,
	}
	var ok: RunRules.BuyResult = RunRules.BuyResult.OK
	assert_eq(RunRules.buy(run, stock, 0, db), ok)
	assert_eq(run.bag[0].move_id, &"loaded_paws")
	assert_eq(RunRules.buy(run, stock, 0, db), RunRules.BuyResult.SOLD_OUT)
	assert_eq(RunRules.buy(run, stock, 1, db), ok)
	assert_eq(run.max_hp, 72)
	assert_eq(RunRules.buy(run, stock, 2, db, 2), RunRules.BuyResult.CANT_ATTACH, "Paw Roll")
	assert_eq(RunRules.buy(run, stock, 2, db, 0), ok)
	assert_eq(run.equipped[0].modifier_ids, [&"sharpened"])
	run.pouch = [&"spare_die", &"spare_die", &"spare_die"]
	assert_eq(RunRules.buy(run, stock, 3, db), RunRules.BuyResult.POUCH_FULL)
	run.pouch[1] = &""
	assert_eq(RunRules.buy(run, stock, 3, db), ok)
	assert_eq(run.pouch[1], &"fish_snack")
	assert_eq(run.purrls, 1000 - 65 - 120 - 55 - 30)
	run.purrls = 10
	_entries(stock).append(_raw("item", "catnip_tea", 35))
	assert_eq(RunRules.buy(run, stock, 4, db), RunRules.BuyResult.TOO_POOR)


func test_stock_survives_json() -> void:
	var db: ContentDb = ContentDb.load_all()
	var stock: Dictionary = _generate(db, "JSON", 500)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(stock))
	var back: Dictionary = ShopRules.stock_from_payload(parsed, db)
	assert_eq(back, stock)
	assert_eq(ShopRules.stock_from_payload({"entries": [{"kind": "move"}]}, db), {})


func test_stock_is_deterministic_for_a_seed() -> void:
	var db: ContentDb = ContentDb.load_all()
	assert_eq(_generate(db, "SAME", 500), _generate(db, "SAME", 500))


func test_generate_only_touches_shop_stream() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("STREAMS", db.tuning())
	var rngs: RngSet = RngSet.for_seed("STREAMS")
	var before: Dictionary[StringName, int] = rngs.to_states()
	ShopRules.generate(1, run, db, "common", [], rngs.shop)
	var after: Dictionary[StringName, int] = rngs.to_states()
	for stream: StringName in before:
		if stream != &"shop":
			assert_eq(after[stream], before[stream], String(stream))
	assert_true(after[&"shop"] != before[&"shop"], "the shop stream moved")


func _generate(db: ContentDb, seed_text: String, purrls: int) -> Dictionary:
	var run: RunState = RunState.start(seed_text, db.tuning())
	run.purrls = purrls
	return ShopRules.generate(1, run, db, "common", [], SeededRng.new(seed_text))


func _entries(stock: Dictionary) -> Array:
	return stock["entries"]


func _kinds(stock: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for entry: Dictionary in _entries(stock):
		kinds.append(entry["kind"])
	return kinds


func _raw(kind: String, id: String, cost: int) -> Dictionary:
	return {"kind": kind, "id": id, "price": cost, "sold": false}
