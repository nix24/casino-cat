extends TestCase
## The full T009 map sim: 10,000 seeds per act, all valid with no fallback, and type shares
## within ±3 points of the PRD §3.1 weights (D52 window). Runs with `-- --slow` (D39).

const SEEDS: int = 10_000


func test_10k_seeds_per_act_are_valid() -> void:
	MapSim.assert_valid(self, SEEDS)


func test_type_frequencies_within_3_points() -> void:
	var table: String = MapSim.assert_frequencies(self, SEEDS)
	if not failures.is_empty():
		printerr(table)
	print(table)
