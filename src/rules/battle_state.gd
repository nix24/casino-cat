class_name BattleState
extends RefCounted
## Everything one battle remembers between turns. Created by BattleRules.start; apply() updates it.

enum Outcome { ONGOING, WON, LOST, FLED }

var cat: Combatant = Combatant.new()
var enemy: Combatant = Combatant.new(BattleEvent.Actor.ENEMY)
var enemy_data: EnemyData
var turn: int = 1
var mp: int = 0
## The cat's loadout for this battle. Slots index into this array.
var equipped: Array[MoveInstance] = []
var last_move_id: StringName = &""
## How many basic uses in a row of last_move_id. Drives the repeat penalty (PRD §4.4).
var repeat_count: int = 0
var intent_index: int = 0
## The intent the enemy will perform at the end of this turn, already shown to the player.
var next_intent: IntentData
var outcome: Outcome = Outcome.ONGOING
## Rerolls left for dice gambles this battle (PRD §6.1). Set from tuning at battle start.
var rerolls: int = 0
## Uses the repeat penalty starts later, from relics such as Pit Boss (PRD §4.4, T013).
var repeat_shift: int = 0
## Loadout slot of the move being resolved, so a gamble's resolution finds the cat's copy.
var acting_slot: int = 0
## The gamble waiting for a player choice, or null. While set, only GAMBLE_CHOICE is accepted.
var pending: GambleSession
## Turn the last pouch item was used on; one item per turn (PRD §8.3).
var last_item_turn: int = -1
## Indexes into enemy_data.overrides that already fired (once-only overrides, T018).
var fired_overrides: Array[int] = []
## True when this turn's enemy action was an override, so the pattern step is retried next turn.
var override_acted: bool = false
## Lucky Charm: the next gamble resolves at its top tier.
var guarantee_top_tier: bool = false
## Ball of Yarn: the enemy's next attack deals this percent (rounded down); 0 when unused.
var weaken_next_attack_pct: int = 0
## Laser Pointer: turns left on the forced enemy suit, and the suit to restore after.
var suit_override_turns: int = 0
var suit_before_override: Suit.Type = Suit.Type.CLUBS
