extends TestCase
## The cards overlay and deck counts in the battle scene (T022, PRD §6.3, §13.4). Instant speed
## keeps every step synchronous. Decks are set top-last on the live state.

const BATTLE_PATH: String = "res://src/scenes/battle/battle.tscn"
const NINE_LIVES_PATH: String = "res://src/content/moves/nine_lives.tres"
const CARD_TRICK_PATH: String = "res://src/content/moves/card_trick.tres"
const BIG_LOU_PATH: String = "res://src/content/enemies/big_lou.tres"
const SLOT_NINE_LIVES: int = 0
const SLOT_CARD_TRICK: int = 1


func test_nine_lives_shows_total_bust_and_forgiveness() -> void:
	var scene: BattleScene = _open_battle()
	var counts := scene.get_node("%DeckCounts") as DeckCounts
	assert_true(counts.visible, "deck counts show with a card move")
	assert_eq((counts.get_child(6) as Label).text, "7 ●●", "a fresh deck before the first draw")
	scene.debug_state().deck = PackedInt32Array([1, 2, 6, 8, 9])
	scene.use_move(SLOT_NINE_LIVES)
	var overlay := scene.get_node("%CardOverlay") as CardOverlay
	assert_true(overlay.visible, "overlay opens")
	assert_eq(_label(overlay, "TotalLabel").text, "Total 17 · Bust next: 33%", "1 of 3 busts")
	assert_eq((counts.get_child(8) as Label).text, "9 ○○", "drawn 9 leaves the count")
	assert_true((overlay.find_child("Stand", true, false) as Button).has_focus(), "Stand focused")

	(overlay.find_child("Hit", true, false) as Button).pressed.emit()
	assert_eq(_label(overlay, "StatusLabel").text, "Nine lives: forgiven", "said in words")
	assert_true(not overlay.visible, "closes after the turn")
	assert_eq(scene.battle_state().enemy.hp, 120 - 17, "forgiven bust stands on 17")
	_close_battle(scene)


func test_card_trick_pick_swap_confirm() -> void:
	var scene: BattleScene = _open_battle()
	scene.debug_state().deck = PackedInt32Array([1, 4, 5, 7])
	scene.use_move(SLOT_CARD_TRICK)
	var overlay := scene.get_node("%CardOverlay") as CardOverlay
	var hand: Node = overlay.find_child("Hand", true, false)
	assert_true((hand.get_child(0) as Button).has_focus(), "first card focused")
	var confirm := overlay.find_child("Confirm", true, false) as Button
	assert_true(confirm.disabled, "nothing picked yet")
	(hand.get_child(0) as Button).pressed.emit()
	assert_eq(_label(overlay, "StatusLabel").text, "Top: 5, then 4", "default order")
	(overlay.find_child("Swap", true, false) as Button).pressed.emit()
	assert_eq(_label(overlay, "StatusLabel").text, "Top: 4, then 5", "swapped")
	confirm.pressed.emit()
	assert_eq(scene.battle_state().enemy.hp, 120 - 18, "7 × 2.5 rounds to 18")
	assert_eq(scene.battle_state().deck, PackedInt32Array([1, 5, 4]), "4 on top")
	_close_battle(scene)


func _open_battle() -> BattleScene:
	var ctx := BattleContext.new()
	for path: String in [NINE_LIVES_PATH, CARD_TRICK_PATH]:
		var move: MoveData = load(path) as MoveData
		ctx.moves[move.id] = move
		var instance := MoveInstance.new()
		instance.move_id = move.id
		ctx.loadout.append(instance)
	var scene := (load(BATTLE_PATH) as PackedScene).instantiate() as BattleScene
	scene.speed = EventPlayer.SPEED_INSTANT
	scene.setup(load(BIG_LOU_PATH) as EnemyData, ctx, RngSet.for_seed("test:card overlay"))
	_root().add_child(scene)
	scene.debug_state().mp = 100
	scene.debug_sync()
	return scene


func _close_battle(scene: BattleScene) -> void:
	_root().remove_child(scene)
	scene.free()


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _label(overlay: CardOverlay, label_name: String) -> Label:
	return overlay.find_child(label_name, true, false) as Label
