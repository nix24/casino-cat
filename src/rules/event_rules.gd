class_name EventRules
extends RefCounted
## Map events (PRD §10.3, D18, D35). Pure: the roll comes from the run's event stream, and every
## outcome's odds are the data the roll uses.

const MAX_TEXT_WORDS: int = 60
const MAX_RESULT_WORDS: int = 25
const MAX_CHOICES: int = 3
## An event may cost at most this percent of max HP (PRD §10.3).
const MAX_HP_COST_PCT: int = 20
const PROBABILITY_TOLERANCE: float = 0.001


## What a choice did. A refused choice has ok false and a reason; nothing changed.
class EventResult:
	extends RefCounted
	var ok: bool = false
	var reason: StringName = &""
	var outcome_index: int = -1
	var result_text: String = ""
	## A modifier the player must now attach to a move (ADD_MODIFIER), or empty.
	var modifier_id: StringName = &""
	## An enemy to fight now (START_BATTLE), or empty.
	var battle_enemy_id: StringName = &""


## The event an event node shows (D54): uniform over [param act]'s events not yet in
## run.seen_events, or over all of them once every one was seen. Draws from the event stream.
static func pick_event(run: RunState, db: ContentDb, rng: SeededRng) -> EventData:
	var all: Array[EventData] = db.events_for(run.act)
	assert(not all.is_empty(), "act %d has no events" % run.act)
	var fresh: Array[EventData] = all.filter(
		func(event: EventData) -> bool: return not run.seen_events.has(event.id)
	)
	var pool: Array[EventData] = fresh if not fresh.is_empty() else all
	return pool[rng.range_int(0, pool.size() - 1)]


## Why [param choice] can't be picked now (D35), or &"": `purrls` (too few), `pouch_full`,
## `loadout_full`, `no_target` (no move can take the modifier), `no_gamble`.
static func disabled_reason(run: RunState, choice: EventChoiceData, db: ContentDb) -> StringName:
	if run.purrls < choice.min_purrls:
		return &"purrls"
	if choice.requires_gamble and not _owns_gamble(run, db):
		return &"no_gamble"
	for outcome: EventOutcomeData in choice.outcomes:
		for effect: RunEffectData in outcome.effects:
			match effect.kind:
				RunEffectData.Kind.GAIN_ITEM:
					if not run.pouch.has(&""):
						return &"pouch_full"
				RunEffectData.Kind.LEARN_MOVE:
					if _loadout_full(run, db.tuning()):
						return &"loadout_full"
				RunEffectData.Kind.ADD_MODIFIER:
					if modifier_targets(run, effect.id, db).is_empty():
						return &"no_target"
	return &""


## Picks [param choice_index] of [param event]: rolls an outcome from [param rng] (the event
## stream) and applies its effects in order. Events never take the cat below 1 HP (D18).
static func choose(
	run: RunState, event: EventData, choice_index: int, db: ContentDb, rng: SeededRng
) -> EventResult:
	var result := EventResult.new()
	if choice_index < 0 or choice_index >= event.choices.size():
		result.reason = &"bad_choice"
		return result
	var choice: EventChoiceData = event.choices[choice_index]
	result.reason = disabled_reason(run, choice, db)
	if result.reason != &"":
		return result
	result.outcome_index = roll_outcome(choice, rng.next_float())
	var outcome: EventOutcomeData = choice.outcomes[result.outcome_index]
	for effect: RunEffectData in outcome.effects:
		_apply(effect, run, db, rng, result)
	result.ok = true
	result.result_text = outcome.result_text
	return result


## The outcome [param roll] (0 to 1) lands on: the first whose running total exceeds it.
static func roll_outcome(choice: EventChoiceData, roll: float) -> int:
	var cumulative: float = 0.0
	for index: int in choice.outcomes.size():
		cumulative += choice.outcomes[index].probability
		if roll < cumulative:
			return index
	return choice.outcomes.size() - 1


## HP the cat ends at after losing [param amount] in an event: never below 1 (D18).
static func hp_after(run: RunState, amount: int) -> int:
	return clampi(run.hp + amount, 1, run.max_hp)


## Moves (equipped then bag index) [param modifier_id] can attach to right now.
static func modifier_targets(run: RunState, modifier_id: StringName, db: ContentDb) -> Array[int]:
	var modifier: ModifierData = db.modifier(modifier_id)
	var targets: Array[int] = []
	if modifier == null:
		return targets
	var owned: Array[MoveInstance] = run.equipped + run.bag
	for index: int in owned.size():
		var instance: MoveInstance = owned[index]
		if (
			RunRules.fits(modifier, db.move(instance.move_id))
			and not instance.modifier_ids.has(modifier_id)
			and instance.modifier_ids.size() < RunRules.MODIFIER_SLOTS
		):
			targets.append(index)
	return targets


## Every broken PRD §10.3 / D35 rule for [param event], one message each.
static func validate_event(event: EventData, db: ContentDb) -> PackedStringArray:
	var problems := PackedStringArray()
	var name: String = String(event.id)
	if _words(event.text) > MAX_TEXT_WORDS:
		problems.append("%s: text over %d words" % [name, MAX_TEXT_WORDS])
	if event.choices.is_empty() or event.choices.size() > MAX_CHOICES:
		problems.append("%s: needs 1-%d choices" % [name, MAX_CHOICES])
	var ids: Array[StringName] = []
	var labels: Array[String] = []
	var has_safe: bool = false
	var has_gamble: bool = false
	for choice: EventChoiceData in event.choices:
		var at: String = "%s/%s" % [name, choice.id]
		if ids.has(choice.id) or labels.has(choice.label):
			problems.append("%s: duplicate id or label" % at)
		ids.append(choice.id)
		labels.append(choice.label)
		if choice.is_safe != (choice.outcomes.size() == 1):
			problems.append("%s: is_safe must mean exactly one outcome" % at)
		has_safe = has_safe or choice.outcomes.size() == 1
		has_gamble = has_gamble or choice.outcomes.size() > 1
		var total: float = 0.0
		for outcome: EventOutcomeData in choice.outcomes:
			total += outcome.probability
			_check_outcome(outcome, at, db, problems)
		if absf(total - 1.0) > PROBABILITY_TOLERANCE:
			problems.append("%s: probabilities sum to %.4f" % [at, total])
		if choice.outcomes.size() > 1:
			for outcome: EventOutcomeData in choice.outcomes:
				if outcome.probability > db.tuning().probability_cap:
					problems.append("%s: an outcome is above the probability cap" % at)
	if not has_safe or not has_gamble:
		problems.append("%s: needs a safe choice and a gamble choice" % name)
	return problems


static func _check_outcome(
	outcome: EventOutcomeData, at: String, db: ContentDb, problems: PackedStringArray
) -> void:
	var words: int = _words(outcome.result_text)
	if words == 0 or words > MAX_RESULT_WORDS:
		problems.append("%s: result_text needs 1-%d words" % [at, MAX_RESULT_WORDS])
	var max_cost: int = floori(db.tuning().cat_max_hp * MAX_HP_COST_PCT / 100.0)
	for effect: RunEffectData in outcome.effects:
		if effect.kind == RunEffectData.Kind.HP and effect.amount < -max_cost:
			problems.append("%s: costs more than %d HP" % [at, max_cost])
		if not _id_exists(effect, db):
			problems.append("%s: unknown id %s" % [at, effect.id])


static func _id_exists(effect: RunEffectData, db: ContentDb) -> bool:
	if effect.id == &"":
		return effect.kind != RunEffectData.Kind.ADD_MODIFIER
	match effect.kind:
		RunEffectData.Kind.GAIN_RELIC:
			return db.relic(effect.id) != null
		RunEffectData.Kind.GAIN_ITEM:
			return db.item(effect.id) != null
		RunEffectData.Kind.LEARN_MOVE:
			return db.move(effect.id) != null
		RunEffectData.Kind.ADD_MODIFIER:
			return db.modifier(effect.id) != null
		RunEffectData.Kind.START_BATTLE:
			return db.enemy(effect.id) != null
	return true


static func _apply(
	effect: RunEffectData, run: RunState, db: ContentDb, rng: SeededRng, result: EventResult
) -> void:
	match effect.kind:
		RunEffectData.Kind.PURRLS:
			run.purrls = maxi(run.purrls + effect.amount, 0)
		RunEffectData.Kind.HP:
			run.hp = hp_after(run, effect.amount)
		RunEffectData.Kind.HP_PCT:
			run.hp = hp_after(run, floori(run.max_hp * effect.amount / 100.0 + 0.5))
		RunEffectData.Kind.MAX_HP:
			run.max_hp += effect.amount
			run.hp += effect.amount
		RunEffectData.Kind.GAIN_RELIC:
			var relic: RelicData = (
				db.relic(effect.id)
				if effect.id != &""
				else ShopRules.pick_relic(
					db.all_relics(), run.relics, ShopRules.RARITY_NAMES[effect.rarity], rng
				)
			)
			if relic != null:
				RunRules.gain_relic(run, relic)
		RunEffectData.Kind.GAIN_ITEM:
			var item_id: StringName = effect.id
			if item_id == &"":
				item_id = RewardRules.drop_item(db.all_items(), rng)
			run.pouch[run.pouch.find(&"")] = item_id
		RunEffectData.Kind.LEARN_MOVE:
			var move_id: StringName = effect.id
			if move_id == &"":
				move_id = _random_move(db, effect.rarity, rng)
			RunRules.learn_move(run, move_id, db.tuning())
		RunEffectData.Kind.ADD_MODIFIER:
			result.modifier_id = effect.id
		RunEffectData.Kind.START_BATTLE:
			result.battle_enemy_id = effect.id
		RunEffectData.Kind.START_NEXT_BATTLE_MP:
			run.next_battle_mp_bonus += effect.amount
		RunEffectData.Kind.NOTHING:
			pass


static func _random_move(db: ContentDb, rarity: int, rng: SeededRng) -> StringName:
	var pool: Array[MoveData] = db.all_moves().filter(
		func(move: MoveData) -> bool: return move.rarity == rarity
	)
	assert(not pool.is_empty(), "no move of rarity %d" % rarity)
	return pool[rng.range_int(0, pool.size() - 1)].id


static func _owns_gamble(run: RunState, db: ContentDb) -> bool:
	for instance: MoveInstance in run.equipped + run.bag:
		if db.move(instance.move_id).category == MoveData.Category.GAMBLE:
			return true
	return false


static func _loadout_full(run: RunState, tuning: TuningData) -> bool:
	return run.equipped.size() >= tuning.equipped_moves and run.bag.size() >= tuning.bag_size


static func _words(text: String) -> int:
	return text.split(" ", false).size()
