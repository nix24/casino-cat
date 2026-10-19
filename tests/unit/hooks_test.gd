extends TestCase
## Relic and modifier hooks (T013, arch §4, PRD §4.4, §8.1, §8.2, D3, D16).

const SLOT_SCRATCH: int = 0
const SLOT_PAW_ROLL: int = 2


func test_relics_fire_in_acquisition_order() -> void:
	var opening: BattleStart = _start([&"loaded_die", &"velvet_rope"])
	var kinds: Array[BattleEvent.Kind] = []
	var relic_ids: Array[StringName] = []
	for event: BattleEvent in opening.events:
		kinds.append(event.kind)
		if event.kind == BattleEvent.Kind.RELIC_TRIGGERED:
			relic_ids.append(event.reason)
	assert_eq(relic_ids, [&"loaded_die", &"velvet_rope"])
	assert_eq(kinds[0], BattleEvent.Kind.BATTLE_STARTED)
	assert_true(
		kinds.find(BattleEvent.Kind.RELIC_TRIGGERED) < kinds.find(BattleEvent.Kind.SHIELD_GAINED),
		"relics announce before their shield"
	)
	assert_eq(kinds[-1], BattleEvent.Kind.INTENT_SHOWN)


func test_modifiers_are_summed_before_relics() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [&"thick_fur"])
	run.equipped[SLOT_SCRATCH].modifier_ids = [&"sharpened"]
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var relic := RelicData.new()
	relic.id = &"test_relic"
	var hook := HookData.new()
	hook.trigger = HookData.Trigger.BEFORE_MOVE
	hook.op = HookData.Op.ADD_FLAT_DAMAGE
	hook.amount = 2
	relic.hooks = [hook]
	ctx.relics.append(relic)
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, SeededRng.new("h"))
	var hook_ctx := HookContext.new()
	hook_ctx.move = db.move(&"scratch")
	hook_ctx.move_instance = opening.state.equipped[SLOT_SCRATCH]
	var result: HookResult = Hooks.collect(
		HookData.Trigger.BEFORE_MOVE, opening.state, ctx, hook_ctx
	)
	assert_eq(result.sources, [&"sharpened", &"test_relic"])
	assert_eq(result.flat_damage, 5)


func test_loaded_die_adds_one_reroll() -> void:
	var opening: BattleStart = _start([&"loaded_die"])
	assert_eq(opening.state.rerolls, 2)
	assert_true(
		_has(opening.events, BattleEvent.Kind.REROLLS_CHANGED), "rerolls change is an event"
	)


func test_velvet_rope_gives_8_shield_at_start() -> void:
	var opening: BattleStart = _start([&"velvet_rope"])
	assert_eq(opening.state.cat.shield, 8)
	var shields: Array[int] = []
	for event: BattleEvent in opening.events:
		if event.kind == BattleEvent.Kind.SHIELD_GAINED:
			shields.append(event.amount)
	assert_eq(shields, [8])


func test_thick_fur_once_on_pickup_not_each_battle() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = RunState.start("HOOKS", db.tuning())
	run.hp = 50
	assert_true(RunRules.gain_relic(run, db.relic(&"thick_fur")))
	assert_eq(run.max_hp, 72)
	assert_eq(run.hp, 62, "current HP rises too (D16)")
	assert_true(not RunRules.gain_relic(run, db.relic(&"thick_fur")), "no duplicates")
	var opening: BattleStart = BattleRules.start(
		db.enemy(&"sewer_rat"), BattleContext.from_run(run, db), SeededRng.new("h")
	)
	assert_eq(opening.state.cat.max_hp, 72, "battle start doesn't add it again")
	assert_eq(run.max_hp, 72)


func test_pit_boss_shifts_repeat_penalty() -> void:
	var tuning := TuningData.new()
	var shifted: Array[float] = []
	var base: Array[float] = []
	for uses: int in range(1, 6):
		shifted.append(Damage.repeat_multiplier(uses, tuning, 1))
		base.append(Damage.repeat_multiplier(uses, tuning))
	assert_eq(shifted, [1.0, 1.0, 1.0, 0.75, 0.5])
	assert_eq(base, [1.0, 1.0, 0.75, 0.5, 0.5])
	assert_eq(_start([&"pit_boss"]).state.repeat_shift, 1)


func test_pit_boss_third_scratch_hits_full() -> void:
	var db: ContentDb = ContentDb.load_all()
	var with_relic: Array[int] = _scratch_hits(db, [&"pit_boss"], 3)
	var without: Array[int] = _scratch_hits(db, [], 3)
	assert_eq(with_relic[2], with_relic[0], "third use is still ×1.0")
	assert_true(without[2] < without[0], "third use is ×0.75 without it")


func test_maneki_paw_adds_8_luck_on_preview() -> void:
	var opening: BattleStart = _start([&"maneki_paw"])
	var hook_ctx := HookContext.new()
	hook_ctx.family = &"dice"
	var result: HookResult = Hooks.collect(
		HookData.Trigger.GAMBLE_PREVIEW, opening.state, _ctx_for([&"maneki_paw"]), hook_ctx
	)
	assert_eq(result.luck, 8)
	var odds: GambleOdds = GambleRules.preview(
		ContentDb.load_all().move(&"paw_roll").gamble, opening.state, _ctx_for([&"maneki_paw"])
	)
	assert_eq(odds.luck, 8, "the preview shows relic Luck")


func test_peeking_monocle_is_free_peek_hook() -> void:
	var relic: RelicData = ContentDb.load_all().relic(&"peeking_monocle")
	assert_eq(relic.hooks[0].op, HookData.Op.FREE_PEEK)
	assert_eq(relic.hooks[0].condition, HookData.Condition.NONE)
	assert_eq(relic.hooks[0].family, &"cups", "never fires on dice")


func test_relics_have_no_negative_amounts() -> void:
	var relics: Array[RelicData] = ContentDb.load_all().all_relics()
	assert_eq(relics.size(), 7, "T013's six plus gold_tooth (D4)")
	for relic: RelicData in relics:
		assert_true(not relic.description.is_empty(), "%s description" % relic.id)
		for hook: HookData in relic.hooks:
			assert_true(hook.amount >= 0, "%s amount" % relic.id)


func test_relic_loads_from_content_db() -> void:
	assert_eq(ContentDb.load_all().relic(&"loaded_die").rarity, RelicData.Rarity.COMMON)
	assert_eq(ContentDb.load_all().relic(&"maneki_paw").rarity, RelicData.Rarity.RARE)


func test_sharpened_adds_3_base_damage() -> void:
	var db: ContentDb = ContentDb.load_all()
	var plain: Array[int] = _scratch_hits(db, [], 1)
	var sharp: Array[int] = _scratch_hits(db, [], 1, [&"sharpened"])
	# Scratch ♠ 6 into the ♠ Sewer Rat is ×1.0: 6 → 9.
	assert_eq(plain[0], 6)
	assert_eq(sharp[0], 9)


func test_quick_draw_only_on_first_turn() -> void:
	var db: ContentDb = ContentDb.load_all()
	var hits: Array[int] = _scratch_hits(db, [], 2, [&"quick_draw"])
	assert_eq(hits[0], 9, "6 × 1.5 on turn 1")
	assert_eq(hits[1], 6, "turn 2 is plain")


func test_thorny_and_charged_on_use() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	run.equipped[SLOT_SCRATCH].modifier_ids = [&"thorny", &"charged"]
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var rngs := RngSet.for_seed("HOOKS")
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle)
	var mp_before: int = opening.state.mp
	var events: Array[BattleEvent] = BattleRules.apply(opening.state, _use(SLOT_SCRATCH), ctx, rngs)
	var shield_gain: int = 0
	var move_mp: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.SHIELD_GAINED and event.target == BattleEvent.Actor.CAT:
			shield_gain += event.amount
		if event.kind == BattleEvent.Kind.MP_CHANGED and event.reason == &"move":
			move_mp += event.amount
	assert_eq(shield_gain, 4, "thorny")
	assert_eq(move_mp, 8, "charged")
	assert_true(opening.state.mp > mp_before)


func test_velvet_paw_heals_25_percent_of_damage() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	run.hp = 30
	run.equipped[SLOT_SCRATCH].modifier_ids = [&"velvet_paw", &"sharpened"]
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var rngs := RngSet.for_seed("HOOKS")
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle)
	var events: Array[BattleEvent] = BattleRules.apply(opening.state, _use(SLOT_SCRATCH), ctx, rngs)
	var healed: int = 0
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.HEALED and event.target == BattleEvent.Actor.CAT:
			healed += event.amount
	assert_eq(healed, 2, "25% of 9 = 2.25 → 2")


func test_re_suited_changes_triangle_and_shift() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	run.equipped[SLOT_SCRATCH].modifier_ids = [&"re_suited"]
	run.equipped[SLOT_SCRATCH].suit_override = Suit.Type.DIAMONDS
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var rngs := RngSet.for_seed("HOOKS")
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle)
	var preview: MovePreview = BattleRules.preview_move(opening.state, SLOT_SCRATCH, ctx)
	assert_eq(preview.triangle_mult, 1.5, "♦ beats the ♠ rat")
	assert_eq(preview.damage, 9)
	BattleRules.apply(opening.state, _use(SLOT_SCRATCH), ctx, rngs)
	assert_eq(opening.state.cat.suit, Suit.Type.DIAMONDS, "the cat shifts to the new suit")


func test_cheap_cuts_gamble_cost_to_a_minimum_of_5() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	run.equipped[SLOT_PAW_ROLL].modifier_ids = [&"cheap"]
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, SeededRng.new("h"))
	var preview: MovePreview = BattleRules.preview_move(opening.state, SLOT_PAW_ROLL, ctx)
	assert_eq(preview.mp_cost, 20, "Paw Roll 30 − 10")
	assert_true(preview.affordable, "20 MP at battle start")
	var tiny := MoveData.new()
	tiny.mp_cost = 12
	assert_eq(BattleRules.discounted_cost(tiny.mp_cost, -10), 5)
	assert_eq(BattleRules.discounted_cost(0, -10), 0, "free moves stay free")


func test_attach_rules() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	var ok: RunRules.AttachResult = RunRules.AttachResult.OK
	assert_eq(RunRules.attach_modifier(run, SLOT_SCRATCH, &"sharpened", db), ok)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_SCRATCH, &"sharpened", db),
		RunRules.AttachResult.ALREADY_ATTACHED
	)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_PAW_ROLL, &"sharpened", db),
		RunRules.AttachResult.DOES_NOT_FIT,
		"basic only"
	)
	assert_eq(RunRules.attach_modifier(run, SLOT_PAW_ROLL, &"cheap", db), ok)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_SCRATCH, &"re_suited", db),
		RunRules.AttachResult.NEEDS_SUIT
	)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_SCRATCH, &"re_suited", db, Suit.Type.CLUBS),
		RunRules.AttachResult.NEEDS_SUIT,
		"♠/♥/♦ only"
	)
	assert_eq(RunRules.attach_modifier(run, SLOT_SCRATCH, &"re_suited", db, Suit.Type.HEARTS), ok)
	assert_eq(run.equipped[SLOT_SCRATCH].suit_override, Suit.Type.HEARTS)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_SCRATCH, &"thorny", db), RunRules.AttachResult.SLOTS_FULL
	)
	assert_eq(
		RunRules.attach_modifier(run, SLOT_SCRATCH, &"thorny", db, -1, 1), ok, "overwrite slot 1"
	)
	assert_eq(run.equipped[SLOT_SCRATCH].modifier_ids, [&"sharpened", &"thorny"])
	assert_eq(run.equipped[SLOT_SCRATCH].suit_override, -1, "re_suited gone, suit back")
	assert_eq(RunRules.attach_modifier(run, 99, &"thorny", db), RunRules.AttachResult.NO_SUCH_MOVE)


func test_attach_reaches_the_bag() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	var bagged := MoveInstance.new()
	bagged.move_id = &"swipe"
	run.bag.append(bagged)
	assert_eq(RunRules.attach_modifier(run, 4, &"thorny", db), RunRules.AttachResult.OK)
	assert_eq(run.bag[0].modifier_ids, [&"thorny"])


func test_suit_override_saves() -> void:
	var db: ContentDb = ContentDb.load_all()
	var run: RunState = _run(db, [])
	run.equipped[0].suit_override = Suit.Type.HEARTS
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	assert_eq(RunState.from_dict(parsed).equipped[0].suit_override, Suit.Type.HEARTS)
	var old: Dictionary = parsed.duplicate(true)
	for entry: Dictionary in old["equipped"]:
		entry.erase("suit_override")
	assert_eq(RunState.from_dict(old).equipped[0].suit_override, -1, "saves before T013 read")


func _start(relic_ids: Array[StringName]) -> BattleStart:
	var db: ContentDb = ContentDb.load_all()
	return BattleRules.start(db.enemy(&"sewer_rat"), _ctx_for(relic_ids), SeededRng.new("h"))


func _ctx_for(relic_ids: Array[StringName]) -> BattleContext:
	var db: ContentDb = ContentDb.load_all()
	return BattleContext.from_run(_run(db, relic_ids), db)


func _run(db: ContentDb, relic_ids: Array[StringName]) -> RunState:
	var run: RunState = RunState.start("HOOKS", db.tuning())
	run.relics = relic_ids.duplicate()
	return run


## Damage of [param uses] Scratches in a row against the Sewer Rat.
func _scratch_hits(
	db: ContentDb, relic_ids: Array[StringName], uses: int, modifier_ids: Array[StringName] = []
) -> Array[int]:
	var run: RunState = _run(db, relic_ids)
	run.equipped[SLOT_SCRATCH].modifier_ids = modifier_ids
	var ctx: BattleContext = BattleContext.from_run(run, db)
	ctx.god_mode = true
	var rngs := RngSet.for_seed("HOOKS")
	var opening: BattleStart = BattleRules.start(db.enemy(&"sewer_rat"), ctx, rngs.battle)
	opening.state.enemy.hp = 999
	opening.state.enemy.max_hp = 999
	var hits: Array[int] = []
	for _use_index: int in uses:
		for event: BattleEvent in BattleRules.apply(opening.state, _use(SLOT_SCRATCH), ctx, rngs):
			if event.kind == BattleEvent.Kind.DAMAGE_DEALT and event.actor == BattleEvent.Actor.CAT:
				hits.append(event.amount)
	return hits


func _use(slot: int) -> PlayerAction:
	var action := PlayerAction.new()
	action.kind = PlayerAction.Kind.USE_MOVE
	action.slot = slot
	return action


func _has(events: Array[BattleEvent], kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in events:
		if event.kind == kind:
			return true
	return false
