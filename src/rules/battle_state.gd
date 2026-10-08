class_name BattleState
extends RefCounted
## Everything one battle remembers between turns. Created by BattleRules.start; apply() updates it.

enum Outcome { ONGOING, WON, LOST }

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
## The gamble waiting for a player choice, or null. While set, only GAMBLE_CHOICE is accepted.
var pending: GambleSession
