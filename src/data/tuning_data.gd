class_name TuningData
extends Resource
## Global gameplay numbers (PRD §23). Each field's default is the PRD starting value; the shipped
## values live in src/content/tuning.tres (T004). Tests use these defaults.

## Cat max HP at battle start (PRD §4.5).
@export var cat_max_hp: int = 60
## Percent of max HP healed after a won battle (PRD §4.5).
@export var post_battle_heal_pct: int = 10
## Most shield the cat or an enemy can hold (PRD §4.5).
@export var shield_cap: int = 30
## Damage multiplier when a move's suit beats the defender's suit (PRD §4.3).
@export var triangle_advantage: float = 1.5
## Damage multiplier when a move's suit loses to the defender's suit (PRD §4.3).
@export var triangle_disadvantage: float = 0.75
## Whether using a move of another suit changes the cat's suit (PRD §4.3).
@export var type_shift_enabled: bool = true
## Damage multiplier by repeat count. Index 0 is use 1; use 4 and later read the last (PRD §4.4).
@export var repeat_penalty: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.75, 0.5])
## Moves the cat has equipped in battle (PRD §4.2).
@export var equipped_moves: int = 4
## Slots in the move bag (PRD §4.2).
@export var bag_size: int = 4
## Largest MP the cat can hold (PRD §7).
@export var mp_max: int = 100
## MP at the start of each battle (PRD §7).
@export var mp_battle_start: int = 20
## MP earned per point of HP damage the cat deals, charged at end of turn (PRD §7).
@export var mp_per_damage_dealt: float = 0.5
## MP earned per point of HP damage the cat takes, charged at end of turn (PRD §7).
@export var mp_per_damage_taken: float = 1.0
## Highest chance a gamble may show; guaranteed outcomes are the exception (PRD §6.0).
@export var probability_cap: float = 0.95
## Largest backfire, as a percent of max HP (PRD §6.0).
@export var backfire_cap_pct_max_hp: int = 12
## Highest Due meter value, in pips (PRD §6.0).
@export var due_pips_max: int = 4
## Luck granted per Due pip (PRD §6.0).
@export var luck_per_pip: int = 5
## Dice rerolls per battle at the start (PRD §6.1).
@export var dice_rerolls_per_battle: int = 1
## Heads chance of a plain coin flip (PRD §6.2).
@export var coin_heads_base: float = 0.55
## Base win chance of an Ante gamble (PRD §6.7).
@export var ante_win_base: float = 0.60
## Most Lucky Tickets that can be waiting to mature at once (PRD §6.6).
@export var ticket_max_active: int = 2
## Slots in the pouch for held items (PRD §8.3).
@export var pouch_slots: int = 3
## Purrls the player starts a run with (PRD §11).
@export var start_purrls: int = 50
## Percent of max HP healed between acts (PRD §3.2).
@export var act_heal_pct: int = 50
## Percent of max HP healed at a rest site (PRD §10.1).
@export var rest_heal_pct: int = 30
## Rows in a generated map (PRD §3.1).
@export var map_rows: int = 15
## Columns in a generated map (PRD §3.1).
@export var map_cols: int = 7
## Walks from start to boss used to lay out a map (PRD §3.1).
@export var map_walks: int = 6
## Shop price multiplier per act, Act 1 to Act 3 (PRD §10.2).
@export var shop_price_scale: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3])
## Purrls for the first shop reroll (PRD §10.2).
@export var shop_reroll_cost: int = 15
## Purrls added to the reroll cost after each reroll (PRD §10.2).
@export var shop_reroll_step: int = 10
