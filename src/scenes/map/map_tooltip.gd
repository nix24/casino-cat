class_name MapTooltip
extends PanelContainer
## The hover and focus card for a map node (PRD §13.2): its type, what it gives, and what it leads
## to. The map hands it text-ready facts; it computes no rewards or odds.

@onready var _title: Label = %Title
@onready var _gives: Label = %Gives
@onready var _leads_to: HBoxContainer = %LeadsTo
@onready var _leads_to_label: Label = %LeadsToLabel


func _ready() -> void:
	_leads_to_label.text = Strings.MAP_LEADS_TO
	hide_tooltip()


## Shows the card for [param node] with its top-left at global [param at], pushed back inside the
## viewport if it would spill out. [param elite_name] and [param suit] describe the pre-rolled elite
## (empty and -1 when unknown).
func show_for(node: MapNode, map: MapData, elite_name: String, suit: int, at: Vector2) -> void:
	_title.text = Strings.MAP_TYPE_NAME[node.type]
	_gives.text = _gives_text(node, elite_name, suit)
	_fill_leads_to(node, map)
	visible = true
	reset_size()
	var bounds: Rect2 = get_viewport_rect()
	var clamped: Vector2 = at
	clamped.x = clampf(clamped.x, bounds.position.x, bounds.end.x - size.x)
	clamped.y = clampf(clamped.y, bounds.position.y, bounds.end.y - size.y)
	global_position = clamped


func hide_tooltip() -> void:
	visible = false


func _gives_text(node: MapNode, elite_name: String, suit: int) -> String:
	var text: String = Strings.MAP_GIVES_BOSS
	match node.type:
		MapNode.Type.BATTLE:
			text = Strings.MAP_GIVES_BATTLE
		MapNode.Type.ELITE:
			text = _elite_gives_text(elite_name, suit)
		MapNode.Type.EVENT:
			text = Strings.MAP_GIVES_EVENT
		MapNode.Type.REST:
			text = Strings.MAP_GIVES_REST
		MapNode.Type.SHOP:
			text = Strings.MAP_GIVES_SHOP_FORMAT % node.payload.get("shop_relic_rarity", "")
		MapNode.Type.TREASURE:
			text = Strings.MAP_GIVES_TREASURE_FORMAT % node.payload.get("treasure_rarity", "")
	return text


func _elite_gives_text(elite_name: String, suit: int) -> String:
	if elite_name.is_empty():
		return Strings.MAP_GIVES_ELITE
	var glyph: String = Strings.suit_glyph(suit as Suit.Type) if suit >= 0 else ""
	return "%s %s · %s" % [elite_name, glyph, Strings.MAP_GIVES_ELITE]


func _fill_leads_to(node: MapNode, map: MapData) -> void:
	_leads_to.visible = node.type != MapNode.Type.BOSS
	# Keep the "Leads to:" label (child 0) and drop the old swatches.
	while _leads_to.get_child_count() > 1:
		var old: Node = _leads_to.get_child(_leads_to.get_child_count() - 1)
		_leads_to.remove_child(old)
		old.queue_free()
	for cell: Vector2i in node.next:
		var target: MapNode = map.node_at(cell.x, cell.y)
		if target != null:
			_leads_to.add_child(MapNodeButton.make_swatch(target.type))
