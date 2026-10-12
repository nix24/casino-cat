extends TestCase
## Treasure chests (T020, PRD §10.4, D30, D31).


func test_roll_rarity_is_50_35_15() -> void:
	var rng := SeededRng.new("CHEST")
	var counts: Dictionary[String, int] = {}
	for _roll: int in 10_000:
		var rarity: String = TreasureRules.roll_rarity(rng)
		counts[rarity] = counts.get(rarity, 0) + 1
	assert_almost_eq(counts["common"] / 10_000.0, 0.50, 0.015, "common")
	assert_almost_eq(counts["uncommon"] / 10_000.0, 0.35, 0.015, "uncommon")
	assert_almost_eq(counts["rare"] / 10_000.0, 0.15, 0.015, "rare")


func test_roll_rarity_boundaries() -> void:
	var expected: Dictionary[int, String] = {
		1: "common", 50: "common", 51: "uncommon", 85: "uncommon", 86: "rare", 100: "rare"
	}
	for roll: int in expected:
		assert_eq(TreasureRules.rarity_for_roll(roll), expected[roll], "roll %d" % roll)


func test_open_chest_gives_rarity_of_chest() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("CHEST", db.tuning())
	var relic: RelicData = TreasureRules.open_chest(run, "common", db, SeededRng.new("c"))
	assert_eq(relic.rarity, RelicData.Rarity.COMMON)
	assert_eq(run.relics, [relic.id])


func test_open_chest_skips_owned_relics() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("CHEST", db.tuning())
	run.relics = [&"loaded_die", &"thick_fur", &"velvet_rope", &"pit_boss"]
	var relic: RelicData = TreasureRules.open_chest(run, "common", db, SeededRng.new("c"))
	assert_eq(relic.id, &"peeking_monocle", "the last unowned common")
	var rare_owned: RunState = RunState.start("CHEST", db.tuning())
	rare_owned.relics = [&"maneki_paw"]
	var fallback: RelicData = TreasureRules.open_chest(rare_owned, "rare", db, SeededRng.new("c"))
	assert_eq(fallback.rarity, RelicData.Rarity.COMMON, "no rare or uncommon left: down (D30)")
