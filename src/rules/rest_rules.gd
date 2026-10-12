class_name RestRules
extends RefCounted
## The rest site (PRD §10.1): Nap or Practice ends the node; Rearrange (T012) never does. Pure.

const PRACTICE_BASIC: StringName = &"sharpened"
const PRACTICE_GAMBLE: StringName = &"cheap"


## HP a Nap restores: 30% of max HP, round half up (D15), capped at max.
static func nap_amount(run: RunState, tuning: TuningData) -> int:
	return mini(floori(run.max_hp * tuning.rest_heal_pct / 100.0 + 0.5), run.max_hp - run.hp)


## Heals the cat and returns the HP actually healed.
static func nap(run: RunState, tuning: TuningData) -> int:
	var heal: int = nap_amount(run, tuning)
	run.hp += heal
	return heal


## The modifier Practice gives [param move]: Sharpened for a basic move, Cheap for a gamble, or
## empty for utility and signature moves (PRD §10.1).
static func practice_modifier(move: MoveData) -> StringName:
	match move.category:
		MoveData.Category.BASIC:
			return PRACTICE_BASIC
		MoveData.Category.GAMBLE:
			return PRACTICE_GAMBLE
	return &""


## Equipped slots Practice can improve: the right category, a free modifier slot, and not already
## carrying that modifier (D3: no duplicates on one move).
static func practice_targets(run: RunState, db: ContentDb) -> Array[int]:
	var targets: Array[int] = []
	for slot: int in run.equipped.size():
		var instance: MoveInstance = run.equipped[slot]
		var modifier_id: StringName = practice_modifier(db.move(instance.move_id))
		if (
			modifier_id != &""
			and instance.modifier_ids.size() < RunRules.MODIFIER_SLOTS
			and not instance.modifier_ids.has(modifier_id)
		):
			targets.append(slot)
	return targets


## Attaches the Practice modifier to equipped [param slot] through RunRules.attach_modifier. False
## when the slot is not a valid target.
static func practice(run: RunState, slot: int, db: ContentDb) -> bool:
	if not practice_targets(run, db).has(slot):
		return false
	var modifier_id: StringName = practice_modifier(db.move(run.equipped[slot].move_id))
	return RunRules.attach_modifier(run, slot, modifier_id, db) == RunRules.AttachResult.OK
