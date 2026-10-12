class_name ShopScene
extends Control
## The shop (PRD §10.2): a grid of stock cards, the heal and reroll services, and a free loadout
## rearrange. It shows the stock ShopRules rolled and asks RunRules to buy; Game saves and rerolls.

## Emitted after anything is bought or healed, so Game can save.
signal changed
## Emitted when the player asks for a reroll and can pay. Game pays and sends the new stock back
## through show_shop.
signal reroll_requested
## Emitted when the player leaves the shop.
signal leave_requested

const CARD_MIN_SIZE: Vector2 = Vector2(140.0, 44.0)

var _run: RunState
var _db: ContentDb
var _stock: Dictionary = {}
var _card_buttons: Array[Button] = []
## Stock index of the modifier the picker is asking about.
var _picker_card: int = -1

@onready var _layout: VBoxContainer = %Layout
@onready var _title: Label = %Title
@onready var _hud: Label = %Hud
@onready var _cards: GridContainer = %Cards
@onready var _heal: Button = %Heal
@onready var _reroll: Button = %Reroll
@onready var _rearrange: Button = %Rearrange
@onready var _leave: Button = %Leave
@onready var _message: Label = %Message
@onready var _picker: PanelContainer = %Picker
@onready var _picker_text: Label = %PickerText
@onready var _picker_options: VBoxContainer = %PickerOptions
@onready var _picker_cancel: Button = %PickerCancel
@onready var _loadout: LoadoutEditor = %Loadout


func _ready() -> void:
	_rearrange.text = Strings.SHOP_REARRANGE
	_leave.text = Strings.SHOP_LEAVE
	_picker_cancel.text = Strings.SHOP_CANCEL
	_heal.pressed.connect(_on_heal_pressed)
	_reroll.pressed.connect(_on_reroll_pressed)
	_rearrange.pressed.connect(_on_rearrange_pressed)
	_leave.pressed.connect(leave_requested.emit)
	_picker_cancel.pressed.connect(_close_picker)
	_loadout.changed.connect(changed.emit)
	_loadout.done.connect(_close_loadout)
	if _run != null:
		_render()
		_focus_first_card.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _loadout.visible or not _picker.visible:
		return
	# Handled first so Esc closes only the picker; with none open it reaches the pause menu (D55).
	get_viewport().set_input_as_handled()
	_close_picker()


## Shows [param stock] (a ShopRules stock) for [param run]. The scene edits both in place through
## RunRules; Game keeps the same Dictionary in the run's node payload.
func show_shop(run: RunState, db: ContentDb, stock: Dictionary) -> void:
	_run = run
	_db = db
	_stock = stock
	if is_node_ready():
		_render()
		_focus_first_card.call_deferred()


func _render() -> void:
	_title.text = Strings.SHOP_TITLES[_run.act - 1]
	_message.visible = false
	_hud.text = Strings.SHOP_HUD_FORMAT % [_run.hp, _run.max_hp, _run.purrls]
	_heal.text = (
		Strings.SHOP_HEAL_FORMAT % [ShopRules.heal_amount(_run, _db.tuning()), ShopRules.HEAL_PRICE]
	)
	var rerolls_done: int = _stock["rerolls"]
	_reroll.text = Strings.SHOP_REROLL_FORMAT % ShopRules.reroll_cost(rerolls_done, _db.tuning())
	_clear_children(_cards)
	_card_buttons.clear()
	var entries: Array = _stock["entries"]
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var card: Button = _make_card(entry)
		card.pressed.connect(_on_card_pressed.bind(index))
		_cards.add_child(card)
		_card_buttons.append(card)
	_link_focus()


func _make_card(entry: Dictionary) -> Button:
	var id_text: String = entry["id"]
	var id := StringName(id_text)
	var button := Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	var kind_label: String
	var item_name: String
	var detail: String = ""
	match entry["kind"]:
		ShopRules.KIND_MOVE:
			var move_data: MoveData = _db.move(id)
			kind_label = Strings.SHOP_KIND_MOVE
			item_name = move_data.display_name
			detail = " " + Strings.suit_glyph(move_data.suit)
			button.tooltip_text = move_data.description
		ShopRules.KIND_RELIC:
			var relic: RelicData = _db.relic(id)
			var rarity_name: String = RelicData.Rarity.keys()[relic.rarity]
			kind_label = Strings.SHOP_KIND_RELIC
			item_name = relic.display_name
			detail = " (%s)" % rarity_name.to_lower()
			button.tooltip_text = relic.description
		ShopRules.KIND_MODIFIER:
			var modifier: ModifierData = _db.modifier(id)
			kind_label = Strings.SHOP_KIND_MODIFIER
			item_name = modifier.display_name
			button.tooltip_text = modifier.description
		_:
			var item: ItemData = _db.item(id)
			kind_label = Strings.SHOP_KIND_ITEM
			item_name = item.display_name
			button.tooltip_text = item.description
	var cost: int = entry["price"]
	var is_sold: bool = entry["sold"]
	var price_text: String = Strings.SHOP_SOLD if is_sold else Strings.SHOP_PRICE_FORMAT % cost
	button.text = Strings.shop_card(kind_label, item_name, detail, price_text)
	button.disabled = is_sold
	return button


## Arrow keys: Down from a card with no card below goes to the services row, and Up from a service
## goes to the nearest enabled card in its column among those.
func _link_focus() -> void:
	var services: Array[Button] = [_heal, _reroll, _rearrange, _leave]
	var columns: int = _cards.columns
	var bottom_indices: Array[int] = []
	for index: int in _card_buttons.size():
		if index + columns < _card_buttons.size():
			continue
		var card: Button = _card_buttons[index]
		card.focus_neighbor_bottom = card.get_path_to(services[index % columns])
		if not card.disabled:
			bottom_indices.append(index)
	for column: int in services.size():
		var service: Button = services[column]
		service.focus_neighbor_top = NodePath()
		var nearest_distance: int = columns
		for index: int in bottom_indices:
			var distance: int = absi(index % columns - column)
			if distance < nearest_distance:
				nearest_distance = distance
				service.focus_neighbor_top = service.get_path_to(_card_buttons[index])


func _focus_first_card() -> void:
	for card: Button in _card_buttons:
		if not card.disabled:
			card.grab_focus()
			return
	_leave.grab_focus()


func _on_card_pressed(index: int) -> void:
	var entries: Array = _stock["entries"]
	var entry: Dictionary = entries[index]
	var cost: int = entry["price"]
	if _run.purrls < cost:
		_show_message(Strings.SHOP_TOO_POOR)
		return
	if entry["kind"] == ShopRules.KIND_MODIFIER:
		_open_picker(index)
		return
	_finish_buy(RunRules.buy(_run, _stock, index, _db))


func _finish_buy(result: RunRules.BuyResult) -> void:
	match result:
		RunRules.BuyResult.OK:
			changed.emit()
			_render()
			_focus_first_card.call_deferred()
		RunRules.BuyResult.TOO_POOR:
			_show_message(Strings.SHOP_TOO_POOR)
		RunRules.BuyResult.POUCH_FULL:
			_show_message(Strings.SHOP_POUCH_FULL)
		RunRules.BuyResult.LOADOUT_FULL:
			_show_message(Strings.SHOP_LOADOUT_FULL)
		RunRules.BuyResult.OWNED:
			_show_message(Strings.SHOP_OWNED)
		_:
			push_error("shop buy refused: %s" % RunRules.BuyResult.keys()[result])


func _show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func _on_heal_pressed() -> void:
	if RunRules.heal_service(_run, _db.tuning()):
		changed.emit()
		_render()
		return
	if _run.purrls < ShopRules.HEAL_PRICE:
		_show_message(Strings.SHOP_TOO_POOR)
	else:
		_show_message(Strings.SHOP_FULL_HP)


func _on_reroll_pressed() -> void:
	var rerolls_done: int = _stock["rerolls"]
	if _run.purrls < ShopRules.reroll_cost(rerolls_done, _db.tuning()):
		_show_message(Strings.SHOP_TOO_POOR)
		return
	reroll_requested.emit()


func _on_rearrange_pressed() -> void:
	_layout.visible = false
	_loadout.visible = true
	_loadout.bind(_run, _db)


func _close_loadout() -> void:
	_loadout.visible = false
	_layout.visible = true
	_rearrange.grab_focus()


## Opens the picker for the modifier at stock [param index]: one button per owned move it can go on.
func _open_picker(index: int) -> void:
	_picker_card = index
	var entries: Array = _stock["entries"]
	var entry: Dictionary = entries[index]
	var id_text: String = entry["id"]
	var modifier: ModifierData = _db.modifier(StringName(id_text))
	_picker_text.text = Strings.SHOP_PICK_MOVE_FORMAT % modifier.display_name
	_clear_children(_picker_options)
	var owned: Array[MoveInstance] = []
	owned.append_array(_run.equipped)
	owned.append_array(_run.bag)
	for move_index: int in owned.size():
		var instance: MoveInstance = owned[move_index]
		var move_data: MoveData = _db.move(instance.move_id)
		if not RunRules.fits(modifier, move_data):
			continue
		if instance.modifier_ids.has(modifier.id):
			continue
		if instance.modifier_ids.size() >= RunRules.MODIFIER_SLOTS:
			continue
		var button := Button.new()
		button.text = "%s %s" % [move_data.display_name, Strings.suit_glyph(move_data.suit)]
		button.pressed.connect(_on_picker_move_pressed.bind(move_index, modifier.id))
		_picker_options.add_child(button)
	_layout.visible = false
	_picker.visible = true
	_focus_picker.call_deferred()


func _on_picker_move_pressed(move_index: int, modifier_id: StringName) -> void:
	if modifier_id != RunRules.RE_SUITED_ID:
		_buy_modifier(move_index, -1)
		return
	_picker_text.text = Strings.SHOP_PICK_SUIT
	_clear_children(_picker_options)
	for suit: Suit.Type in RunRules.RE_SUIT_CHOICES:
		var button := Button.new()
		button.text = Strings.suit_glyph(suit)
		button.pressed.connect(_buy_modifier.bind(move_index, suit))
		_picker_options.add_child(button)
	_focus_picker.call_deferred()


func _buy_modifier(move_index: int, suit: int) -> void:
	var result: RunRules.BuyResult = RunRules.buy(_run, _stock, _picker_card, _db, move_index, suit)
	_close_picker()
	_finish_buy(result)


func _close_picker() -> void:
	var card_index: int = _picker_card
	_picker_card = -1
	_picker.visible = false
	_layout.visible = true
	if card_index >= 0 and card_index < _card_buttons.size():
		_card_buttons[card_index].grab_focus()


func _focus_picker() -> void:
	if _picker_options.get_child_count() > 0:
		(_picker_options.get_child(0) as Button).grab_focus()
	else:
		_picker_cancel.grab_focus()


## Frees [param parent]'s children now out of the layout, so a grid never counts a card that is
## only queued for deletion.
func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
