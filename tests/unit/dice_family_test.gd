extends TestCase
## Dice family (PRD §6.1, gamble-math.md) on its own: tier lookup, kept dice, Snake Eyes, Luck
## eligibility, scripted faces, and the shipped .tres numbers.

const PAW_ROLL_PATH: String = "res://src/content/moves/paw_roll.tres"
const LOADED_PAWS_PATH: String = "res://src/content/moves/loaded_paws.tres"
const SNAKE_EYES_PATH: String = "res://src/content/moves/snake_eyes.tres"

## Backfire cap is not under test here; any value above the table's 4 keeps the rows intact.
const CAP: int = 7


func test_tier_for_each_sum() -> void:
	var tiers: Array[DiceTierData] = _paw_roll().tiers
	var expected: Array[StringName] = [
		&"Snake eyes", &"Cold", &"Fair", &"Hot", &"Lucky", &"Boxcars"
	]
	var sums: Array[int] = [2, 4, 7, 9, 11, 12]
	for index: int in sums.size():
		assert_eq(
			DiceFamily.tier_for_sum(tiers, sums[index]).label,
			expected[index],
			"sum %d" % sums[index]
		)


func test_kept_sum_keeps_best_two_of_three() -> void:
	assert_eq(DiceFamily.kept_sum(PackedInt32Array([1, 6, 6]), 2), 12, "1, 6, 6")
	assert_eq(DiceFamily.kept_sum(PackedInt32Array([2, 2, 5]), 2), 7, "2, 2, 5")


func test_snake_eyes_jackpot_only_on_1() -> void:
	var snake: DiceGambleData = _snake_eyes()
	var jackpot: GambleOddsRow = DiceFamily.score(snake, PackedInt32Array([1]), 0, 1.0, CAP)
	assert_eq(jackpot.label, &"Jackpot", "face 1 label")
	assert_eq(jackpot.payout, 36, "face 1 payout")
	assert_eq(jackpot.due_step, GambleData.DueStep.TOP, "face 1 empties due")
	var plain: GambleOddsRow = DiceFamily.score(snake, PackedInt32Array([4]), 0, 1.0, CAP)
	assert_eq(plain.label, &"Plain", "face 4 label")
	assert_eq(plain.payout, 6, "face 4 payout")
	assert_eq(plain.due_step, GambleData.DueStep.BOTTOM, "face 4 adds a pip")


func test_luck_eligible() -> void:
	var paw: DiceGambleData = _paw_roll()
	assert_true(DiceFamily.luck_eligible(paw, 1), "paw 1 rerolls")
	assert_true(DiceFamily.luck_eligible(paw, 2), "paw 2 rerolls")
	for face: int in [3, 4, 5, 6]:
		assert_true(not DiceFamily.luck_eligible(paw, face), "paw %d holds" % face)
	var snake: DiceGambleData = _snake_eyes()
	assert_true(not DiceFamily.luck_eligible(snake, 1), "snake eyes 1 holds")
	for face: int in [2, 3, 4, 5, 6]:
		assert_true(DiceFamily.luck_eligible(snake, face), "snake eyes %d rerolls" % face)


func test_forced_faces_then_rng() -> void:
	var session := GambleSession.new()
	session.forced = [3]
	var rng := SeededRng.new("test:forced")
	var faces: PackedInt32Array = DiceFamily.roll_faces(2, session, rng)
	assert_eq(faces[0], 3, "forced face first")
	assert_true(faces[1] >= 1 and faces[1] <= 6, "rng face in 1..6")
	assert_true(session.forced.is_empty(), "forced consumed")


func test_content_loads() -> void:
	var paw: MoveData = load(PAW_ROLL_PATH) as MoveData
	assert_true(paw != null, "paw roll loads")
	if paw != null:
		assert_eq(paw.display_name, "Paw Roll", "paw name")
		assert_eq(paw.category, MoveData.Category.GAMBLE, "paw category")
		assert_eq(paw.suit, Suit.Type.CLUBS, "paw suit")
		assert_eq(paw.rarity, MoveData.Rarity.STARTER, "paw rarity")
		assert_eq(paw.mp_cost, 30, "paw cost")
		assert_eq(paw.base_damage, 10, "paw base")
		_check_paw_tiers(_paw_roll())

	var loaded: MoveData = load(LOADED_PAWS_PATH) as MoveData
	assert_true(loaded != null, "loaded paws loads")
	if loaded != null:
		assert_eq(loaded.display_name, "Loaded Paws", "loaded name")
		assert_eq(loaded.category, MoveData.Category.GAMBLE, "loaded category")
		assert_eq(loaded.suit, Suit.Type.CLUBS, "loaded suit")
		assert_eq(loaded.rarity, MoveData.Rarity.UNCOMMON, "loaded rarity")
		assert_eq(loaded.mp_cost, 45, "loaded cost")
		assert_eq(loaded.base_damage, 10, "loaded base")
		assert_eq(_loaded_paws().dice_count, 3, "loaded dice")
		assert_eq(_loaded_paws().keep_best, 2, "loaded keep")
		assert_eq(_loaded_paws().base_damage, 10, "loaded gamble base")
		_check_paw_tiers(_loaded_paws())

	var snake: MoveData = load(SNAKE_EYES_PATH) as MoveData
	assert_true(snake != null, "snake eyes loads")
	if snake != null:
		assert_eq(snake.display_name, "Snake Eyes", "snake name")
		assert_eq(snake.category, MoveData.Category.GAMBLE, "snake category")
		assert_eq(snake.suit, Suit.Type.CLUBS, "snake suit")
		assert_eq(snake.rarity, MoveData.Rarity.RARE, "snake rarity")
		assert_eq(snake.mp_cost, 25, "snake cost")
		assert_eq(snake.base_damage, 6, "snake base")
		assert_eq(_snake_eyes().dice_count, 1, "snake dice")
		assert_eq(_snake_eyes().jackpot_face, 1, "snake jackpot face")
		assert_eq(_snake_eyes().jackpot_damage, 36, "snake jackpot damage")
		assert_true(_snake_eyes().tiers.is_empty(), "snake has no tier table")


## The Paw Roll tier table (PRD §6.1), shared by Paw Roll and Loaded Paws.
func _check_paw_tiers(dice: DiceGambleData) -> void:
	assert_eq(dice.family, &"dice", "family")
	assert_eq(dice.tiers.size(), 6, "tier count")
	if dice.tiers.size() != 6:
		return
	_assert_tier(dice.tiers[0], 2, 2, 0.0, 4, &"Snake eyes", GambleData.DueStep.BOTTOM)
	_assert_tier(dice.tiers[1], 3, 5, 0.5, 0, &"Cold", GambleData.DueStep.BOTTOM)
	_assert_tier(dice.tiers[2], 6, 8, 1.0, 0, &"Fair", GambleData.DueStep.NONE)
	_assert_tier(dice.tiers[3], 9, 10, 2.0, 0, &"Hot", GambleData.DueStep.NONE)
	_assert_tier(dice.tiers[4], 11, 11, 3.0, 0, &"Lucky", GambleData.DueStep.TOP)
	_assert_tier(dice.tiers[5], 12, 12, 4.0, 0, &"Boxcars", GambleData.DueStep.TOP)


func _assert_tier(
	tier: DiceTierData,
	min_sum: int,
	max_sum: int,
	multiplier: float,
	backfire: int,
	label: StringName,
	due_step: GambleData.DueStep
) -> void:
	assert_eq(tier.min_sum, min_sum, "%s min" % label)
	assert_eq(tier.max_sum, max_sum, "%s max" % label)
	assert_almost_eq(tier.multiplier, multiplier, 1e-9, "%s multiplier" % label)
	assert_eq(tier.backfire, backfire, "%s backfire" % label)
	assert_eq(tier.label, label, "label")
	assert_eq(tier.due_step, due_step, "%s due step" % label)


func _paw_roll() -> DiceGambleData:
	return (load(PAW_ROLL_PATH) as MoveData).gamble as DiceGambleData


func _loaded_paws() -> DiceGambleData:
	return (load(LOADED_PAWS_PATH) as MoveData).gamble as DiceGambleData


func _snake_eyes() -> DiceGambleData:
	return (load(SNAKE_EYES_PATH) as MoveData).gamble as DiceGambleData
