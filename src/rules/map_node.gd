class_name MapNode
extends RefCounted
## One node on an act map (PRD §3.1). Rows run 1-15; columns 0-6.

enum Type { BATTLE, ELITE, EVENT, REST, SHOP, TREASURE, BOSS }

var row: int = 0
var col: int = 0
var type: Type = Type.BATTLE
## Cells on row + 1 this node leads to, as Vector2i(row, col).
var next: Array[Vector2i] = []
## Pre-rolled at generation (D31): "elite_id" on ELITE, "treasure_rarity" on TREASURE,
## "shop_relic_rarity" on SHOP. Rarity values are "common", "uncommon", or "rare".
var payload: Dictionary[String, String] = {}
## True when last-chance forcing chose the type (D52). Generation-only; never saved.
var forced: bool = false


func _init(at_row: int = 0, at_col: int = 0, node_type: Type = Type.BATTLE) -> void:
	row = at_row
	col = at_col
	type = node_type


## The save name of [param node_type]: the lowercase enum name, e.g. "battle" (arch §6).
static func type_name(node_type: Type) -> String:
	var key: String = Type.keys()[node_type]
	return key.to_lower()


## The type for a save name, or -1 when [param text] names no type.
static func type_from_name(text: String) -> int:
	return Type.keys().find(text.to_upper())


func cell() -> Vector2i:
	return Vector2i(row, col)
