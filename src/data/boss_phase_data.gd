class_name BossPhaseData
extends Resource
## One phase of a boss (PRD §9.4, D25). Banner text lives in src/ui/strings.gd, keyed by the boss id
## and phase index.

## The phase starts when HP × 100 <= this × max HP (inclusive, D25). Phase 0 uses 100.
@export var hp_at_or_below_pct: int = 100
## The boss's suit in this phase.
@export var suit: Suit.Type
## Intents in order; the pattern loops and restarts at the first step when the phase begins.
@export var pattern: Array[IntentData] = []
## Suits this phase rotates through (The Dealer, T031). Empty for a fixed suit.
@export var rotate_suits: Array[Suit.Type] = []
## Enemy actions between suit rotations (T031). 0 when the suit is fixed.
@export var rotate_every: int = 0
