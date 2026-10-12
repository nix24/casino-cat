class_name MapScene
extends Control
## The act map (PRD §3.1, §13.2): a scrolling board of nodes the cat walks up. It draws the map it
## is given and reports which node the player picked. Game owns the run and decides what is next.

## Emitted when the player picks a node the cat can reach.
signal node_chosen(node: MapNode)
## Emitted when the player closes the "coming soon" panel.
signal coming_soon_closed

const TITLE_SCENE: String = "res://src/scenes/title/title.tscn"
const NODE_BUTTON_SCENE: PackedScene = preload("res://src/scenes/map/map_node_button.tscn")
const FIRST_COL_X: float = 64.0
const COL_STEP: float = 64.0
const ROW_STEP: float = 40.0
const TOP_ROW: int = 15
const EDGE_COLOR: Color = Color("#3a3f6a")
const EDGE_WIDTH: float = 2.0
const TOOLTIP_GAP: float = 8.0
const MARKER_GAP: float = 8.0
const PULSE_PERIOD: float = 1.2
const PULSE_MID: float = 0.8
const PULSE_SWING: float = 0.2
const STICK_DEADZONE: float = 0.2
const STICK_SPEED: float = 600.0
const LEGEND_TYPES: Array[MapNode.Type] = [
	MapNode.Type.BATTLE,
	MapNode.Type.ELITE,
	MapNode.Type.EVENT,
	MapNode.Type.SHOP,
	MapNode.Type.REST,
	MapNode.Type.TREASURE,
]

var _map: MapData
var _position: Vector2i = Vector2i.ZERO
var _run: RunState
## The buttons the cat can press, left to right.
var _reachable: Array[MapNodeButton] = []
var _pulse_time: float = 0.0

@onready var _hud: Label = %Hud
@onready var _save_warning: Label = %SaveWarning
@onready var _to_title: Button = %ToTitle
@onready var _scroll: ScrollContainer = %Scroll
@onready var _board: Control = %Board
@onready var _you_are_here: Label = %YouAreHere
@onready var _legend: HBoxContainer = %Legend
@onready var _tooltip: MapTooltip = %Tooltip
@onready var _coming_soon: PanelContainer = %ComingSoon
@onready var _coming_soon_text: Label = %ComingSoonText
@onready var _coming_soon_continue: Button = %ComingSoonContinue


func _ready() -> void:
	_save_warning.text = Strings.SAVE_UNAVAILABLE
	_save_warning.visible = Game.save_store.last_result == SaveStore.Result.WRITE_FAILED
	_to_title.text = Strings.MAP_TO_TITLE
	_to_title.pressed.connect(_on_to_title_pressed)
	_you_are_here.text = Strings.MAP_YOU_ARE_HERE
	_coming_soon_continue.text = Strings.MAP_CONTINUE
	_coming_soon_continue.pressed.connect(_close_coming_soon)
	_build_legend()
	if _map != null:
		_render()


func _process(delta: float) -> void:
	var axis: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis) > STICK_DEADZONE:
		_scroll.scroll_vertical += int(axis * STICK_SPEED * delta)
	if not Settings.motion_allowed():
		return
	_pulse_time += delta
	var alpha: float = PULSE_MID + PULSE_SWING * sin(TAU * _pulse_time / PULSE_PERIOD)
	for button: MapNodeButton in _reachable:
		button.set_pulse_alpha(alpha)


func _unhandled_input(event: InputEvent) -> void:
	if _coming_soon.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_coming_soon()


## Draws [param map] with the cat standing at [param at] (row 0 is before row 1).
func show_map(map: MapData, at: Vector2i, run: RunState) -> void:
	_map = map
	_position = at
	_run = run
	if is_node_ready():
		_render()


## Opens the interim panel for a node type that has no screen yet (decision D7).
func show_coming_soon(node_type: MapNode.Type) -> void:
	_coming_soon_text.text = Strings.MAP_COMING_SOON_FORMAT % Strings.MAP_TYPE_NAME[node_type]
	_coming_soon.visible = true
	_coming_soon_continue.grab_focus()


func _render() -> void:
	_tooltip.hide_tooltip()
	_hud.text = Strings.MAP_HUD_FORMAT % [_run.hp, _run.max_hp, _run.purrls, _run.run_seed]
	_clear_board()
	_draw_edges()
	_draw_nodes()
	_place_marker()
	_link_focus()
	if not _reachable.is_empty():
		_reachable[0].grab_focus.call_deferred()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_row_y(_position.x) - _scroll.size.y / 2.0)
	# The tooltip opened on the first focus was placed before the scroll moved; place it again.
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner() as MapNodeButton
	if focused != null:
		focused.focus_entered.emit()


func _clear_board() -> void:
	_reachable.clear()
	for child: Node in _board.get_children():
		if child != _you_are_here:
			_board.remove_child(child)
			child.queue_free()


func _draw_edges() -> void:
	for node: MapNode in _map.nodes:
		for cell: Vector2i in node.next:
			if _map.node_at(cell.x, cell.y) == null:
				continue
			var line := Line2D.new()
			line.width = EDGE_WIDTH
			line.default_color = EDGE_COLOR
			line.points = PackedVector2Array(
				[_centre_of(node.row, node.col), _centre_of(cell.x, cell.y)]
			)
			_board.add_child(line)


func _draw_nodes() -> void:
	for node: MapNode in _map.nodes:
		var is_reachable: bool = MapNavigation.is_reachable(_map, _position, node.row, node.col)
		var elite_name: String = ""
		var suit: int = -1
		if node.type == MapNode.Type.ELITE:
			var elite_id: String = node.payload.get("elite_id", "")
			var elite: EnemyData = Game.db.enemy(StringName(elite_id))
			if elite != null:
				elite_name = elite.display_name
				suit = elite.suit
		var button := NODE_BUTTON_SCENE.instantiate() as MapNodeButton
		button.setup(node, is_reachable, suit)
		_board.add_child(button)
		button.size = button.get_combined_minimum_size()
		button.position = (_centre_of(node.row, node.col) - button.size / 2.0).round()
		button.focus_entered.connect(_show_tooltip.bind(button, elite_name, suit))
		button.mouse_entered.connect(_show_tooltip.bind(button, elite_name, suit))
		button.focus_exited.connect(_tooltip.hide_tooltip)
		button.mouse_exited.connect(_tooltip.hide_tooltip)
		button.pressed.connect(_on_node_pressed.bind(button))
		if is_reachable:
			_reachable.append(button)
			if not Settings.motion_allowed():
				button.set_outline(true)
	_reachable.sort_custom(
		func(a: MapNodeButton, b: MapNodeButton) -> bool: return a.node.col < b.node.col
	)


func _place_marker() -> void:
	_board.move_child(_you_are_here, -1)
	var marker_size: Vector2 = _you_are_here.get_combined_minimum_size()
	if _position.x == 0:
		var below_row_one := Vector2(_board.custom_minimum_size.x / 2.0, _row_y(0))
		_you_are_here.position = (below_row_one - marker_size / 2.0).round()
		return
	var button: MapNodeButton = _button_at(_position)
	var right_edge: float = _centre_of(_position.x, _position.y).x
	if button != null:
		right_edge += button.size.x / 2.0
	var middle_y: float = _row_y(_position.x)
	_you_are_here.position = (
		(Vector2(right_edge + MARKER_GAP, middle_y - marker_size.y / 2.0)).round()
	)


## Each reachable button links left and right to its neighbour by column; the ends and the up and
## down sides point back at themselves so focus never leaves the choices.
func _link_focus() -> void:
	for index: int in _reachable.size():
		var button: MapNodeButton = _reachable[index]
		var left: MapNodeButton = _reachable[maxi(index - 1, 0)]
		var right: MapNodeButton = _reachable[mini(index + 1, _reachable.size() - 1)]
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)


func _build_legend() -> void:
	var title := Label.new()
	title.text = Strings.MAP_LEGEND_LABEL
	_legend.add_child(title)
	for node_type: MapNode.Type in LEGEND_TYPES:
		_legend.add_child(MapNodeButton.make_swatch(node_type))
		var name_label := Label.new()
		name_label.text = Strings.MAP_TYPE_NAME[node_type].to_lower()
		_legend.add_child(name_label)


func _button_at(cell: Vector2i) -> MapNodeButton:
	for child: Node in _board.get_children():
		var button := child as MapNodeButton
		if button != null and button.node.cell() == cell:
			return button
	return null


func _centre_of(row: int, col: int) -> Vector2:
	return Vector2(FIRST_COL_X + col * COL_STEP, _row_y(row))


func _row_y(row: int) -> float:
	return ROW_STEP + (TOP_ROW - row) * ROW_STEP + ROW_STEP / 2.0


func _show_tooltip(button: MapNodeButton, elite_name: String, suit: int) -> void:
	var at: Vector2 = button.global_position + Vector2(button.size.x + TOOLTIP_GAP, 0)
	_tooltip.show_for(button.node, _map, elite_name, suit, at)


func _on_node_pressed(button: MapNodeButton) -> void:
	if _coming_soon.visible:
		return
	node_chosen.emit(button.node)


func _close_coming_soon() -> void:
	_coming_soon.visible = false
	coming_soon_closed.emit()


func _on_to_title_pressed() -> void:
	Game.save_now()
	get_tree().change_scene_to_file(TITLE_SCENE)
