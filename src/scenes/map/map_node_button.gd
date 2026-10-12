class_name MapNodeButton
extends Button
## One node on the map board (PRD §13.2): a grey-box coloured square with a letter. Only nodes the
## cat can step to are enabled. It shows what the map tells it and computes nothing.

const MIN_SIZE: Vector2 = Vector2(32, 32)
const WIDE_MIN_WIDTH: float = 40.0
const UNREACHABLE_ALPHA: float = 0.4
const OUTLINE_COLOR: Color = Color("#f2e7b2")
const CORNER_RADIUS: int = 3
const OUTLINE_WIDTH: int = 2
const FOCUS_MARGIN: float = 3.0
const SWATCH_SIZE: Vector2 = Vector2(16, 16)
const SWATCH_FONT_SIZE: int = 10
const STATE_STYLES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"
]
const FONT_COLORS: Array[StringName] = [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_hover_pressed_color",
	&"font_focus_color",
	&"font_disabled_color",
]

## The map node this button stands for. Null until setup.
var node: MapNode


## Shows [param map_node]. [param suit] is the elite's suit, or -1 when unknown. An unreachable node
## is disabled, dimmed, and skipped by focus.
func setup(map_node: MapNode, reachable: bool, suit: int = -1) -> void:
	node = map_node
	text = _label_for(map_node, suit)
	custom_minimum_size = MIN_SIZE
	if text.length() > 1:
		custom_minimum_size.x = WIDE_MIN_WIDTH
	focus_mode = Control.FOCUS_ALL
	for color_name: StringName in FONT_COLORS:
		add_theme_color_override(color_name, Strings.MAP_NODE_LETTER_COLOR)
	add_theme_stylebox_override(&"focus", _focus_style())
	set_outline(false)
	if not reachable:
		disabled = true
		focus_mode = Control.FOCUS_NONE
		modulate = Color(1, 1, 1, UNREACHABLE_ALPHA)


## Draws a border on the idle and hover looks. This is the reduced-motion stand-in for the pulse.
func set_outline(on: bool) -> void:
	for state: StringName in STATE_STYLES:
		var style := StyleBoxFlat.new()
		style.bg_color = Strings.MAP_NODE_COLOR[node.type]
		style.set_corner_radius_all(CORNER_RADIUS)
		if on and (state == &"normal" or state == &"hover"):
			style.set_border_width_all(OUTLINE_WIDTH)
			style.border_color = OUTLINE_COLOR
		add_theme_stylebox_override(state, style)


func set_pulse_alpha(alpha: float) -> void:
	modulate.a = alpha


## A 16×16 coloured square with the type's letter, for the legend and the tooltip.
static func make_swatch(node_type: MapNode.Type) -> PanelContainer:
	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Strings.MAP_NODE_COLOR[node_type]
	style.set_corner_radius_all(2)
	swatch.add_theme_stylebox_override(&"panel", style)
	var letter := Label.new()
	letter.text = Strings.MAP_NODE_LETTER[node_type]
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override(&"font_size", SWATCH_FONT_SIZE)
	letter.add_theme_color_override(&"font_color", Strings.MAP_NODE_LETTER_COLOR)
	swatch.add_child(letter)
	return swatch


func _label_for(map_node: MapNode, suit: int) -> String:
	var label: String = Strings.MAP_NODE_LETTER[map_node.type]
	match map_node.type:
		MapNode.Type.ELITE:
			if suit >= 0:
				label += Strings.suit_glyph(suit as Suit.Type)
		MapNode.Type.TREASURE:
			var rarity: String = map_node.payload.get("treasure_rarity", "")
			label += Strings.map_rarity_initial(rarity)
	return label


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(OUTLINE_WIDTH)
	style.border_color = OUTLINE_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_expand_margin_all(FOCUS_MARGIN)
	return style
