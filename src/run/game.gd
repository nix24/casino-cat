extends Node
## The run's state machine (arch §5). An autoload named Game. It owns the RunState and the
## ContentDb, moves the cat between screens, and saves at each step. Screens call it and listen to
## run_changed. A battle reports back through the signals connected in _enter_battle.

## Emitted when a run starts, loads, or ends, so screens can refresh what they show.
signal run_changed

const RUN_FILE: String = "run.json"
const META_FILE: String = "meta.json"
const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"
const MAP_SCENE: String = "res://src/scenes/map/map.tscn"
const BATTLE_SCENE: String = "res://src/scenes/battle/battle.tscn"
const REWARD_SCENE: String = "res://src/scenes/reward/reward.tscn"
const SHOP_SCENE: String = "res://src/scenes/shop/shop.tscn"
const REST_SCENE: String = "res://src/scenes/rest/rest.tscn"
const EVENT_SCENE: String = "res://src/scenes/event/event.tscn"
const BOSS_REWARD_SCENE: String = "res://src/scenes/reward/boss_reward.tscn"
const TREASURE_SCENE: String = "res://src/scenes/treasure/treasure.tscn"
const SUMMARY_SCENE: String = "res://src/scenes/summary/summary.tscn"
const PAUSE_MENU_SCENE: String = "res://src/scenes/pause/pause_menu.tscn"
const SETTINGS_SCENE: String = "res://src/scenes/settings/settings_stub.tscn"
## Above the run scenes, below the debug layer (100).
const PAUSE_LAYER: int = 90
const DEFAULT_ENEMY_ID: StringName = &"sewer_rat"

var run: RunState
var db: ContentDb
## Progress kept across runs (arch §6): signature unlocks now, history and the compendium later.
var meta: MetaState = MetaState.new()
## Owns every write to run.json. Its last_result tells the title and map when a save failed.
var save_store: SaveStore = SaveStore.new()
## The streams of the battle in progress. Saved back into the run when the battle ends.
var _battle_rngs: RngSet
## The action log of the battle in progress. It joins run.action_log only when the battle ends, so a
## reload mid-battle restarts it cleanly (arch §6).
var _battle_entry: Dictionary = {}
## The battle screen in progress, read once when it finishes.
var _battle: BattleScene
## Ticks (ms) up to which run.stats.duration_s has counted play time.
var _clock_ms: int = 0
## Lives on its own layer so it survives scene changes (D55). Hidden unless the game is paused.
var _pause_menu: PauseMenu
## The settings stub opened from the pause menu, or null.
var _settings_overlay: SettingsStub
## What had focus when the pause opened; Resume gives it back so keys and controllers still work.
var _focus_before_pause: Control


func _ready() -> void:
	db = ContentDb.load_all()
	_load_meta()
	_add_pause_layer()
	if OS.is_debug_build():
		_add_debug_layer()


func _unhandled_input(event: InputEvent) -> void:
	if run == null or _pause_menu.visible or not event.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()
	open_pause()


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
	_clock_ms = Time.get_ticks_msec()
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
		RunState.NodeState.SHOP:
			_enter_shop()
		RunState.NodeState.REST:
			_enter_rest()
		RunState.NodeState.EVENT:
			_enter_event()
		RunState.NodeState.TREASURE:
			_enter_treasure()
		RunState.NodeState.BOSS_REWARD:
			_enter_boss_reward()
		_:
			push_error("no scene for %s yet" % RunState.NodeState.keys()[node_state])
			_enter_map()
	save_now()
	run_changed.emit()


## Ends the run as won or lost (D32): the history entry goes to meta.json, run.json and its backup
## are deleted, and [member run] is cleared. Returns the entry for the summary screen.
func end_run(is_won: bool) -> Dictionary:
	_count_play_time()
	run.node_state = RunState.NodeState.VICTORY if is_won else RunState.NodeState.DEFEAT
	var entry: Dictionary = RunSummary.build_entry(run, is_won, Time.get_date_string_from_system())
	meta.append_history(entry)
	save_meta()
	save_store.delete_file(RUN_FILE)
	run = null
	run_changed.emit()
	return entry


## Abandons the run (D32, D55): it ends as a loss, goes in the history, and the summary opens.
func abandon_run() -> void:
	close_pause()
	_show_summary(end_run(false))


## Saves the run and returns to the title (D55). In battle the save is the node-start state with
## used pouch items gone (D34, arch §6): the battle writes hp and RNG back only when it ends.
func save_and_quit() -> void:
	close_pause()
	save_now()
	run = null
	_battle = null
	run_changed.emit()
	_change_scene(_load_scene(TITLE_SCENE))


## Pauses the tree and opens the pause menu. Does nothing without a run.
func open_pause() -> void:
	if run == null:
		return
	_focus_before_pause = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	_pause_menu.open()


## Closes the pause menu and any settings opened from it, then resumes the tree.
func close_pause() -> void:
	_close_settings_overlay()
	_pause_menu.close()
	get_tree().paused = false
	if is_instance_valid(_focus_before_pause) and _focus_before_pause.is_visible_in_tree():
		_focus_before_pause.grab_focus()
	_focus_before_pause = null


## The run and meta saves as one save code (PRD §17.4). Works with or without a run.
func save_code() -> String:
	return SaveCode.export_code(run.to_dict() if run != null else {}, meta.to_dict())


## Replaces both saves with the ones in [param code]. Refused during a run. On success meta is
## reloaded and the title offers Continue when the code carried a run.
func import_save_code(code: String) -> SaveCode.Error:
	if run != null:
		push_warning("import_save_code called during a run; refused")
		return SaveCode.Error.BAD_CODE
	var imported: SaveCode.Imported = SaveCode.import_code(code)
	if imported.error != SaveCode.Error.NONE:
		return imported.error
	if save_store.write_json(META_FILE, imported.meta) != SaveStore.Result.OK:
		return SaveCode.Error.WRITE_FAILED
	_load_meta()
	if imported.run.is_empty():
		save_store.delete_file(RUN_FILE)
	elif save_store.write_json(RUN_FILE, imported.run) != SaveStore.Result.OK:
		return SaveCode.Error.WRITE_FAILED
	return SaveCode.Error.NONE


## Writes [member run] to run.json. A failed write is kept in save_store.last_result.
func save_now() -> void:
	if run == null:
		push_error("save_now called with no run")
		return
	_count_play_time()
	save_store.write_json(RUN_FILE, run.to_dict())


## Adds the whole seconds played since the last count to the run's duration; the remainder carries.
func _count_play_time() -> void:
	var now: int = Time.get_ticks_msec()
	var seconds: int = (now - _clock_ms) / 1000
	run.stats.duration_s += seconds
	_clock_ms += seconds * 1000


## Writes [member meta] to meta.json. A failed write is kept in save_store.last_result.
func save_meta() -> void:
	save_store.write_json(META_FILE, meta.to_dict())


func _load_meta() -> void:
	var saved: Dictionary = save_store.read_json(META_FILE)
	if saved.is_empty():
		return
	var loaded: MetaState = MetaState.from_dict(saved)
	if loaded != null:
		meta = loaded


func _enter_boss_reward() -> void:
	var reward: RunRules.BossReward = RunRules.BossReward.from_payload(run.node_payload, db)
	if reward == null:
		push_error("run is on BOSS_REWARD without a readable reward; back to the map")
		run.node_state = RunState.NodeState.MAP
		run.node_payload = {}
		_enter_map()
		return
	var scene: BossRewardScene = _load_scene(BOSS_REWARD_SCENE) as BossRewardScene
	scene.show_reward(reward, db)
	scene.relic_chosen.connect(_on_boss_relic_chosen.bind(reward))
	_change_scene(scene)


## Takes the boss reward, heals, and starts the next act (PRD §3.2), then autosaves on its map.
func _on_boss_relic_chosen(relic_index: int, reward: RunRules.BossReward) -> void:
	var rngs: RngSet = _run_rngs()
	RunRules.take_boss_reward(run, reward, relic_index, db, rngs.map)
	run.rng_states = rngs.to_states()
	if run.node_state == RunState.NodeState.VICTORY:
		_show_summary(end_run(true))
		return
	goto(RunState.NodeState.MAP)


## Opens the run summary for a finished run's history [param entry]. The run is already gone.
func _show_summary(entry: Dictionary) -> void:
	var scene: SummaryScene = _load_scene(SUMMARY_SCENE) as SummaryScene
	scene.show_summary(entry, db)
	scene.finished.connect(func() -> void: _change_scene(_load_scene(TITLE_SCENE)))
	_change_scene(scene)


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
	_clock_ms = Time.get_ticks_msec()
	save_now()
	run_changed.emit()


## Enters [param node] through RunRules: the enemy is drawn from the battle stream, then the
## matching screen opens. A node without a screen yet (or an enemy not in the content yet) shows
## the D7 "coming soon" panel on the map. The dev console's goto and node use this too.
func enter_node(node: MapNode) -> void:
	if run.act > 1:
		# D51: Act 2 content arrives in M4. Until then every Act 2 node is a placeholder.
		run.position = node.cell()
		run.node_state = RunState.NodeState.MAP
		_enter_map(node.type)
		save_now()
		run_changed.emit()
		return
	var rngs: RngSet = _run_rngs()
	var entry: RunRules.NodeEntry = RunRules.enter_node(run, node, db, rngs.battle)
	run.rng_states = rngs.to_states()
	run.position = entry.position
	if entry.node_state == RunState.NodeState.BATTLE and db.enemy(entry.enemy_id) != null:
		# "entered" survives a reload so the log tells Replay to redraw this enemy.
		run.node_payload = {"enemy": String(entry.enemy_id), "entered": true}
		goto(RunState.NodeState.BATTLE)
		return
	if entry.node_state == RunState.NodeState.SHOP:
		run.node_payload = {"relic_rarity": node.payload.get("shop_relic_rarity", "common")}
		goto(RunState.NodeState.SHOP)
		return
	if entry.node_state == RunState.NodeState.TREASURE:
		run.node_payload = {"rarity": node.payload.get("treasure_rarity", "common")}
		goto(RunState.NodeState.TREASURE)
		return
	if entry.node_state == RunState.NodeState.REST:
		run.node_payload = {}
		goto(RunState.NodeState.REST)
		return
	if entry.node_state == RunState.NodeState.EVENT:
		var event_rngs: RngSet = _run_rngs()
		var event: EventData = EventRules.pick_event(run, db, event_rngs.event)
		run.rng_states = event_rngs.to_states()
		run.seen_events.append(event.id)
		run.node_payload = {"event": String(event.id)}
		goto(RunState.NodeState.EVENT)
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


## Maps are made from the map stream on first arrival (PRD §3.1).
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
	_battle_rngs = _run_rngs()
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


## Opens the shop. The stock is made on first arrival and kept in the node payload, so a reload
## shows the same shelves (PRD §10.2).
func _enter_shop() -> void:
	var stock: Dictionary = {}
	var saved_stock: Variant = run.node_payload.get("stock")
	if saved_stock is Dictionary:
		stock = ShopRules.stock_from_payload(saved_stock as Dictionary, db)
	if stock.is_empty():
		var rngs: RngSet = _run_rngs()
		stock = ShopRules.generate(
			run.act, run, db, _shop_relic_rarity(), [] as Array[StringName], rngs.shop
		)
		run.rng_states = rngs.to_states()
	run.node_payload["stock"] = stock
	var shop_scene: ShopScene = _load_scene(SHOP_SCENE) as ShopScene
	shop_scene.show_shop(run, db, stock)
	shop_scene.changed.connect(save_now)
	shop_scene.reroll_requested.connect(_on_shop_reroll.bind(shop_scene))
	shop_scene.leave_requested.connect(_on_shop_left)
	_change_scene(shop_scene)


## Opens the rest site. Nap and Practice end it, and RunRules.rest has already set the run to MAP.
func _enter_rest() -> void:
	var rest_scene: RestScene = _load_scene(REST_SCENE) as RestScene
	rest_scene.show_rest(run, db)
	rest_scene.finished.connect(goto.bind(RunState.NodeState.MAP))
	rest_scene.changed.connect(save_now)
	_change_scene(rest_scene)


## Opens the chest. Once opened, the payload keeps the relic id, so a reload never draws twice.
func _enter_treasure() -> void:
	var scene: TreasureScene = _load_scene(TREASURE_SCENE) as TreasureScene
	var rarity: String = run.node_payload.get("rarity", "common")
	var relic_id: String = run.node_payload.get("relic", "")
	var relic: RelicData = db.relic(StringName(relic_id)) if relic_id != "" else null
	scene.show_chest(run.act, rarity, relic, run.node_payload.has("relic"))
	scene.open_requested.connect(_on_chest_opened.bind(scene))
	scene.finished.connect(_on_treasure_left)
	_change_scene(scene)


func _on_chest_opened(scene: TreasureScene) -> void:
	if run.node_payload.has("relic"):
		return
	var rngs: RngSet = _run_rngs()
	var rarity: String = run.node_payload.get("rarity", "common")
	var relic: RelicData = TreasureRules.open_chest(run, rarity, db, rngs.reward)
	run.rng_states = rngs.to_states()
	run.node_payload["relic"] = String(relic.id) if relic != null else ""
	save_now()
	scene.show_relic(relic)


func _on_treasure_left() -> void:
	run.node_payload = {}
	goto(RunState.NodeState.MAP)


## Opens the event the node payload names. Once a choice is made the payload says "resolved", so a
## reload never offers the choices twice.
func _enter_event() -> void:
	var event_id: String = run.node_payload.get("event", "")
	var event: EventData = db.event(StringName(event_id))
	if event == null or run.node_payload.get("resolved", false) == true:
		if event == null:
			push_warning("run is on EVENT without a known event; back to the map")
		run.node_state = RunState.NodeState.MAP
		run.node_payload = {}
		_enter_map()
		return
	var rngs: RngSet = _run_rngs()
	var event_scene: EventScene = _load_scene(EVENT_SCENE) as EventScene
	event_scene.show_event(run, db, event, rngs.event)
	event_scene.changed.connect(_on_event_changed.bind(rngs))
	event_scene.finished.connect(_on_event_finished)
	_change_scene(event_scene)


## The choice (and its modifier) is in the run: keep the event stream and mark the node resolved.
func _on_event_changed(rngs: RngSet) -> void:
	run.rng_states = rngs.to_states()
	run.node_payload["resolved"] = true
	save_now()


func _on_event_finished(battle_enemy_id: StringName) -> void:
	if battle_enemy_id != &"" and db.enemy(battle_enemy_id) != null:
		run.node_payload = {"enemy": String(battle_enemy_id)}
		goto(RunState.NodeState.BATTLE)
		return
	run.node_payload = {}
	goto(RunState.NodeState.MAP)


func _on_shop_reroll(shop_scene: ShopScene) -> void:
	var stock: Dictionary = run.node_payload["stock"]
	var rngs: RngSet = _run_rngs()
	var fresh: Dictionary = RunRules.reroll_shop(
		run, stock, db, _shop_relic_rarity(), [] as Array[StringName], rngs.shop
	)
	if fresh.is_empty():
		return
	run.rng_states = rngs.to_states()
	run.node_payload["stock"] = fresh
	save_now()
	shop_scene.show_shop(run, db, fresh)


func _on_shop_left() -> void:
	run.node_payload = {}
	goto(RunState.NodeState.MAP)


func _shop_relic_rarity() -> String:
	return run.node_payload.get("relic_rarity", "common")


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
		elif event.kind == BattleEvent.Kind.ITEM_FOUND:
			run.pouch[event.amount] = event.reason


func _on_action_sent(action: PlayerAction) -> void:
	ActionLog.record(_battle_entry, action)


func _on_battle_finished(outcome: BattleState.Outcome) -> void:
	run.action_log.append(_battle_entry)
	var state: BattleState = _battle.battle_state()
	_battle = null
	run.node_payload = {}
	if outcome == BattleState.Outcome.WON and state.enemy_data.tier == EnemyData.Tier.BOSS:
		RunRules.finish_boss(run, state, db, meta, _battle_rngs.reward)
		run.rng_states = _battle_rngs.to_states()
		save_meta()
		goto(RunState.NodeState.BOSS_REWARD)
		return
	if outcome == BattleState.Outcome.WON:
		RunRules.finish_battle(run, state, db, meta.unlocked_signatures, _battle_rngs.reward)
		run.rng_states = _battle_rngs.to_states()
		goto(RunState.NodeState.REWARD)
		return
	run.rng_states = _battle_rngs.to_states()
	if outcome == BattleState.Outcome.FLED:
		# Smoke Bomb: the cat keeps its HP and leaves with no rewards (PRD §4.6).
		run.hp = state.cat.hp
		goto(RunState.NodeState.MAP)
		return
	_show_summary(end_run(false))


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


## The pause menu sits on its own layer under Game, like the debug layer, and keeps running while
## the tree is paused (D55).
func _add_pause_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = PAUSE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_menu = _load_scene(PAUSE_MENU_SCENE) as PauseMenu
	_pause_menu.visible = false
	_pause_menu.resume_requested.connect(close_pause)
	_pause_menu.settings_requested.connect(_open_settings_overlay)
	_pause_menu.save_quit_requested.connect(save_and_quit)
	_pause_menu.abandon_confirmed.connect(abandon_run)
	layer.add_child(_pause_menu)


func _open_settings_overlay() -> void:
	_settings_overlay = _load_scene(SETTINGS_SCENE) as SettingsStub
	_settings_overlay.is_overlay = true
	_settings_overlay.closed.connect(_on_settings_closed)
	_pause_menu.visible = false
	_pause_menu.get_parent().add_child(_settings_overlay)


func _on_settings_closed() -> void:
	_close_settings_overlay()
	_pause_menu.open()


func _close_settings_overlay() -> void:
	if _settings_overlay == null:
		return
	_settings_overlay.queue_free()
	_settings_overlay = null


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
