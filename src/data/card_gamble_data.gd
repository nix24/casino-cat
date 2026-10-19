class_name CardGambleData
extends GambleData
## Outcome data of a Cards move (PRD §6.3). Every card comes from the battle deck.

## BLACKJACK: Nine Lives. HIGH_CARD: draw 1. TRICK: draw 3, keep one, put two back.
enum Mode { BLACKJACK, HIGH_CARD, TRICK }

## How the move draws and pays.
@export var mode: Mode = Mode.HIGH_CARD
## Payout per card value point for HIGH_CARD and TRICK, rounded half up.
@export var multiplier: float = 1.0
## HP the cat loses on a bust (BLACKJACK), before the backfire cap.
@export var bust_backfire: int = 0
## Payout for a total of exactly 21 (BLACKJACK).
@export var blackjack_damage: int = 0
