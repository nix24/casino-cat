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
## - BACKFIRE: amount is the HP lost (shield does not apply), value_after the cat's HP after it.
## - DUE_CHANGED: reason is the gamble family, amount the new pip count.
## - RELIC_TRIGGERED: reason is the relic id (T013).
## - ITEM_USED: reason is the item id, amount the pouch slot (T014). STATUS_CLEANSED: status.
## - PHASE_CHANGED: reason = boss id, amount = new phase index, suit_from/suit_to (T019).
## - ITEM_FOUND: reason = item id, amount = pouch slot it went into (Dumpster Dive, T019).
## - SUIT_OVERRIDE_EXPIRED: Laser Pointer ended; a SUIT_SHIFTED (actor ENEMY) follows.
## - REROLLS_CHANGED: amount is the rerolls left. Gamble detail lives in `gamble` (T002).
## - GAMBLE_STARTED, GAMBLE_AWAITING_CHOICE: reason is the gamble family.
## - COIN_FLIPPED: amount is the pending damage after the flip, gamble.is_heads the side (T021).
## - STREAK_CHANGED: amount is the Hot Streak stacks after the change (decisions D22).
## - DECK_SHUFFLED: amount is the deck size (20). CARD_DRAWN: amount is the value drawn.
##   CARD_SAVED: amount is the value Luck turned the bust card into. CARDS_REORDERED: gamble.cards
##   are the cards put back, top first. Every card event carries gamble.cards (the hand),
##   gamble.counts, and gamble.bust_chance (T022).
## - MP_CHANGED with reason gamble: MP a gamble outcome paid (Heads Up tails).

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
	GAMBLE_STARTED,
	GAMBLE_AWAITING_CHOICE,
	DICE_ROLLED,
	DICE_REROLLED,
	LUCK_TRIGGERED,
	GAMBLE_RESOLVED,
	BACKFIRE,
	DUE_CHANGED,
	REROLLS_CHANGED,
	RELIC_TRIGGERED,
	ITEM_USED,
	STATUS_CLEANSED,
	FLED,
	SUIT_OVERRIDE_EXPIRED,
	PHASE_CHANGED,
	ITEM_FOUND,
	COIN_FLIPPED,
	STREAK_CHANGED,
	DECK_SHUFFLED,
	CARD_DRAWN,
	CARD_SAVED,
	CARDS_REORDERED,
}
enum Actor { CAT, ENEMY }

var kind: Kind
## Who caused the event. For ticks and expiry, the combatant that owns the status.
var actor: Actor
## Who received it: the combatant whose HP, shield, or status changed. Set on DAMAGE_DEALT,
## SHIELD_GAINED, HEALED, BACKFIRE, and STATUS_* (T003); CAT on every other kind.
var target: Actor = Actor.CAT
var amount: int = 0
var value_after: int = 0
var shield_after: int = 0
var absorbed: int = 0
var suit_from: Suit.Type = Suit.Type.CLUBS
var suit_to: Suit.Type = Suit.Type.CLUBS
var status: StringName = &""
var turns: int = 0
var move_id: StringName = &""
## Hits of an INTENT_SHOWN attack (MULTI_ATTACK shows ×hits).
var hits: int = 1
var reason: StringName = &""
## Gamble detail for the GAMBLE_*, DICE_*, LUCK_TRIGGERED events. Null on every other kind.
var gamble: GambleEventData


func _init(event_kind: Kind, event_actor: Actor = Actor.CAT) -> void:
	kind = event_kind
	actor = event_actor
