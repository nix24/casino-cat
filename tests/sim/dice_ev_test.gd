extends TestCase
## Seeded EV and tier-frequency checks for the Dice family (gamble-math.md, decisions D39). Each
## trial rolls faces from the gamble stream, applies Luck rerolls the way DiceFamily.start does,
## and scores the faces with DiceFamily.score. Means within max(3%, 0.02); tier shares within 1
## point.

const TRIALS: int = 50_000
const PAW_ROLL_PATH: String = "res://src/content/moves/paw_roll.tres"
const LOADED_PAWS_PATH: String = "res://src/content/moves/loaded_paws.tres"
const SNAKE_EYES_PATH: String = "res://src/content/moves/snake_eyes.tres"
const MEAN_KEY: StringName = &"mean"
## Backfire cap at 60 max HP. Backfire does not affect the payout means under test.
const CAP: int = 7


func test_paw_roll_ev_and_tiers() -> void:
	var shares: Dictionary[StringName, float] = _play(_dice(PAW_ROLL_PATH), 0)
	_assert_mean(shares, 12.36)
	_assert_share(shares, &"Snake eyes", 0.0278)
	_assert_share(shares, &"Cold", 0.2500)
	_assert_share(shares, &"Fair", 0.4444)
	_assert_share(shares, &"Hot", 0.1944)
	_assert_share(shares, &"Lucky", 0.0556)
	_assert_share(shares, &"Boxcars", 0.0278)


func test_loaded_paws_ev_and_tiers() -> void:
	var shares: Dictionary[StringName, float] = _play(_dice(LOADED_PAWS_PATH), 0)
	_assert_mean(shares, 17.41)
	_assert_share(shares, &"Snake eyes", 0.0046)
	_assert_share(shares, &"Cold", 0.1019)
	_assert_share(shares, &"Fair", 0.3704)
	_assert_share(shares, &"Hot", 0.3241)
	_assert_share(shares, &"Lucky", 0.1250)
	_assert_share(shares, &"Boxcars", 0.0741)


func test_snake_eyes_ev() -> void:
	var shares: Dictionary[StringName, float] = _play(_dice(SNAKE_EYES_PATH), 0)
	_assert_mean(shares, 11.00)
	_assert_share(shares, &"Jackpot", 1.0 / 6.0)


func test_luck_reroll_matches_preview() -> void:
	# Snake Eyes at Luck 10: the rolled mean must match the 13/72 preview (11.42).
	var snake_shares: Dictionary[StringName, float] = _play(_dice(SNAKE_EYES_PATH), 10)
	_assert_mean(snake_shares, 11.42)

	# Paw Roll at Luck 20: the rolled mean must match what the preview table itself promises.
	var paw: DiceGambleData = _dice(PAW_ROLL_PATH)
	var preview_mean: float = GambleRules.odds(paw, 20, 1.0, CAP).expected_damage()
	var paw_shares: Dictionary[StringName, float] = _play(paw, 20)
	_assert_mean(paw_shares, preview_mean)


## Plays [constant TRIALS] seeded rolls and returns the mean payout under key [constant MEAN_KEY]
## and each outcome label's share.
func _play(dice: DiceGambleData, luck: int) -> Dictionary[StringName, float]:
	var rng := SeededRng.derive("sim", "gamble")
	var session := GambleSession.new()
	var chance: float = GambleRules.luck_chance(luck)
	var counts: Dictionary[StringName, int] = {}
	var payout_total: int = 0
	for _trial: int in TRIALS:
		var faces: PackedInt32Array = DiceFamily.roll_faces(dice.dice_count, session, rng)
		for index: int in faces.size():
			if DiceFamily.luck_eligible(dice, faces[index]) and rng.chance(chance):
				faces[index] = DiceFamily.draw_face(session, rng)
		var row: GambleOddsRow = DiceFamily.score(dice, faces, luck, 1.0, CAP)
		payout_total += row.payout
		counts[row.label] = counts.get(row.label, 0) + 1

	var shares: Dictionary[StringName, float] = {}
	for label: StringName in counts:
		shares[label] = float(counts[label]) / TRIALS
	shares[MEAN_KEY] = float(payout_total) / TRIALS
	return shares


func _assert_mean(shares: Dictionary[StringName, float], expected: float) -> void:
	var mean: float = shares[MEAN_KEY]
	assert_almost_eq(mean, expected, maxf(0.03 * expected, 0.02), "mean")


func _assert_share(
	shares: Dictionary[StringName, float], label: StringName, expected: float
) -> void:
	var share: float = shares.get(label, 0.0)
	assert_almost_eq(share, expected, 0.01, "share of %s" % label)


func _dice(path: String) -> DiceGambleData:
	return (load(path) as MoveData).gamble as DiceGambleData
