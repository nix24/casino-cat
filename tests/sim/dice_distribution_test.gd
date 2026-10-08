extends TestCase
## Seeded Monte-Carlo check: a d6 from SeededRng must be fair, because every gamble shows its
## odds to the player and those odds have to be true.

const ROLLS: int = 60_000


func test_d6_is_fair_within_two_percent() -> void:
	var rng := SeededRng.new("sim:d6")
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for i: int in ROLLS:
		counts[rng.range_int(1, 6) - 1] += 1
	for face: int in 6:
		var share: float = float(counts[face]) / ROLLS
		assert_almost_eq(share, 1.0 / 6.0, 0.02, "face %d" % (face + 1))
