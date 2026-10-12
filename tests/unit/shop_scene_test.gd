extends TestCase
## The shop screen buys through RunRules and says why a purchase was refused (T015).

const SHOP_PATH: String = "res://src/scenes/shop/shop.tscn"


func test_item_card_buys_and_move_card_is_too_poor() -> void:
	var db := ContentDb.load_all()
	var run := RunState.start("SHOP-1", db.tuning())
	run.purrls = 50
	var stock: Dictionary = {
		"entries":
		[
			{"kind": "move", "id": "loaded_paws", "price": 65, "sold": false},
			{"kind": "item", "id": "fish_snack", "price": 30, "sold": false},
		],
		"rerolls": 0,
	}
	var scene := (load(SHOP_PATH) as PackedScene).instantiate() as ShopScene
	var changes: Array[int] = []
	scene.changed.connect(func() -> void: changes.append(1))
	scene.show_shop(run, db, stock)
	_root().add_child(scene)
	var move_card: Button = _card(scene, 0)
	var item_card: Button = _card(scene, 1)

	move_card.pressed.emit()
	assert_eq((scene.get_node("%Message") as Label).text, Strings.SHOP_TOO_POOR, "too poor")
	assert_eq(run.purrls, 50, "nothing charged")

	item_card.pressed.emit()
	assert_eq(run.purrls, 20, "fish snack costs 30")
	assert_true(_card(scene, 1).disabled, "sold card is disabled")
	assert_eq(changes.size(), 1, "changed emitted once")
	_root().remove_child(scene)
	scene.free()


func _card(scene: ShopScene, index: int) -> Button:
	return (scene.get_node("%Cards") as GridContainer).get_child(index) as Button


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
