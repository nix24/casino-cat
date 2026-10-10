class_name Replay
extends RefCounted
## Rebuilds a run's battles from its seed and action log (decisions D38). Pure: it never touches
## saves, Game, or the scene tree. M1 only verifies; T011 adds the node bookkeeping that Game does
## between battles, here and in Game together.

## Every event the replayed battles produced, in order. Kept up to the first error.
var events: Array[BattleEvent] = []
## RNG states after the replay. The dev console compares them with the run's saved states.
var rng_states: Dictionary[StringName, int] = {}
## Empty when the replay ran to the end. Otherwise the first problem found, and the replay stopped.
var error: String = ""


## Replays [param action_log] from [param run_seed], the way Game plays a run's battles.
static func play(run_seed: String, action_log: Array[Dictionary], db: ContentDb) -> Replay:
	var replay := Replay.new()
	var run: RunState = RunState.start(run_seed, db.tuning())
	var rngs: RngSet = RngSet.for_seed(run_seed)
	rngs.apply_states(run.rng_states)
	for entry_index: int in action_log.size():
		replay._play_entry(action_log[entry_index], entry_index, run, db, rngs)
		if not replay.error.is_empty():
			break
	replay.rng_states = rngs.to_states()
	return replay


func _play_entry(
	entry: Dictionary, entry_index: int, run: RunState, db: ContentDb, rngs: RngSet
) -> void:
	var entry_type: String = str(entry.get("type", ""))
	if entry_type != "battle":
		error = "unsupported node type: %s" % entry_type
		return
	var enemy_id: String = str(entry.get("enemy", ""))
	var enemy: EnemyData = db.enemy(StringName(enemy_id))
	if enemy == null:
		error = "unknown enemy: %s" % enemy_id
		return
	var ctx: BattleContext = BattleContext.from_run(run, db)
	var start: BattleStart = BattleRules.start(enemy, ctx, rngs.battle)
	events.append_array(start.events)
	var actions: Array = entry.get("actions", [])
	for action_index: int in actions.size():
		var action_entry: Dictionary = actions[action_index]
		var action: PlayerAction = ActionLog.from_dict(action_entry)
		if action == null:
			error = "bad action at entry %d index %d" % [entry_index, action_index]
			return
		var action_events: Array[BattleEvent] = BattleRules.apply(start.state, action, ctx, rngs)
		if action_events.size() == 1 and action_events[0].kind == BattleEvent.Kind.ACTION_REJECTED:
			error = (
				"action rejected at entry %d index %d: %s"
				% [entry_index, action_index, action_events[0].reason]
			)
			return
		events.append_array(action_events)
