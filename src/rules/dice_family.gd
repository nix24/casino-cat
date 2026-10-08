class_name DiceFamily
extends RefCounted
## The Dice family (PRD §6.1): roll the dice, spend rerolls on the ones you pick, keep the best
## dice. Pure: every face comes from ctx.forced or the gamble stream (decisions §D).

const DIE_FACE_MIN: int = 1
const DIE_SIDES: int = 6
## Tier moves reroll dice showing this face or less for Luck (PRD §6.1).
const LUCK_REROLL_MAX_FACE: int = 2


## The Dice data of [param session]'s move. Only Dice moves reach this family.
static func gamble_of(session: GambleSession, ctx: BattleContext) -> DiceGambleData:
	var move: MoveData = ctx.moves[session.move_id]
	var dice: DiceGambleData = move.gamble as DiceGambleData
	assert(dice != null, "move %s has no DiceGambleData" % session.move_id)
	return dice


## Opens the dice gamble: rolls the faces, gives Luck its free rerolls, then waits for a choice.
## Emits DICE_ROLLED, one LUCK_TRIGGERED per reroll, and GAMBLE_AWAITING_CHOICE.
static func start(session: GambleSession, ctx: BattleContext, rng: SeededRng) -> Array[BattleEvent]:
	var dice: DiceGambleData = gamble_of(session, ctx)
	var events: Array[BattleEvent] = []
	var faces: PackedInt32Array = roll_faces(dice.dice_count, session, rng)
	events.append(_dice_event(BattleEvent.Kind.DICE_ROLLED, faces, PackedInt32Array()))
	var chance: float = GambleRules.luck_chance(session.odds.luck)
	for index: int in faces.size():
		# Luck 0 draws nothing, so the gamble stream only moves when Luck can fire.
		if chance > 0.0 and luck_eligible(dice, faces[index]) and rng.chance(chance):
			faces[index] = draw_face(session, rng)
			var indices := PackedInt32Array([index])
			events.append(_dice_event(BattleEvent.Kind.LUCK_TRIGGERED, faces, indices))
	session.faces = faces
	events.append(_awaiting_event(session))
	return events


## Rerolls the chosen dice for one reroll. The caller has run choice_rejection first.
static func choose(
	session: GambleSession, choice: GambleChoice, state: BattleState, rng: SeededRng
) -> Array[BattleEvent]:
	state.rerolls -= 1
	var faces: PackedInt32Array = session.faces
	for index: int in choice.reroll_dice:
		faces[index] = draw_face(session, rng)
	session.faces = faces
	var rerolls_changed := BattleEvent.new(BattleEvent.Kind.REROLLS_CHANGED)
	rerolls_changed.amount = state.rerolls
	var events: Array[BattleEvent] = [rerolls_changed]
	events.append(_dice_event(BattleEvent.Kind.DICE_REROLLED, faces, choice.reroll_dice))
	events.append(_awaiting_event(session))
	return events


## Why [param choice] cannot run on [param session], or &"" if it can. Checked before anything
## changes. An empty choice is Confirm and always runs.
static func choice_rejection(
	session: GambleSession, choice: GambleChoice, state: BattleState
) -> StringName:
	if choice.reroll_dice.is_empty():
		return &""
	if not _are_valid_indices(choice.reroll_dice, session.faces.size()):
		return &"invalid_choice"
	if state.rerolls <= 0:
		return &"no_rerolls"
	return &""


## Next die face: the next forced face if one is queued, otherwise a fair d6 from the gamble
## stream (decisions §D). Forced faces are consumed in order.
static func draw_face(session: GambleSession, rng: SeededRng) -> int:
	if session.forced.is_empty():
		return rng.range_int(DIE_FACE_MIN, DIE_SIDES)
	var face: int = session.forced.pop_front()
	assert(face >= DIE_FACE_MIN and face <= DIE_SIDES, "forced face %d is not a d6 face" % face)
	return face


## [param count] faces for the opening roll, each through draw_face.
static func roll_faces(count: int, session: GambleSession, rng: SeededRng) -> PackedInt32Array:
	var faces := PackedInt32Array()
	for _die: int in count:
		@warning_ignore("return_value_discarded")
		faces.append(draw_face(session, rng))
	return faces


## Whether a die showing [param face] may take a Luck reroll. Tier moves reroll 1s and 2s. Snake
## Eyes is inverted and rerolls every face but its jackpot (PRD §6.1).
static func luck_eligible(dice: DiceGambleData, face: int) -> bool:
	if _is_jackpot(dice):
		return face != dice.jackpot_face
	return face <= LUCK_REROLL_MAX_FACE


## Sum of the [param keep_best] highest faces (PRD §6.1).
static func kept_sum(faces: PackedInt32Array, keep_best: int) -> int:
	var ascending: PackedInt32Array = faces.duplicate()
	ascending.sort()
	var total: int = 0
	for index: int in range(ascending.size() - keep_best, ascending.size()):
		total += ascending[index]
	return total


## The tier whose range covers [param total]. Every kept sum from 2 to 12 has one (PRD §6.1).
static func tier_for_sum(tiers: Array[DiceTierData], total: int) -> DiceTierData:
	for tier: DiceTierData in tiers:
		if total >= tier.min_sum and total <= tier.max_sum:
			return tier
	assert(false, "no tier covers kept sum %d" % total)
	return null


## The row that [param faces] land in: the resolve side of the odds table (PRD §6.0 rule 2). The
## probability is left at 0.
static func score(
	dice: DiceGambleData, faces: PackedInt32Array, luck: int, payout_mult: float, backfire_cap: int
) -> GambleOddsRow:
	if _is_jackpot(dice):
		var hit: bool = faces[0] == dice.jackpot_face
		return _jackpot_row(dice, hit, luck, payout_mult, backfire_cap)
	var tier: DiceTierData = tier_for_sum(dice.tiers, kept_sum(faces, dice.keep_best))
	return _tier_row(dice, tier, luck, payout_mult, backfire_cap)


## Every row of the odds table for [param dice], in table order. Each row's probability adds up
## the chance of every face combination that lands in it (PRD §6.1, gamble-math.md).
static func odds(
	dice: DiceGambleData, luck: int, payout_mult: float, backfire_cap: int
) -> Array[GambleOddsRow]:
	var rows: Array[GambleOddsRow] = _outcome_rows(dice, luck, payout_mult, backfire_cap)
	var chance: float = GambleRules.luck_chance(luck)
	var combinations: int = 1
	for _die: int in dice.dice_count:
		combinations *= DIE_SIDES
	for combination: int in combinations:
		var faces := PackedInt32Array()
		var probability: float = 1.0
		var rest: int = combination
		for _die: int in dice.dice_count:
			var face: int = DIE_FACE_MIN + rest % DIE_SIDES
			rest = floori(float(rest) / DIE_SIDES)
			@warning_ignore("return_value_discarded")
			faces.append(face)
			probability *= _face_chance(dice, face, chance)
		var row: GambleOddsRow = score(dice, faces, luck, payout_mult, backfire_cap)
		rows[_row_index(rows, row.label)].probability += probability
	return rows


## Chance that one die ends on [param face] after its Luck reroll (gamble-math.md). An eligible
## die keeps its face with probability 1 - chance. Any eligible die can reroll into any face.
static func _face_chance(dice: DiceGambleData, face: int, chance: float) -> float:
	var stays: float = 1.0 - chance if luck_eligible(dice, face) else 1.0
	var eligible_faces: int = 0
	for other: int in range(DIE_FACE_MIN, DIE_SIDES + 1):
		if luck_eligible(dice, other):
			eligible_faces += 1
	return stays / DIE_SIDES + eligible_faces * chance / (DIE_SIDES * DIE_SIDES)


## The table's rows in order, each at probability 0. odds() fills them in by label.
static func _outcome_rows(
	dice: DiceGambleData, luck: int, payout_mult: float, backfire_cap: int
) -> Array[GambleOddsRow]:
	var rows: Array[GambleOddsRow] = []
	if _is_jackpot(dice):
		rows.append(_jackpot_row(dice, true, luck, payout_mult, backfire_cap))
		rows.append(_jackpot_row(dice, false, luck, payout_mult, backfire_cap))
		return rows
	for tier: DiceTierData in dice.tiers:
		rows.append(_tier_row(dice, tier, luck, payout_mult, backfire_cap))
	return rows


static func _row_index(rows: Array[GambleOddsRow], label: StringName) -> int:
	for index: int in rows.size():
		if rows[index].label == label:
			return index
	assert(false, "no odds row labelled %s" % label)
	return -1


static func _tier_row(
	dice: DiceGambleData, tier: DiceTierData, luck: int, payout_mult: float, backfire_cap: int
) -> GambleOddsRow:
	return (
		GambleRules
		. outcome_row(
			tier.label,
			dice.base_damage,
			tier.multiplier,
			tier.backfire,
			tier.due_step,
			luck,
			payout_mult,
			backfire_cap,
		)
	)


## Snake Eyes: the jackpot face pays jackpot_damage and empties Due. Every other face pays
## base_damage and adds a pip (decisions D19).
static func _jackpot_row(
	dice: DiceGambleData, is_jackpot: bool, luck: int, payout_mult: float, backfire_cap: int
) -> GambleOddsRow:
	if is_jackpot:
		return (
			GambleRules
			. outcome_row(
				&"Jackpot",
				dice.jackpot_damage,
				1.0,
				0,
				GambleData.DueStep.TOP,
				luck,
				payout_mult,
				backfire_cap,
			)
		)
	return (
		GambleRules
		. outcome_row(
			&"Plain",
			dice.base_damage,
			1.0,
			0,
			GambleData.DueStep.BOTTOM,
			luck,
			payout_mult,
			backfire_cap,
		)
	)


static func _is_jackpot(dice: DiceGambleData) -> bool:
	return dice.jackpot_face > 0


static func _are_valid_indices(indices: PackedInt32Array, dice_count: int) -> bool:
	var seen: Array[int] = []
	for index: int in indices:
		if index < 0 or index >= dice_count or seen.has(index):
			return false
		seen.append(index)
	return true


static func _dice_event(
	kind: BattleEvent.Kind, faces: PackedInt32Array, indices: PackedInt32Array
) -> BattleEvent:
	var event := BattleEvent.new(kind)
	event.gamble = GambleEventData.new()
	event.gamble.faces = faces
	event.gamble.indices = indices
	return event


static func _awaiting_event(session: GambleSession) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.GAMBLE_AWAITING_CHOICE)
	event.reason = session.family
	return event
