extends Node
## The run's state machine (arch §5). An autoload named Game. It owns the RunState and the
## ContentDb, moves the cat between screens, and saves at each step. Screens call it and listen to
## run_changed. A battle reports back through the signals connected in _enter_battle.

## Emitted when a run starts, loads, or ends, so screens can refresh what they show.
signal run_changed

const RUN_FILE: String = "run.json"
const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"
const MAP_SCENE: String = "res://src/scenes/map/map.tscn"
const BATTLE_SCENE: String = "res://src/scenes/battle/battle.tscn"
const REWARD_SCENE: String = "res://src/scenes/reward/reward.tscn"
const DEFAULT_ENEMY_ID: StringName = &"sewer_rat"

var run: RunState
var db: ContentDb
## Owns every write to run.json. Its last_result tells the title and map when a save failed.
var save_store: SaveStore = SaveStore.new()
## The streams of the battle in progress. Saved back into the run when the battle ends.
var _battle_rngs: RngSet
## The action log of the battle in progress. It joins run.action_log only when the battle ends, so a
## reload mid-battle restarts it cleanly (arch §6).
var _battle_entry: Dictionary = {}
## The battle screen in progress, read once when it finishes.
var _battle: BattleScene


func _ready() -> void:
	db = ContentDb.load_all()
	if OS.is_debug_build():
		_add_debug_layer()


## Starts a run from [param run_seed], or a fresh seed when it is empty, and opens the map.
func new_run(run_seed: String = "") -> void:
	_start_run(run_seed)
	goto(RunState.NodeState.MAP)


## Loads the saved run into [member run]. Returns false, and leaves [member run] null, when there is
## nothing to continue: no readable file, an ended run, or a move the content no longer has.
func continue_run() -> bool:
	var saved: Dictionary = save_store.read_json(RUN_FILE)
	if saved.is_empty():
		return false
	var loaded: RunState = RunState.from_dict(saved)
	if loaded == null:
		return false
	if not _all_moves_known(loaded.equipped) or not _all_moves_known(loaded.bag):
		push_warning("run.json names a move that is not in the content; not continuing")
		return false
	if loaded.node_state == RunState.NodeState.DEFEAT:
		return false
	if loaded.node_state == RunState.NodeState.VICTORY:
		return false
	run = loaded
	run_changed.emit()
	return true


## Moves the run to [param node_state] and shows that node's screen. Saves the new state first.
func goto(node_state: RunState.NodeState) -> void:
	run.node_state = node_state
	match node_state:
		RunState.NodeState.MAP:
			_enter_map()
		RunState.NodeState.BATTLE:
			_enter_battle()
		RunState.NodeState.REWARD:
			_enter_reward()
		_:
			push_error("no scene for %s yet" % RunState.NodeState.keys()[node_state])
			_enter_map()
	save_now()
	run_changed.emit()


## Ends the run after a loss. It is saved as DEFEAT and the player goes back to the title.
func abandon_run() -> void:
	if run != null:
		run.node_state = RunState.NodeState.DEFEAT
		save_now()
	run = null
	run_changed.emit()
	_change_scene(_load_scene(TITLE_SCENE))


## Writes [member run] to run.json. A failed write is kept in save_store.last_result.
func save_now() -> void:
	if run == null:
		push_error("save_now called with no run")
		return
	save_store.write_json(RUN_FILE, run.to_dict())


func _start_run(run_seed: String) -> void:
	var seed_text: String = run_seed
	if seed_text.is_empty():
		# Wall-clock entropy is enough for a seed the player can read and retype. Only SeededRng
		# draws numbers here, so the rules never see a global RNG.
		var entropy := SeededRng.new(
			str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec())
		)
		seed_text = SeedWords.generate(entropy)
	run = RunState.start(seed_text, db.tuning())
	save_now()
	run_changed.emit()


## Enters [param node] through RunRules: the enemy is drawn from the battle stream, then the
## matching screen opens. A node without a screen yet (or an enemy not in the content yet) shows
## the D7 "coming soon" panel on the map. The dev console's goto and node use this too.
func enter_node(node: MapNode) -> void:
	var rngs: RngSet = _run_rngs()
	var entry: RunRules.NodeEntry = RunRules.enter_node(run, node, db, rngs.battle)
	run.rng_states = rngs.to_states()
	run.position = entry.position
	if entry.node_state == RunState.NodeState.BATTLE and db.enemy(entry.enemy_id) != null:
		# "entered" survives a reload so the log tells Replay to redraw this enemy.
		run.node_payload = {"enemy": String(entry.enemy_id), "entered": true}
		goto(RunState.NodeState.BATTLE)
		return
	run.node_state = RunState.NodeState.MAP
	_enter_map(node.type)
	save_now()
	run_changed.emit()


## Opens the map. [param coming_soon_type] is a MapNode.Type to announce as not built yet, or -1.
func _enter_map(coming_soon_type: int = -1) -> void:
	_ensure_map()
	var map_scene: MapScene = _load_scene(MAP_SCENE) as MapScene
	map_scene.show_map(run.map, run.position, run)
	if coming_soon_type >= 0:
		map_scene.show_coming_soon(coming_soon_type as MapNode.Type)
	map_scene.node_chosen.connect(enter_node)
	map_scene.coming_soon_closed.connect(goto.bind(RunState.NodeState.MAP))
	_change_scene(map_scene)


## Maps are made from the map stream on first arrival (PRD §3.1). T011 may move this into RunRules.
func _ensure_map() -> void:
	if run.map != null and run.map.act == run.act:
		return
	var rngs: RngSet = _run_rngs()
	run.map = MapGen.generate(run.act, db.tuning(), rngs.map)
	run.rng_states = rngs.to_states()
	run.position = MapNavigation.start_position()


func _enter_battle() -> void:
	var enemy_id: StringName = run.node_payload.get("enemy", DEFAULT_ENEMY_ID)
	var enemy: EnemyData = db.enemy(enemy_id)
	if enemy == null:
		push_error("unknown enemy %s; fighting %s instead" % [enemy_id, DEFAULT_ENEMY_ID])
		enemy = db.enemy(DEFAULT_ENEMY_ID)
	assert(enemy != null, "the default enemy is missing from content")
	_battle_rngs = RngSet.for_seed(run.run_seed)
	_battle_rngs.apply_states(run.rng_states)
	var battle: BattleScene = _load_scene(BATTLE_SCENE) as BattleScene
	battle.setup(enemy, BattleContext.from_run(run, db), _battle_rngs)
	battle.speed = Settings.battle_speed
	var entered: bool = run.node_payload.get("entered", false) == true
	_battle_entry = ActionLog.battle_entry(run.position, enemy.id, entered)
	battle.action_sent.connect(_on_action_sent)
	battle.events_applied.connect(_on_battle_events)
	# Deferred: at instant speed the battle finishes inside its own _input, and swapping the scene
	# there would pull the battle out of the tree mid-call.
	battle.battle_finished.connect(_on_battle_finished, CONNECT_DEFERRED)
	battle.speed_changed.connect(_on_speed_changed)
	_battle = battle
	_change_scene(battle)


func _enter_reward() -> void:
	var reward: RunRules.Reward = RunRules.Reward.from_payload(run.node_payload, db)
	if reward == null:
		push_error("run is on REWARD without a readable reward; back to the map")
		run.node_state = RunState.NodeState.MAP
		run.node_payload = {}
		_enter_map()
		return
	var reward_scene: RewardScene = _load_scene(REWARD_SCENE) as RewardScene
	reward_scene.show_reward(reward, RunRules.owned_ids(run), run.pouch)
	reward_scene.choice_made.connect(_on_reward_choice.bind(reward, reward_scene))
	_change_scene(reward_scene)


func _on_reward_choice(
	choice: RunRules.RewardChoice, reward: RunRules.Reward, reward_scene: RewardScene
) -> void:
	if not RunRules.take_reward(run, reward, choice, db.tuning()):
		reward_scene.begin_learn(run, db, choice.index)
		return
	var pick: int = choice.index if choice.kind == RunRules.RewardChoice.Kind.MOVE else -1
	if not run.action_log.is_empty():
		var actions: Array = run.action_log[-1]["actions"]
		actions.append({"kind": "reward", "pick": pick, "item_slot": choice.item_slot})
	goto(RunState.NodeState.MAP)


## A used pouch item leaves the run's pouch at once (D34), so a reload can't use it twice.
func _on_battle_events(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.ITEM_USED:
			run.pouch[event.amount] = &""


func _on_action_sent(action: PlayerAction) -> void:
	ActionLog.record(_battle_entry, action)


func _on_battle_finished(outcome: BattleState.Outcome) -> void:
	run.action_log.append(_battle_entry)
	var state: BattleState = _battle.battle_state()
	_battle = null
	run.node_payload = {}
	if outcome == BattleState.Outcome.WON:
		RunRules.finish_battle(run, state, db, [], _battle_rngs.reward)
		run.rng_states = _battle_rngs.to_states()
		goto(RunState.NodeState.REWARD)
		return
	run.rng_states = _battle_rngs.to_states()
	if outcome == BattleState.Outcome.FLED:
		# Smoke Bomb: the cat keeps its HP and leaves with no rewards (PRD §4.6).
		run.hp = state.cat.hp
		goto(RunState.NodeState.MAP)
		return
	abandon_run()


func _on_speed_changed(speed: int) -> void:
	Settings.battle_speed = speed
	Settings.save()


## Dev tools (D36) sit on their own layer under Game, so they survive scene changes. load() instead
## of preload() keeps them out of release builds entirely.
func _add_debug_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	layer.add_child((load("res://src/debug/debug_overlay.tscn") as PackedScene).instantiate())
	layer.add_child((load("res://src/debug/dev_console.tscn") as PackedScene).instantiate())


## The run's streams at their saved states. Each caller writes them back with to_states().
func _run_rngs() -> RngSet:
	var rngs: RngSet = RngSet.for_seed(run.run_seed)
	rngs.apply_states(run.rng_states)
	return rngs


func _change_scene(scene: Node) -> void:
	get_tree().change_scene_to_node(scene)


func _load_scene(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


func _all_moves_known(moves: Array[MoveInstance]) -> bool:
	for instance: MoveInstance in moves:
		if db.move(instance.move_id) == null:
			return false
	return true
