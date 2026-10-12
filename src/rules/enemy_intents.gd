class_name EnemyIntents
extends RefCounted
## Enemy intent extras (PRD §9.1-9.3, T018): HP overrides and the special intents. Pure; BattleRules
## calls these just before the enemy acts.

const CHEAT_SUIT: StringName = &"cheat_suit"
## A Cheat lasts through the cat's next turn: it reverts at the end of the turn after it lands.
const CHEAT_TURNS: int = 2


## The override that replaces this enemy action, or null (arch §3 step 7). HP_BELOW_PCT is strict:
## hp × 100 < threshold × max_hp. A `once` override is recorded in state.fired_overrides.
static func due_override(state: BattleState) -> IntentOverrideData:
	for index: int in state.enemy_data.overrides.size():
		var override: IntentOverrideData = state.enemy_data.overrides[index]
		if override.once and state.fired_overrides.has(index):
			continue
		if state.enemy.hp * 100 < override.threshold_pct * state.enemy.max_hp:
			if override.once:
				state.fired_overrides.append(index)
			return override
	return null


## The suit that beats [param suit] on the triangle, or -1 when nothing does (♣).
static func counter_suit(suit: Suit.Type) -> int:
	for attacker: Suit.Type in Suit.BEATS:
		if Suit.BEATS[attacker] == suit:
			return attacker
	return -1
