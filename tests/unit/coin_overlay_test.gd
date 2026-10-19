extends TestCase
## The coin overlay in the battle scene (T021, PRD §13.4): it opens on a coin gamble, shows the
## pending payout and the ladder from COIN_FLIPPED, starts focus on Cash out (D44), keeps the odds
## pinned beside it, and sends the player's call. Instant speed keeps every step synchronous.

const BATTLE_PATH: String = "res://src/scenes/battle/battle.tscn"
const DOUBLE_OR_NOTHING_PATH: String = "res://src/content/moves/double_or_nothing.tres"
const SEWER_RAT_PATH: String = "res://src/content/enemies/sewer_rat.tres"


func test_double_or_nothing_flip_then_cash_out() -> void:
	var scene: BattleScene = _open_battle([1, 1])
	scene.use_move(0)
	var overlay := scene.get_node("%CoinOverlay") as CoinOverlay
	assert_true(overlay.visible, "overlay opens")
	assert_eq(_label(scene, "PendingLabel").text, "Pending 16", "pending after the first head")
	var rungs: Array[String] = []
	for rung: Node in overlay.find_child("Rungs", true, false).get_children():
		rungs.append((rung as Label).text)
	assert_eq(rungs, ["16", "32", "64", "128"], "ladder")
	var cash_out := overlay.find_child("CashOut", true, false) as Button
	assert_true(cash_out.has_focus(), "focus starts on Cash out")
	var odds := scene.get_node("%MoveOdds") as OddsTable
	assert_true(odds.visible, "odds pinned during the resolve")
	assert_eq(
		(odds.find_child("Rows", true, false).get_child(0) as Label).text,
		"Heads  55.0%  16",
		"heads row at Luck 0"
	)

	(overlay.find_child("Flip", true, false) as Button).pressed.emit()
	assert_eq(_label(scene, "PendingLabel").text, "Pending 32", "second head doubles")
	cash_out.pressed.emit()
	assert_true(not overlay.visible, "overlay closes when the battle ends")
	assert_true(not odds.visible, "odds unpinned")
	assert_eq(scene.battle_state().outcome, BattleState.Outcome.WON, "32 beats the 22 HP rat")
	_close_battle(scene)


func _open_battle(forced: Array[int]) -> BattleScene:
	var move: MoveData = load(DOUBLE_OR_NOTHING_PATH) as MoveData
	var ctx := BattleContext.new()
	ctx.moves[move.id] = move
	var instance := MoveInstance.new()
	instance.move_id = move.id
	ctx.loadout.append(instance)
	ctx.forced = forced
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = EventPlayer.SPEED_INSTANT
	scene.setup(load(SEWER_RAT_PATH) as EnemyData, ctx, RngSet.for_seed("test:coin overlay"))
	_root().add_child(scene)
	scene.debug_state().mp = 100
	scene.debug_sync()
	return scene


func _close_battle(scene: BattleScene) -> void:
	_root().remove_child(scene)
	scene.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _label(scene: BattleScene, label_name: String) -> Label:
	return scene.find_child(label_name, true, false) as Label
