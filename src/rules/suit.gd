class_name Suit
extends RefCounted
## The suit type triangle: Spades beat Hearts, Hearts beat Diamonds, Diamonds beat Spades.
##
## Clubs is the neutral suit used by gamble moves. It neither gives nor takes advantage.
## Pure rules: no nodes, no randomness. See docs/PRD.md section "Suit triangle".

enum Type { SPADES, HEARTS, DIAMONDS, CLUBS }

const ADVANTAGE_MULTIPLIER: float = 1.5
const DISADVANTAGE_MULTIPLIER: float = 0.75
const NEUTRAL_MULTIPLIER: float = 1.0

## Which suit each suit beats. Clubs beats nothing.
const BEATS: Dictionary[Type, Type] = {
	Type.SPADES: Type.HEARTS,
	Type.HEARTS: Type.DIAMONDS,
	Type.DIAMONDS: Type.SPADES,
}


## Damage multiplier for a move of [param attacker] suit hitting a target of [param defender] suit.
static func damage_multiplier(attacker: Type, defender: Type) -> float:
	if BEATS.get(attacker) == defender:
		return ADVANTAGE_MULTIPLIER
	if BEATS.get(defender) == attacker:
		return DISADVANTAGE_MULTIPLIER
	return NEUTRAL_MULTIPLIER
