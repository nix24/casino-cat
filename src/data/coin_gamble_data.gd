class_name CoinGambleData
extends GambleData
## Outcome data of a Coin move (PRD §6.2). Every flip lands heads at the coin's heads chance.

## DOUBLE: cash out or flip again after each head. SINGLE: one flip. STREAK: flip until tails.
enum Mode { DOUBLE, SINGLE, STREAK }

## How the move flips and pays.
@export var mode: Mode = Mode.SINGLE
## Damage of the first head. DOUBLE doubles it per further head; SINGLE pays it on heads.
@export var start_damage: int = 0
## Damage each head adds. STREAK only.
@export var per_head_damage: int = 0
## Most heads one use can land: DOUBLE auto-cashes there, STREAK stops flipping there.
@export var max_heads: int = 1
## HP the cat loses on tails, before the backfire cap.
@export var backfire: int = 0
## MP the cat gains on tails. SINGLE only (Heads Up).
@export var tails_mp: int = 0
