class_name BattleContext
extends RefCounted
## What a battle resolves against: the tuning numbers, the move content, and the cat's loadout.
## Read-only for the rules except `due` and `forced`, which gamble moves update. The run builds it
## from ContentDb.

var tuning: TuningData = TuningData.new()
## Move content by id, for every move in the loadout.
var moves: Dictionary[StringName, MoveData] = {}
var loadout: Array[MoveInstance] = []
## Due pips per gamble family, kept across battles by the run (PRD §6.0 rule 7). Rules update it.
var due: Dictionary[StringName, int] = {}
## The run's relics in acquisition order, and every modifier the loadout uses, by id (T013).
var relics: Array[RelicData] = []
var modifiers: Dictionary[StringName, ModifierData] = {}
## Pouch item ids by slot, "" for empty (a battle-local copy; Game clears the run's slot on
## ITEM_USED, D34), and the item content they name.
var pouch: Array[StringName] = []
var items: Dictionary[StringName, ItemData] = {}
## Every pouch item, for finds such as Dumpster Dive (T019).
var item_pool: Array[ItemData] = []
## Luck from relics and other sources, added to every gamble's Luck. 0 until T013.
var luck_bonus: int = 0
## Faces the next gamble's dice draw before the RNG, in order. Consumed when that gamble opens.
var forced: Array[int] = []
## The cat's HP and max HP carried in from the run. 0 means a fresh cat at the tuning max HP.
var cat_hp: int = 0
var cat_max_hp: int = 0
## Dev console only (D36): the cat cannot drop below 1 HP. Never set in a release build.
var god_mode: bool = false


## The context for one battle of [param run]. Copies the loadout and Due, so the battle changes its
## own copies and the run keeps its state until the battle ends. Game and replays share this path.
static func from_run(run: RunState, db: ContentDb) -> BattleContext:
	var ctx := BattleContext.new()
	ctx.tuning = db.tuning()
	for run_move: MoveInstance in run.equipped:
		var move_data: MoveData = db.move(run_move.move_id)
		assert(move_data != null, "run loadout has an unknown move: %s" % run_move.move_id)
		ctx.moves[run_move.move_id] = move_data
		var instance := MoveInstance.new()
		instance.move_id = run_move.move_id
		instance.modifier_ids = run_move.modifier_ids.duplicate()
		instance.suit_override = run_move.suit_override
		ctx.loadout.append(instance)
		for modifier_id: StringName in run_move.modifier_ids:
			var modifier: ModifierData = db.modifier(modifier_id)
			assert(modifier != null, "run loadout has an unknown modifier: %s" % modifier_id)
			ctx.modifiers[modifier_id] = modifier
	ctx.pouch = run.pouch.duplicate()
	ctx.item_pool = db.all_items()
	for item_id: StringName in run.pouch:
		if item_id != &"":
			var item: ItemData = db.item(item_id)
			assert(item != null, "run pouch has an unknown item: %s" % item_id)
			ctx.items[item_id] = item
	for relic_id: StringName in run.relics:
		var relic: RelicData = db.relic(relic_id)
		assert(relic != null, "run has an unknown relic: %s" % relic_id)
		ctx.relics.append(relic)
	ctx.due = run.due.duplicate()
	ctx.cat_hp = run.hp
	ctx.cat_max_hp = run.max_hp
	return ctx
