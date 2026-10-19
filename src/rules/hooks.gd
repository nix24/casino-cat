class_name Hooks
extends RefCounted
## Sums relic and modifier hooks for one trigger (arch §4). Pure: no Node, no RNG. Order: the
## move's modifiers in attach order, then relics in acquisition order. Statuses and one-shots join
## later (T014, T027).


## Every hook of [param trigger] that fires right now, summed. RELIC_TRIGGERED goes into
## result.events once per relic that fired, in acquisition order.
static func collect(
	trigger: HookData.Trigger, state: BattleState, ctx: BattleContext, hook_ctx: HookContext
) -> HookResult:
	var result := HookResult.new()
	if hook_ctx.move_instance != null:
		for modifier_id: StringName in hook_ctx.move_instance.modifier_ids:
			var modifier: ModifierData = ctx.modifiers.get(modifier_id)
			assert(modifier != null, "unknown modifier %s" % modifier_id)
			if _apply_all(modifier.hooks, trigger, state, hook_ctx, result):
				result.sources.append(modifier.id)
	for relic: RelicData in ctx.relics:
		if _apply_all(relic.hooks, trigger, state, hook_ctx, result):
			result.sources.append(relic.id)
			var event := BattleEvent.new(BattleEvent.Kind.RELIC_TRIGGERED)
			event.reason = relic.id
			result.events.append(event)
	return result


## Applies every hook in [param hooks] that fires. True when at least one did.
static func _apply_all(
	hooks: Array[HookData],
	trigger: HookData.Trigger,
	state: BattleState,
	hook_ctx: HookContext,
	result: HookResult
) -> bool:
	var fired: bool = false
	for hook: HookData in hooks:
		if hook.trigger != trigger or not _fires(hook, state, hook_ctx):
			continue
		_apply(hook, _amount(hook, hook_ctx), result)
		fired = true
	return fired


static func _fires(hook: HookData, state: BattleState, hook_ctx: HookContext) -> bool:
	if hook.family != &"" and hook.family != hook_ctx.family:
		return false
	match hook.condition:
		HookData.Condition.NONE:
			return true
		HookData.Condition.FIRST_TURN:
			return state.turn == 1
		HookData.Condition.HAS_SUIT_ADVANTAGE:
			var suit: Suit.Type = BattleRules.suit_of(hook_ctx.move, hook_ctx.move_instance)
			return Suit.damage_multiplier(suit, state.enemy.suit) > 1.0
		HookData.Condition.PER_STREAK:
			return hook_ctx.consecutive_heads > 0
	assert(false, "hook condition %d is not implemented yet" % hook.condition)
	return false


## The hook's amount, scaled per head in a row for PER_STREAK (Gold Tooth, D22).
static func _amount(hook: HookData, hook_ctx: HookContext) -> int:
	if hook.condition == HookData.Condition.PER_STREAK:
		return hook.amount * hook_ctx.consecutive_heads
	return hook.amount


static func _apply(hook: HookData, amount: int, result: HookResult) -> void:
	match hook.op:
		HookData.Op.ADD_MAX_HP:
			result.max_hp += amount
		HookData.Op.ADD_SHIELD:
			result.shield += amount
		HookData.Op.HEAL:
			result.heal += amount
		HookData.Op.GAIN_MP:
			result.gain_mp += amount
		HookData.Op.ADD_FLAT_DAMAGE:
			result.flat_damage += amount
		HookData.Op.MULT_DAMAGE:
			result.damage_mult_pct = result.damage_mult_pct * amount / 100
		HookData.Op.ADD_LUCK:
			result.luck += amount
		HookData.Op.ADD_REROLLS:
			result.rerolls += amount
		HookData.Op.MP_COST_DELTA:
			result.mp_cost_delta += amount
		HookData.Op.REPEAT_PENALTY_SHIFT:
			result.repeat_shift += amount
		HookData.Op.FREE_PEEK:
			result.free_peeks += amount
		HookData.Op.CHANGE_SUIT:
			# The suit lives on MoveInstance.suit_override; the hook only marks the modifier.
			pass
		_:
			assert(false, "hook op %d is not implemented yet" % hook.op)
