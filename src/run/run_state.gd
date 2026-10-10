class_name RunState
extends RefCounted
## One run in progress: everything run.json holds (arch §5, §6). Plain data only; the save code
## and file writes live in SaveStore. Content ids are checked against ContentDb by Game (T006), not
## here.

enum NodeState { MAP, BATTLE, REWARD, SHOP, REST, EVENT, TREASURE, BOSS_REWARD, VICTORY, DEFEAT }

## Starter kit the cat begins with (PRD §4.2).
const STARTER_MOVES: Array[StringName] = [&"scratch", &"swipe", &"paw_roll", &"curl_up"]
const RUN_CONTEXT: String = "run.json"

var version: int = 1
## The seed text the run was started with (PRD §17.3). On disk the key is "seed".
var run_seed: String = ""
var act: int = 1
## Map cell: x is the row (row 0 is before row 1), y is the column. Saved as [row, col].
var position: Vector2i = Vector2i.ZERO
var hp: int = 0
var max_hp: int = 60
var purrls: int = 50
var equipped: Array[MoveInstance] = []
var bag: Array[MoveInstance] = []
## Pouch item ids, one per slot. An empty string means the slot is empty.
var pouch: Array[StringName] = []
## Relic ids in acquisition order.
var relics: Array[StringName] = []
## Due pips per gamble family (PRD §6.0).
var due: Dictionary[StringName, int] = {}
var next_battle_mp_bonus: int = 0
## Raw state of each RNG stream, from RngSet.to_states().
var rng_states: Dictionary[StringName, int] = {}
## The map is a plain Dictionary until T009 adds MapData.
var map: Dictionary = {}
var node_state: NodeState = NodeState.MAP
var node_payload: Dictionary = {}
var action_log: Array[Dictionary] = []
var stats: RunStats = RunStats.new()


## A fresh run with full HP, the starter kit, and the map at the start (arch §5, PRD §3).
static func start(seed_text: String, tuning: TuningData) -> RunState:
	var run := RunState.new()
	run.run_seed = seed_text
	run.max_hp = tuning.cat_max_hp
	run.hp = tuning.cat_max_hp
	run.purrls = tuning.start_purrls
	for move_id: StringName in STARTER_MOVES:
		var move := MoveInstance.new()
		move.move_id = move_id
		run.equipped.append(move)
	for _slot: int in tuning.pouch_slots:
		run.pouch.append(&"")
	run.rng_states = RngSet.for_seed(seed_text).to_states()
	return run


func to_dict() -> Dictionary:
	return {
		"version": version,
		"seed": run_seed,
		"act": act,
		"position": [position.x, position.y],
		"hp": hp,
		"max_hp": max_hp,
		"purrls": purrls,
		"equipped": _moves_to_dicts(equipped),
		"bag": _moves_to_dicts(bag),
		"pouch": SaveReader.plain_ids(pouch),
		"relics": SaveReader.plain_ids(relics),
		"due": SaveReader.plain_counts(due),
		"next_battle_mp_bonus": next_battle_mp_bonus,
		"rng_states": SaveReader.plain_counts(rng_states),
		"map": map.duplicate(true),
		"node_state": NodeState.keys()[node_state],
		"node_payload": node_payload.duplicate(true),
		"action_log": action_log.duplicate(true),
		"stats": stats.to_dict(),
	}


## Returns null (after a warning) when [param d] fails the run.json shape: a missing key, a wrong
## type, a fractional number, or an unknown node_state. Unknown extra keys are ignored.
static func from_dict(d: Dictionary) -> RunState:
	var reader := SaveReader.new(d, RUN_CONTEXT)
	var run := RunState.new()
	run.version = reader.int_at("version")
	run.run_seed = reader.string_at("seed")
	run.act = reader.int_at("act")
	var cell: Array[int] = reader.ints_at("position", 2)
	run.hp = reader.int_at("hp")
	run.max_hp = reader.int_at("max_hp")
	run.purrls = reader.int_at("purrls")
	var equipped_entries: Array[Dictionary] = reader.dicts_at("equipped")
	var bag_entries: Array[Dictionary] = reader.dicts_at("bag")
	run.pouch = reader.ids_at("pouch")
	run.relics = reader.ids_at("relics")
	run.due = reader.counts_at("due")
	run.next_battle_mp_bonus = reader.int_at("next_battle_mp_bonus")
	run.rng_states = reader.counts_at("rng_states")
	run.map = reader.dict_at("map")
	var node_state_name: String = reader.string_at("node_state")
	run.node_payload = reader.dict_at("node_payload")
	run.action_log = reader.dicts_at("action_log")
	var stats_dict: Dictionary = reader.dict_at("stats")
	if not reader.ok():
		reader.warn()
		return null
	var node_index: int = NodeState.keys().find(node_state_name)
	if node_index < 0:
		push_warning("%s: node_state: unknown value" % RUN_CONTEXT)
		return null
	var parsed_stats: RunStats = RunStats.from_dict(stats_dict)
	if parsed_stats == null:
		return null
	for entry: Dictionary in equipped_entries:
		var equipped_move: MoveInstance = _move_from(entry, "run.json equipped")
		if equipped_move == null:
			return null
		run.equipped.append(equipped_move)
	for entry: Dictionary in bag_entries:
		var bag_move: MoveInstance = _move_from(entry, "run.json bag")
		if bag_move == null:
			return null
		run.bag.append(bag_move)
	run.position = Vector2i(cell[0], cell[1])
	run.node_state = node_index as NodeState
	run.stats = parsed_stats
	return run


static func _move_from(entry: Dictionary, context: String) -> MoveInstance:
	var reader := SaveReader.new(entry, context)
	var move := MoveInstance.new()
	move.move_id = StringName(reader.string_at("move_id"))
	move.modifier_ids = reader.ids_at("modifier_ids")
	if not reader.ok():
		reader.warn()
		return null
	return move


static func _moves_to_dicts(moves: Array[MoveInstance]) -> Array[Dictionary]:
	var plain: Array[Dictionary] = []
	for move: MoveInstance in moves:
		var entry := {
			"move_id": String(move.move_id),
			"modifier_ids": SaveReader.plain_ids(move.modifier_ids),
		}
		plain.append(entry)
	return plain
