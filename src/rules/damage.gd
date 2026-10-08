class_name Damage
extends RefCounted
## Damage arithmetic (PRD §4.4). Every hit goes through here; no other rule computes damage.

const WEAK_MULTIPLIER: float = 0.75
const EXPOSED_MULTIPLIER: float = 1.25


## Rounds half up, but a hit that rounds to 0 still deals 1 if its raw value was above 0.
static func round_half_up(raw: float) -> int:
	var rounded: int = floori(raw + 0.5)
	if raw > 0.0 and rounded == 0:
		return 1
	return rounded


## Multiplier for the Nth basic use in a row. The count is capped at 4 in the tuning table.
static func repeat_multiplier(repeat_count: int, tuning: TuningData) -> float:
	assert(repeat_count >= 1, "repeat_count starts at 1 for the first use")
	return tuning.repeat_penalty[mini(repeat_count, 4) - 1]


## Final damage for one hit. Each hit is rounded on its own, so three hits of 4.5 deal 15.
static func hit_amount(
	base: int,
	flat: int,
	triangle: float,
	repeat_mult: float,
	attacker_weak: bool,
	defender_exposed: bool,
) -> int:
	var raw: float = float(base + flat) * triangle * repeat_mult
	if attacker_weak:
		raw *= WEAK_MULTIPLIER
	if defender_exposed:
		raw *= EXPOSED_MULTIPLIER
	return round_half_up(raw)


## Shield takes the first part of [param amount]. Mutates target shield and hp, and returns the
## part the shield absorbed. HP never drops below 0.
static func absorb(target: Combatant, amount: int) -> int:
	assert(amount >= 0, "damage cannot be negative")
	var absorbed: int = mini(target.shield, amount)
	target.shield -= absorbed
	target.hp = maxi(target.hp - (amount - absorbed), 0)
	return absorbed
