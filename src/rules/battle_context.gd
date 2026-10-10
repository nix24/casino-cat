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
## Luck from relics and other sources, added to every gamble's Luck. 0 until T013.
var luck_bonus: int = 0
## Faces the next gamble's dice draw before the RNG, in order. Consumed when that gamble opens.
var forced: Array[int] = []
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
		ctx.loadout.append(instance)
	ctx.due = run.due.duplicate()
	return ctx
