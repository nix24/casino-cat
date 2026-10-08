extends TestCase
## Per-hit damage arithmetic (PRD §4.4). Numbers come from the PRD and the T001 worked examples.


func test_triangle_worked_numbers() -> void:
	var advantage: float = Suit.damage_multiplier(Suit.Type.SPADES, Suit.Type.HEARTS)
	var disadvantage: float = Suit.damage_multiplier(Suit.Type.HEARTS, Suit.Type.SPADES)
	assert_eq(Damage.hit_amount(6, 0, advantage, 1.0, false, false), 9, "6 x 1.5")
	assert_eq(Damage.hit_amount(6, 0, disadvantage, 1.0, false, false), 5, "6 x 0.75 = 4.5")


func test_round_half_up() -> void:
	assert_eq(Damage.round_half_up(4.5), 5)
	assert_eq(Damage.round_half_up(6.75), 7)
	assert_eq(Damage.round_half_up(2.4), 2)


func test_minimum_one_when_raw_positive() -> void:
	assert_eq(Damage.hit_amount(1, 0, 0.75, 0.5, false, false), 1, "0.375 rounds to 0, raised to 1")
	assert_eq(Damage.round_half_up(0.0), 0, "zero stays zero")


func test_repeat_multipliers() -> void:
	var tuning := TuningData.new()
	var expected: Array[int] = [6, 6, 5, 3, 3]
	for count: int in range(1, 6):
		var repeat_mult: float = Damage.repeat_multiplier(count, tuning)
		var amount: int = Damage.hit_amount(6, 0, 1.0, repeat_mult, false, false)
		assert_eq(amount, expected[count - 1], "repeat count %d" % count)


func test_weak_and_exposed() -> void:
	assert_eq(Damage.hit_amount(6, 0, 1.0, 1.0, false, true), 8, "6 x 1.25 = 7.5 rounds up")
	assert_eq(Damage.hit_amount(6, 0, 1.0, 1.0, true, false), 5, "6 x 0.75 = 4.5 rounds up")


func test_multi_hit_rounds_each_hit() -> void:
	var total: int = 0
	for hit: int in 3:
		total += Damage.hit_amount(3, 0, 1.5, 1.0, false, false)
	assert_eq(total, 15, "three hits of 4.5 round to 5 each, not 14 in one lump")


func test_absorb_shield_first() -> void:
	var target := Combatant.new()
	target.hp = 10
	target.shield = 4
	assert_eq(Damage.absorb(target, 6), 4, "absorbed")
	assert_eq(target.shield, 0, "shield after")
	assert_eq(target.hp, 8, "hp after the unabsorbed 2")

	target.hp = 10
	target.shield = 10
	assert_eq(Damage.absorb(target, 6), 6, "absorbed")
	assert_eq(target.shield, 4, "shield after")
	assert_eq(target.hp, 10, "hp unchanged")
