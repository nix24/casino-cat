class_name BattleRules
extends RefCounted
## Turn resolution for battles (PRD §4, §7). Each call updates the state and returns the
## BattleEvents in play order. The presentation plays them; the rules never animate.
## Architecture §3 lists the steps; resolutions R1-R12 in T001 are binding where they differ.
## Gamble moves (T002, R8) open a GambleSession in state.pending and finish on a GAMBLE_CHOICE.

## Regen heals this much at the end of each turn (content-registry, status regen).
const REGEN_HEAL: int = 3
## A discounted move never costs less than this (Cheap, PRD §8.1). Free moves stay free.
const MIN_DISCOUNTED_MP_COST: int = 5


## Opens a battle against [param enemy]. The cat starts at the run's HP (full when [param ctx]
## carries none) and CLUBS, with the loadout from [param ctx]. Returns the state and the
## BATTLE_STARTED, BATTLE_START relic events, TURN_STARTED, INTENT_SHOWN events. [param _rng] is
## unused until a battle rule needs randomness.
static func start(enemy: EnemyData, ctx: BattleContext, _rng: SeededRng) -> BattleStart:
	assert(not enemy.pattern.is_empty(), "every enemy needs at least one intent")
	var state := BattleState.new()
	state.cat.max_hp = ctx.cat_max_hp if ctx.cat_max_hp > 0 else ctx.tuning.cat_max_hp
	state.cat.hp = ctx.cat_hp if ctx.cat_hp > 0 else state.cat.max_hp
	state.cat.suit = Suit.Type.CLUBS
	state.enemy.max_hp = enemy.max_hp
	state.enemy.hp = enemy.max_hp
	state.enemy.suit = enemy.suit
	state.enemy_data = enemy
	state.mp = ctx.tuning.mp_battle_start
	state.equipped = ctx.loadout.duplicate()
	state.next_intent = enemy.pattern[0]
	state.rerolls = ctx.tuning.dice_rerolls_per_battle

	var opening := BattleStart.new()
	opening.state = state
	opening.events.append(BattleEvent.new(BattleEvent.Kind.BATTLE_STARTED))
	_battle_start_hooks(state, ctx, opening.events)
	opening.events.append(_turn_started_event(state.turn))
	opening.events.append(_intent_shown_event(state.next_intent))
	return opening


## Resolves one player action and the enemy's reply. A rejected action returns a single
## ACTION_REJECTED and changes nothing.
static func apply(
	state: BattleState, action: PlayerAction, ctx: BattleContext, rngs: RngSet
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	state.cat.hp_floor = 1 if ctx.god_mode else 0
	var rejection: StringName = _rejection_reason(state, action, ctx)
	if rejection != &"":
		events.append(_rejected(rejection))
		return events

	if action.kind == PlayerAction.Kind.GAMBLE_CHOICE:
		return _gamble_choice(state, action.gamble_choice, ctx, rngs.gamble)
	if action.kind == PlayerAction.Kind.USE_ITEM:
		return _use_item(state, action, ctx)

	var move: MoveData = _move_for_slot(state, action.slot, ctx)
	var instance: MoveInstance = state.equipped[action.slot]
	state.acting_slot = action.slot
	var move_event := BattleEvent.new(BattleEvent.Kind.MOVE_USED)
	move_event.move_id = move.id
	events.append(move_event)
	var cost: int = _mp_cost(state, move, instance, ctx)
	_change_mp(state, ctx.tuning, BattleEvent.Actor.CAT, &"cost", -cost, events)
	if move.category == MoveData.Category.BASIC:
		events.append_array(
			(
				Hooks
				. collect(HookData.Trigger.BEFORE_MOVE, state, ctx, _move_context(move, instance))
				. events
			)
		)

	state.repeat_count = _next_repeat_count(state, move)
	state.last_move_id = move.id
	if move.category == MoveData.Category.GAMBLE:
		return _open_gamble(state, move, ctx, rngs.gamble, events)
	_resolve_move(state, move, ctx, events)
	return _resolve_turn(state, move, ctx, events)


## What a move would do right now. Damage matches the DAMAGE_DEALT amounts apply() would emit
## for the same slot (R9).
static func preview_move(state: BattleState, slot: int, ctx: BattleContext) -> MovePreview:
	assert(slot >= 0 and slot < state.equipped.size(), "slot %d is not equipped" % slot)
	var move: MoveData = _move_for_slot(state, slot, ctx)
	var instance: MoveInstance = state.equipped[slot]
	var preview := MovePreview.new()
	preview.mp_cost = _mp_cost(state, move, instance, ctx)
	preview.affordable = preview.mp_cost <= state.mp
	preview.missing_mp = maxi(preview.mp_cost - state.mp, 0)
	if move.category == MoveData.Category.BASIC:
		var repeat_count: int = _next_repeat_count(state, move)
		preview.hits = move.hits
		preview.triangle_mult = Suit.damage_multiplier(suit_of(move, instance), state.enemy.suit)
		preview.damage = _player_hit_amount(state, move, instance, repeat_count, ctx) * move.hits
	elif move.category == MoveData.Category.GAMBLE:
		preview.odds = GambleRules.preview(move.gamble, state, ctx)
	if state.next_intent.kind == IntentData.Kind.ATTACK:
		var suit_after: Suit.Type = _suit_after_move(state, move, instance, ctx.tuning)
		preview.incoming_mult = Suit.damage_multiplier(state.enemy.suit, suit_after)
	return preview


# --- player action -----------------------------------------------------------------------------


## Why [param action] can't run right now, or &"" if it can. Checked before anything changes.
static func _rejection_reason(
	state: BattleState, action: PlayerAction, ctx: BattleContext
) -> StringName:
	if action.kind == PlayerAction.Kind.GAMBLE_CHOICE:
		if state.pending == null:
			return &"no_gamble_pending"
		return DiceFamily.choice_rejection(state.pending, action.gamble_choice, state)
	if state.outcome != BattleState.Outcome.ONGOING:
		return &"battle_over"
	if action.kind == PlayerAction.Kind.USE_ITEM:
		return _item_rejection(state, action, ctx)
	if state.pending != null:
		return &"gamble_pending"
	if action.slot < 0 or action.slot >= state.equipped.size():
		return &"invalid_slot"
	var move: MoveData = _move_for_slot(state, action.slot, ctx)
	if _mp_cost(state, move, state.equipped[action.slot], ctx) > state.mp:
		return &"not_affordable"
	return &""


## Why the item in [param action]'s pouch slot can't be used now, or &"" (PRD §8.3).
static func _item_rejection(
	state: BattleState, action: PlayerAction, ctx: BattleContext
) -> StringName:
	if state.pending != null:
		return &"pending"
	var slot: int = action.pouch_slot
	if slot < 0 or slot >= ctx.pouch.size() or ctx.pouch[slot] == &"":
		return &"empty_slot"
	if state.last_item_turn == state.turn:
		return &"item_already_used"
	for effect: EffectData in ctx.items[ctx.pouch[slot]].effects:
		match effect.kind:
			EffectData.Kind.FLEE:
				if state.enemy_data.tier != EnemyData.Tier.NORMAL:
					return &"smoke_bomb_not_normal"
			EffectData.Kind.SET_ENEMY_SUIT:
				if action.choice < 0 or action.choice >= Suit.Type.size():
					return &"bad_suit"
	return &""


## Uses one pouch item (PRD §8.3): ITEM_USED, then each effect in order. It never ends the turn,
## so the enemy doesn't act. Smoke Bomb ends the battle as FLED.
static func _use_item(
	state: BattleState, action: PlayerAction, ctx: BattleContext
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var item_id: StringName = ctx.pouch[action.pouch_slot]
	var item: ItemData = ctx.items[item_id]
	ctx.pouch[action.pouch_slot] = &""
	state.last_item_turn = state.turn
	var used := BattleEvent.new(BattleEvent.Kind.ITEM_USED)
	used.reason = item_id
	used.amount = action.pouch_slot
	events.append(used)
	for effect: EffectData in item.effects:
		if effect.kind == EffectData.Kind.FLEE:
			return _finish(state, BattleState.Outcome.FLED, BattleEvent.Kind.FLED, events)
		_item_effect(effect, state, action.choice, ctx.tuning, events)
	return events


static func _item_effect(
	effect: EffectData,
	state: BattleState,
	choice: int,
	tuning: TuningData,
	events: Array[BattleEvent]
) -> void:
	match effect.kind:
		EffectData.Kind.HEAL:
			_heal(state.cat, BattleEvent.Actor.CAT, effect.amount, &"item", events)
		EffectData.Kind.MP_GAIN:
			_change_mp(state, tuning, BattleEvent.Actor.CAT, &"item", effect.amount, events)
		EffectData.Kind.SHIELD:
			_gain_shield(state.cat, BattleEvent.Actor.CAT, effect.amount, tuning, events)
		EffectData.Kind.CLEANSE:
			for status: StringName in state.cat.statuses.keys():
				state.cat.statuses.erase(status)
				var cleansed := BattleEvent.new(BattleEvent.Kind.STATUS_CLEANSED)
				cleansed.status = status
				events.append(cleansed)
			state.cat.statuses_fresh.clear()
		EffectData.Kind.ADD_REROLLS:
			state.rerolls += effect.amount
			var rerolls_changed := BattleEvent.new(BattleEvent.Kind.REROLLS_CHANGED)
			rerolls_changed.amount = state.rerolls
			events.append(rerolls_changed)
		EffectData.Kind.FLAT_DAMAGE_NEXT_MOVE:
			state.cat.flat_damage_bonus += effect.amount
		EffectData.Kind.WEAKEN_NEXT_INTENT:
			state.weaken_next_attack_pct = effect.amount
		EffectData.Kind.GUARANTEE_TOP_TIER:
			state.guarantee_top_tier = true
		EffectData.Kind.SET_ENEMY_SUIT:
			if state.suit_override_turns == 0:
				state.suit_before_override = state.enemy.suit
			state.suit_override_turns = effect.turns
			_shift_enemy_suit(state, choice as Suit.Type, events)
		_:
			assert(false, "item effect kind %d is not implemented" % effect.kind)


static func _shift_enemy_suit(
	state: BattleState, suit: Suit.Type, events: Array[BattleEvent]
) -> void:
	var shifted: BattleEvent = _suit_shifted_event(state.enemy.suit, suit)
	shifted.actor = BattleEvent.Actor.ENEMY
	shifted.target = BattleEvent.Actor.ENEMY
	state.enemy.suit = suit
	events.append(shifted)


static func _move_for_slot(state: BattleState, slot: int, ctx: BattleContext) -> MoveData:
	var instance: MoveInstance = state.equipped[slot]
	var move: MoveData = ctx.moves[instance.move_id]
	return move


## Repeat tracker (PRD §4.4). Only basic moves stack. Any other use starts a new streak at 1.
static func _next_repeat_count(state: BattleState, move: MoveData) -> int:
	if move.category == MoveData.Category.BASIC and move.id == state.last_move_id:
		return state.repeat_count + 1
	return 1


## Basic moves hit for their damage, one hit per `hits`. Then the effects run in order.
static func _resolve_move(
	state: BattleState, move: MoveData, ctx: BattleContext, events: Array[BattleEvent]
) -> void:
	var tuning: TuningData = ctx.tuning
	if move.category == MoveData.Category.BASIC:
		var instance: MoveInstance = state.equipped[state.acting_slot]
		var amount: int = _player_hit_amount(state, move, instance, state.repeat_count, ctx)
		for _hit: int in move.hits:
			_deal_damage(state.enemy, BattleEvent.Actor.CAT, amount, events)
			if state.enemy.hp <= 0:
				break
	for effect: EffectData in move.effects:
		_resolve_effect(effect, state, tuning, events)


static func _resolve_effect(
	effect: EffectData, state: BattleState, tuning: TuningData, events: Array[BattleEvent]
) -> void:
	var recipient: Combatant = (
		state.enemy if effect.target == EffectData.Target.ENEMY else state.cat
	)
	match effect.kind:
		EffectData.Kind.SHIELD:
			_gain_shield(recipient, BattleEvent.Actor.CAT, effect.amount, tuning, events)
		EffectData.Kind.HEAL:
			_heal(recipient, BattleEvent.Actor.CAT, effect.amount, &"", events)
		EffectData.Kind.MP_GAIN:
			# Charged at end of turn with the other MP, so it lands after ENEMY_ACTED (PRD §7).
			pass
		EffectData.Kind.STATUS:
			_apply_status(recipient, effect.status, effect.turns, BattleEvent.Actor.CAT, events)
		_:
			assert(false, "effect kind %d is not implemented in T001" % effect.kind)


## Per-hit damage for a basic move of the cat, using the repeat count for this use. BEFORE_MOVE
## hooks add flat damage and multipliers before the triangle and repeat penalty (arch §4).
static func _player_hit_amount(
	state: BattleState,
	move: MoveData,
	instance: MoveInstance,
	repeat_count: int,
	ctx: BattleContext
) -> int:
	var hooks: HookResult = Hooks.collect(
		HookData.Trigger.BEFORE_MOVE, state, ctx, _move_context(move, instance)
	)
	return (
		Damage
		. hit_amount(
			move.base_damage,
			state.cat.flat_damage_bonus + hooks.flat_damage,
			Suit.damage_multiplier(suit_of(move, instance), state.enemy.suit),
			Damage.repeat_multiplier(repeat_count, ctx.tuning, state.repeat_shift),
			state.cat.statuses.has(&"weak"),
			state.enemy.statuses.has(&"exposed"),
			hooks.damage_mult_pct / 100.0,
		)
	)


## The suit [param move] attacks with: Re-suited's choice when attached, else its own (PRD §8.1).
static func suit_of(move: MoveData, instance: MoveInstance) -> Suit.Type:
	if instance != null and instance.suit_override >= 0:
		return instance.suit_override as Suit.Type
	return move.suit


## [param cost] after a discount [param delta] (negative). Never below MIN_DISCOUNTED_MP_COST,
## and a free move stays free.
static func discounted_cost(cost: int, delta: int) -> int:
	if cost <= 0 or delta == 0:
		return cost
	return maxi(cost + delta, mini(cost, MIN_DISCOUNTED_MP_COST))


## Type-shift (PRD §4.3). A move of another suit makes that suit the cat's suit. With the
## shift disabled the cat stays CLUBS.
static func _suit_after_move(
	state: BattleState, move: MoveData, instance: MoveInstance, tuning: TuningData
) -> Suit.Type:
	if tuning.type_shift_enabled:
		return suit_of(move, instance)
	return state.cat.suit


## MP the move costs this turn, after modifiers such as Cheap.
static func _mp_cost(
	state: BattleState, move: MoveData, instance: MoveInstance, ctx: BattleContext
) -> int:
	var hooks: HookResult = Hooks.collect(
		HookData.Trigger.BEFORE_MOVE, state, ctx, _move_context(move, instance)
	)
	return discounted_cost(move.mp_cost, hooks.mp_cost_delta)


static func _move_context(move: MoveData, instance: MoveInstance) -> HookContext:
	var hook_ctx := HookContext.new()
	hook_ctx.move = move
	hook_ctx.move_instance = instance
	if move.gamble != null:
		hook_ctx.family = move.gamble.family
	return hook_ctx


## BATTLE_START hooks (T013): relic events, then extra rerolls, then the opening shield.
static func _battle_start_hooks(
	state: BattleState, ctx: BattleContext, events: Array[BattleEvent]
) -> void:
	var hooks: HookResult = Hooks.collect(
		HookData.Trigger.BATTLE_START, state, ctx, HookContext.new()
	)
	events.append_array(hooks.events)
	state.repeat_shift = hooks.repeat_shift
	if hooks.rerolls > 0:
		state.rerolls += hooks.rerolls
		var rerolls_changed := BattleEvent.new(BattleEvent.Kind.REROLLS_CHANGED)
		rerolls_changed.amount = state.rerolls
		events.append(rerolls_changed)
	if hooks.shield > 0:
		_gain_shield(state.cat, BattleEvent.Actor.CAT, hooks.shield, ctx.tuning, events)


## AFTER_MOVE and ON_DAMAGE_DEALT hooks for the move that just resolved. Shield and heal land now;
## the returned MP joins the move's own MP at the end of the turn (PRD §7).
static func _after_move_hooks(
	state: BattleState, move: MoveData, ctx: BattleContext, events: Array[BattleEvent]
) -> int:
	var instance: MoveInstance = state.equipped[state.acting_slot]
	var hook_ctx: HookContext = _move_context(move, instance)
	var after: HookResult = Hooks.collect(HookData.Trigger.AFTER_MOVE, state, ctx, hook_ctx)
	events.append_array(after.events)
	if after.shield > 0:
		_gain_shield(state.cat, BattleEvent.Actor.CAT, after.shield, ctx.tuning, events)
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.CAT:
			hook_ctx.damage += event.amount - event.absorbed
	if hook_ctx.damage > 0:
		var dealt: HookResult = Hooks.collect(
			HookData.Trigger.ON_DAMAGE_DEALT, state, ctx, hook_ctx
		)
		events.append_array(dealt.events)
		var heal: int = floori(hook_ctx.damage * dealt.heal / 100.0 + 0.5)
		if heal > 0:
			_heal(state.cat, BattleEvent.Actor.CAT, heal, &"", events)
	return after.gain_mp


# --- turn tail and gambles ---------------------------------------------------------------------


## Everything after the move's own resolution: type-shift, win and lose checks, enemy action, and
## end of turn. Basic, utility, and gamble moves all finish here.
static func _resolve_turn(
	state: BattleState, move: MoveData, ctx: BattleContext, events: Array[BattleEvent]
) -> Array[BattleEvent]:
	var hook_mp: int = _after_move_hooks(state, move, ctx, events)
	# Sardine Tin's bonus lasts for one move (PRD §8.3).
	state.cat.flat_damage_bonus = 0
	var instance: MoveInstance = state.equipped[state.acting_slot]
	var suit_after: Suit.Type = _suit_after_move(state, move, instance, ctx.tuning)
	if suit_after != state.cat.suit:
		events.append(_suit_shifted_event(state.cat.suit, suit_after))
		state.cat.suit = suit_after

	# A win ends the turn before the enemy acts and before any end-of-turn MP is charged.
	if state.enemy.hp <= 0:
		return _finish(state, BattleState.Outcome.WON, BattleEvent.Kind.BATTLE_WON, events)
	# Backfire can take the cat to 0 before the enemy acts (PRD §6.0 rule 8).
	if state.cat.hp <= 0:
		return _finish(state, BattleState.Outcome.LOST, BattleEvent.Kind.BATTLE_LOST, events)
	_enemy_acts(state, ctx.tuning, events)
	if state.cat.hp <= 0:
		return _finish(state, BattleState.Outcome.LOST, BattleEvent.Kind.BATTLE_LOST, events)
	_end_turn(state, move, ctx.tuning, hook_mp, events)
	return events


## Opens a gamble (PRD §6.0 rule 2). The odds are snapshotted, the queued forced faces move into the
## session, and the family rolls. The turn waits in state.pending for a GAMBLE_CHOICE.
static func _open_gamble(
	state: BattleState,
	move: MoveData,
	ctx: BattleContext,
	rng: SeededRng,
	events: Array[BattleEvent]
) -> Array[BattleEvent]:
	assert(move.gamble != null, "gamble move %s has no gamble data" % move.id)
	var session := GambleSession.new()
	session.move_id = move.id
	session.family = move.gamble.family
	session.odds = GambleRules.preview(move.gamble, state, ctx)
	session.forced = ctx.forced.duplicate()
	ctx.forced.clear()
	if state.guarantee_top_tier:
		# Lucky Charm: the faces of the top tier, shown in the preview at 100% (PRD §8.3).
		session.forced = DiceFamily.top_tier_faces(move.gamble as DiceGambleData)
		state.guarantee_top_tier = false
	state.pending = session

	var preview_ctx := HookContext.new()
	preview_ctx.family = session.family
	events.append_array(
		Hooks.collect(HookData.Trigger.GAMBLE_PREVIEW, state, ctx, preview_ctx).events
	)
	var started := BattleEvent.new(BattleEvent.Kind.GAMBLE_STARTED)
	started.gamble = GambleEventData.new()
	started.gamble.odds = session.odds
	events.append(started)
	events.append_array(DiceFamily.start(session, ctx, rng))
	return events


## A GAMBLE_CHOICE with dice listed rerolls them. An empty choice keeps the faces and resolves.
static func _gamble_choice(
	state: BattleState, choice: GambleChoice, ctx: BattleContext, rng: SeededRng
) -> Array[BattleEvent]:
	if choice.reroll_dice.is_empty():
		return _keep_gamble(state, ctx)
	return DiceFamily.choose(state.pending, choice, state, rng)


## Resolves the held faces. The payout and backfire come from the same row the odds table showed
## (PRD §6.0 rule 2), then the turn's shared tail runs.
static func _keep_gamble(state: BattleState, ctx: BattleContext) -> Array[BattleEvent]:
	var session: GambleSession = state.pending
	var move: MoveData = ctx.moves[session.move_id]
	var dice: DiceGambleData = DiceFamily.gamble_of(session, ctx)
	var row: GambleOddsRow = DiceFamily.score(
		dice,
		session.faces,
		session.odds.luck,
		GambleRules.status_mult(state),
		GambleRules.backfire_cap(state, ctx)
	)
	session.tier = row.label
	session.damage = row.payout
	session.backfire = row.backfire
	session.finished = true
	state.pending = null

	var events: Array[BattleEvent] = []
	var resolved := BattleEvent.new(BattleEvent.Kind.GAMBLE_RESOLVED)
	resolved.amount = row.payout
	resolved.gamble = GambleEventData.new()
	resolved.gamble.tier = row.label
	resolved.gamble.payout = row.payout
	events.append(resolved)
	if row.payout > 0:
		_deal_damage(state.enemy, BattleEvent.Actor.CAT, row.payout, events)
	if row.backfire > 0:
		_backfire(state.cat, row.backfire, events)
	_settle_due(session.family, row.due_step, ctx, events)
	return _resolve_turn(state, move, ctx, events)


## Backfire skips the shield and comes straight out of HP (PRD §6.0 rule 8, decisions D17).
static func _backfire(target: Combatant, amount: int, events: Array[BattleEvent]) -> void:
	target.hp = maxi(target.hp - amount, target.hp_floor)
	var event := BattleEvent.new(BattleEvent.Kind.BACKFIRE)
	event.target = target.side
	event.amount = amount
	event.value_after = target.hp
	events.append(event)


## Moves the family's Due meter for one outcome (PRD §6.0 rule 7). DUE_CHANGED is emitted only when
## the pips change.
static func _settle_due(
	family: StringName, due_step: GambleData.DueStep, ctx: BattleContext, events: Array[BattleEvent]
) -> void:
	var pips_before: int = ctx.due.get(family, 0)
	var pips_after: int = GambleRules.due_after(pips_before, due_step, ctx.tuning)
	if pips_after == pips_before:
		return
	ctx.due[family] = pips_after
	var event := BattleEvent.new(BattleEvent.Kind.DUE_CHANGED)
	event.reason = family
	event.amount = pips_after
	events.append(event)


# --- enemy action ------------------------------------------------------------------------------


## The enemy performs the intent it showed at the end of last turn, unless an HP override replaces
## it (T018); the override is announced with its own INTENT_SHOWN first.
static func _enemy_acts(state: BattleState, tuning: TuningData, events: Array[BattleEvent]) -> void:
	var intent: IntentData = state.next_intent
	var override: IntentOverrideData = EnemyIntents.due_override(state)
	state.override_acted = override != null
	if override != null:
		intent = override.intent
		events.append(_intent_shown_event(intent))
	var acted := BattleEvent.new(BattleEvent.Kind.ENEMY_ACTED, BattleEvent.Actor.ENEMY)
	acted.reason = _intent_kind_name(intent.kind)
	events.append(acted)
	match intent.kind:
		IntentData.Kind.ATTACK, IntentData.Kind.MULTI_ATTACK:
			_enemy_attacks(state, intent, events)
		IntentData.Kind.BUFF:
			state.enemy.flat_damage_bonus += intent.amount
		IntentData.Kind.HEAL:
			_heal(state.enemy, BattleEvent.Actor.ENEMY, intent.amount, &"", events)
		IntentData.Kind.SPECIAL:
			_enemy_special(state, intent, events)
		IntentData.Kind.GUARD:
			_gain_shield(state.enemy, BattleEvent.Actor.ENEMY, intent.amount, tuning, events)
		IntentData.Kind.DEBUFF:
			_apply_status(state.cat, intent.status, intent.turns, BattleEvent.Actor.ENEMY, events)
		IntentData.Kind.STEAL_MP:
			var stolen: int = mini(intent.amount, state.mp)
			_change_mp(state, tuning, BattleEvent.Actor.ENEMY, &"steal", -stolen, events)
		_:
			assert(false, "intent kind %s is not implemented in T001" % acted.reason)


## Special intents (PRD §9.3). Cheat (Card Sharp Weasel): the enemy takes the suit that beats the
## cat's current suit until the end of the next turn. Nothing beats ♣, so it does nothing then.
static func _enemy_special(
	state: BattleState, intent: IntentData, events: Array[BattleEvent]
) -> void:
	match intent.special_id:
		EnemyIntents.CHEAT_SUIT:
			var counter: int = EnemyIntents.counter_suit(state.cat.suit)
			if counter < 0 or counter == state.enemy.suit:
				return
			if state.suit_override_turns == 0:
				state.suit_before_override = state.enemy.suit
			state.suit_override_turns = EnemyIntents.CHEAT_TURNS
			_shift_enemy_suit(state, counter as Suit.Type, events)
		_:
			assert(false, "special intent %s is not implemented" % intent.special_id)


## Enemy attacks are never repeat-penalised. The cat's suit is the one after this turn's shift.
static func _enemy_attacks(
	state: BattleState, intent: IntentData, events: Array[BattleEvent]
) -> void:
	var base: int = intent.amount
	if state.weaken_next_attack_pct > 0:
		# Ball of Yarn: this attack only, rounded down (PRD §8.3).
		base = floori(intent.amount * state.weaken_next_attack_pct / 100.0)
		state.weaken_next_attack_pct = 0
	var amount: int = (
		Damage
		. hit_amount(
			base,
			state.enemy.flat_damage_bonus,
			Suit.damage_multiplier(state.enemy.suit, state.cat.suit),
			1.0,
			state.enemy.statuses.has(&"weak"),
			state.cat.statuses.has(&"exposed"),
		)
	)
	for _hit: int in intent.hits:
		_deal_damage(state.cat, BattleEvent.Actor.ENEMY, amount, events)
		if state.cat.hp <= 0:
			return


# --- end of turn -------------------------------------------------------------------------------


## Regen, then status ticks, then MP (R6). Heal comes before the tick, so Regen 3 heals exactly
## three times. MP is charged last, from this turn's hits and move effects.
static func _end_turn(
	state: BattleState, move: MoveData, tuning: TuningData, hook_mp: int, events: Array[BattleEvent]
) -> void:
	_regen(state.cat, BattleEvent.Actor.CAT, events)
	_regen(state.enemy, BattleEvent.Actor.ENEMY, events)
	_tick_statuses(state.cat, BattleEvent.Actor.CAT, events)
	_tick_statuses(state.enemy, BattleEvent.Actor.ENEMY, events)
	state.cat.statuses_fresh.clear()
	state.enemy.statuses_fresh.clear()
	if state.suit_override_turns > 0:
		state.suit_override_turns -= 1
		if state.suit_override_turns == 0:
			events.append(BattleEvent.new(BattleEvent.Kind.SUIT_OVERRIDE_EXPIRED))
			_shift_enemy_suit(state, state.suit_before_override, events)

	var dealt: int = _mp_from_hits(events, BattleEvent.Actor.CAT, tuning.mp_per_damage_dealt)
	_change_mp(state, tuning, BattleEvent.Actor.CAT, &"dealt", dealt, events)
	var taken: int = _mp_from_hits(events, BattleEvent.Actor.ENEMY, tuning.mp_per_damage_taken)
	taken += _mp_from_backfire(events, tuning.mp_per_damage_taken)
	_change_mp(state, tuning, BattleEvent.Actor.CAT, &"taken", taken, events)
	_change_mp(state, tuning, BattleEvent.Actor.CAT, &"move", _move_mp_gain(move) + hook_mp, events)

	# An override took this turn's action, so the replaced pattern step comes up again (T018).
	if not state.override_acted:
		state.intent_index = (state.intent_index + 1) % state.enemy_data.pattern.size()
	state.override_acted = false
	state.next_intent = state.enemy_data.pattern[state.intent_index]
	state.turn += 1
	events.append(_turn_started_event(state.turn))
	events.append(_intent_shown_event(state.next_intent))


static func _regen(target: Combatant, actor: BattleEvent.Actor, events: Array[BattleEvent]) -> void:
	if not target.statuses.has(&"regen") or target.statuses_fresh.has(&"regen"):
		return
	_heal(target, actor, REGEN_HEAL, &"regen", events)


## Ticks every non-fresh status down one turn. Dictionary order keeps the event order stable.
static func _tick_statuses(
	target: Combatant, actor: BattleEvent.Actor, events: Array[BattleEvent]
) -> void:
	for status: StringName in target.statuses.keys():
		if target.statuses_fresh.has(status):
			continue
		var turns_left: int = target.statuses[status] - 1
		var event: BattleEvent
		if turns_left <= 0:
			target.statuses.erase(status)
			event = BattleEvent.new(BattleEvent.Kind.STATUS_EXPIRED, actor)
		else:
			target.statuses[status] = turns_left
			event = BattleEvent.new(BattleEvent.Kind.STATUS_TICKED, actor)
		event.target = target.side
		event.status = status
		event.turns = maxi(turns_left, 0)
		events.append(event)


## MP from hits by [param attacker]: each hit's HP damage times [param rate], floored. Damage the
## shield absorbed earns nothing (decision D13).
static func _mp_from_hits(
	events: Array[BattleEvent], attacker: BattleEvent.Actor, rate: float
) -> int:
	var total: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == attacker:
			total += floori(float(event.amount - event.absorbed) * rate)
	return total


## MP from backfire the cat took this turn. Backfire is damage taken (decisions D17).
static func _mp_from_backfire(events: Array[BattleEvent], rate: float) -> int:
	var total: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.BACKFIRE:
			total += floori(float(event.amount) * rate)
	return total


static func _move_mp_gain(move: MoveData) -> int:
	var total: int = 0
	for effect: EffectData in move.effects:
		if effect.kind == EffectData.Kind.MP_GAIN:
			total += effect.amount
	return total


# --- shared mutations --------------------------------------------------------------------------


## One hit on [param target]. The shield takes its part first; the event records both halves.
static func _deal_damage(
	target: Combatant, actor: BattleEvent.Actor, amount: int, events: Array[BattleEvent]
) -> void:
	var absorbed: int = Damage.absorb(target, amount)
	var event := BattleEvent.new(BattleEvent.Kind.DAMAGE_DEALT, actor)
	event.target = target.side
	event.amount = amount
	event.absorbed = absorbed
	event.value_after = target.hp
	event.shield_after = target.shield
	events.append(event)


## Adds shield up to the cap. Emits even when the cap leaves nothing to add, so the UI can show
## that the shield is full.
static func _gain_shield(
	target: Combatant,
	actor: BattleEvent.Actor,
	amount: int,
	tuning: TuningData,
	events: Array[BattleEvent]
) -> void:
	var shield_before: int = target.shield
	target.shield = mini(shield_before + amount, tuning.shield_cap)
	var event := BattleEvent.new(BattleEvent.Kind.SHIELD_GAINED, actor)
	event.target = target.side
	event.amount = target.shield - shield_before
	event.value_after = target.shield
	event.shield_after = target.shield
	events.append(event)


static func _heal(
	target: Combatant,
	actor: BattleEvent.Actor,
	amount: int,
	reason: StringName,
	events: Array[BattleEvent]
) -> void:
	var hp_before: int = target.hp
	target.hp = mini(hp_before + amount, target.max_hp)
	var gained: int = target.hp - hp_before
	if gained == 0:
		return
	var event := BattleEvent.new(BattleEvent.Kind.HEALED, actor)
	event.target = target.side
	event.amount = gained
	event.value_after = target.hp
	event.reason = reason
	events.append(event)


## Applies a status. Refreshes to the longer duration (PRD §4.7). The status is fresh, so it skips
## this turn's tick (decision D14) but takes effect immediately.
static func _apply_status(
	target: Combatant,
	status: StringName,
	turns: int,
	actor: BattleEvent.Actor,
	events: Array[BattleEvent]
) -> void:
	var current: int = target.statuses.get(status, 0)
	var turns_after: int = maxi(current, turns)
	target.statuses[status] = turns_after
	if not target.statuses_fresh.has(status):
		target.statuses_fresh.append(status)
	var event := BattleEvent.new(BattleEvent.Kind.STATUS_APPLIED, actor)
	event.target = target.side
	event.status = status
	event.turns = turns_after
	events.append(event)


## Moves MP by [param amount] (signed) and clamps the result to 0..mp_max. A zero change emits
## nothing. The event keeps the intended amount; value_after is the clamped result.
static func _change_mp(
	state: BattleState,
	tuning: TuningData,
	actor: BattleEvent.Actor,
	reason: StringName,
	amount: int,
	events: Array[BattleEvent]
) -> void:
	var mp_before: int = state.mp
	state.mp = clampi(state.mp + amount, 0, tuning.mp_max)
	if state.mp == mp_before:
		return
	var event := BattleEvent.new(BattleEvent.Kind.MP_CHANGED, actor)
	event.reason = reason
	# The change that happened, so a gain clipped at max MP shows what the cat really got.
	event.amount = state.mp - mp_before
	event.value_after = state.mp
	events.append(event)


static func _finish(
	state: BattleState,
	outcome: BattleState.Outcome,
	kind: BattleEvent.Kind,
	events: Array[BattleEvent]
) -> Array[BattleEvent]:
	state.outcome = outcome
	events.append(BattleEvent.new(kind))
	return events


# --- event builders ----------------------------------------------------------------------------


static func _rejected(reason: StringName) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.ACTION_REJECTED)
	event.reason = reason
	return event


static func _turn_started_event(turn: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.amount = turn
	return event


static func _intent_shown_event(intent: IntentData) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.INTENT_SHOWN, BattleEvent.Actor.ENEMY)
	event.reason = _intent_kind_name(intent.kind)
	event.amount = intent.amount
	event.status = intent.status if intent.kind != IntentData.Kind.SPECIAL else intent.special_id
	event.turns = intent.turns
	event.hits = intent.hits
	return event


static func _suit_shifted_event(from: Suit.Type, to: Suit.Type) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.SUIT_SHIFTED)
	event.suit_from = from
	event.suit_to = to
	return event


## Lowercase intent kind for events and the presentation: "attack", "steal_mp".
static func _intent_kind_name(kind: IntentData.Kind) -> StringName:
	var key: String = IntentData.Kind.keys()[kind]
	return StringName(key.to_lower())
