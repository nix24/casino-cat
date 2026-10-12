extends TestCase
## Map generation over many seeds (T009, PRD §3.1, D52). The 10k-seed run is
## map_gen_slow_test.gd; this file samples fewer seeds so check.sh stays fast. A fallback map
## would push_error, which fails the test.

const SEEDS: int = 100


func test_seeds_per_act_are_valid() -> void:
	MapSim.assert_valid(self, SEEDS)


func test_same_seed_same_map() -> void:
	var tuning := TuningData.new()
	for i: int in 100:
		var seed_text: String = "SIM-%05d" % i
		var first: MapData = MapGen.generate(1 + i % 3, tuning, SeededRng.new(seed_text))
		var second: MapData = MapGen.generate(1 + i % 3, tuning, SeededRng.new(seed_text))
		assert_eq(first.to_dict(), second.to_dict(), seed_text)
