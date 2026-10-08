class_name BattleEvent
extends RefCounted
## One thing that happened in a battle. The presentation plays these in order; rules never play
## animations themselves (decision D3).
##
## Field meanings by kind:
## - DAMAGE_DEALT: amount is the hit before shield, absorbed is the shield part, value_after is
##   the target's HP, shield_after is the target's shield. actor is the attacker.
## - SHIELD_GAINED: amount is what was actually added after the cap, value_after and shield_after
##   are the new shield.
## - MP_CHANGED: reason is cost, steal, dealt, taken, or move. amount is signed and is the intended
##   change; value_after is the MP after clamping to 0..mp_max.
## - INTENT_SHOWN: reason is the intent kind, amount its amount, status and turns for DEBUFF.
## - STATUS_TICKED, STATUS_EXPIRED: actor is the status owner.

enum Kind {
	BATTLE_STARTED,
	TURN_STARTED,
	INTENT_SHOWN,
	MOVE_USED,
	ACTION_REJECTED,
	DAMAGE_DEALT,
	SHIELD_GAINED,
	HEALED,
	MP_CHANGED,
	SUIT_SHIFTED,
	STATUS_APPLIED,
	STATUS_TICKED,
	STATUS_EXPIRED,
	ENEMY_ACTED,
	BATTLE_WON,
	BATTLE_LOST,
}
enum Actor { CAT, ENEMY }

var kind: Kind
## Who caused the event. For ticks and expiry, the combatant that owns the status.
var actor: Actor
var amount: int = 0
var value_after: int = 0
var shield_after: int = 0
var absorbed: int = 0
var suit_from: Suit.Type = Suit.Type.CLUBS
var suit_to: Suit.Type = Suit.Type.CLUBS
var status: StringName = &""
var turns: int = 0
var move_id: StringName = &""
var reason: StringName = &""


func _init(event_kind: Kind, event_actor: Actor = Actor.CAT) -> void:
	kind = event_kind
	actor = event_actor
