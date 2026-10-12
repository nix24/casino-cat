class_name Strings
extends RefCounted
## Every glyph, colour, and format string the battle UI shows (architecture §8). Presentation only:
## every number comes from the rules, and these functions only turn it into text.

const SUIT_GLYPH: PackedStringArray = ["♠", "♥", "♦", "♣"]
## Grey-box colours, not the final palette (T039, T040).
const SUIT_COLOR: Array[Color] = [
	Color("#5fb7ff"),
	Color("#ff6b8a"),
	Color("#ffa84a"),
	Color("#c9c5e0"),
]
const ATTACK_GLYPH: String = "⚔"
const SHIELD_GLYPH: String = "🛡"
const DEBUFF_GLYPH: String = "▼"
const NO_STATUS_TEXT: String = "—"
const PIP_FULL: String = "●"
const PIP_EMPTY: String = "○"
const HEAL_COLOR: Color = Color("#7be08a")
const SHIELD_COLOR: Color = Color("#9fd8ff")
const BACKFIRE_COLOR: Color = Color("#ff5a5a")
const TICK_COLOR: Color = Color("#f2e7b2")
const RUN_INFO_FORMAT: String = "Seed %s · HP %d/%d · %d Purrls"
const SAVE_UNAVAILABLE: String = "Save unavailable here. Recent progress may be lost."
const TITLE_UNREADABLE: String = "Save unreadable. Start a new run?"
## Grey-box map icons (D31): a coloured square with a letter until T048 brings the 16×16 icons.
## All map arrays are indexed by MapNode.Type order.
const MAP_NODE_LETTER: PackedStringArray = ["B", "E", "?", "R", "S", "T", "!"]
const MAP_NODE_COLOR: Array[Color] = [
	Color("#8a8fa8"),
	Color("#ff8a4a"),
	Color("#9a7bff"),
	Color("#5fbf7a"),
	Color("#f2c14e"),
	Color("#4ac9d8"),
	Color("#ff4a6a"),
]
const MAP_NODE_LETTER_COLOR: Color = Color("#0c0e2e")
const MAP_TYPE_NAME: PackedStringArray = [
	"Battle", "Elite", "Event", "Rest", "Shop", "Treasure", "Boss"
]
const MAP_HUD_FORMAT: String = "♥ %d/%d   MP —   ◉ %d Purrls   ⚙ seed: %s"
const MAP_YOU_ARE_HERE: String = "🐾 you are here"
const MAP_LEGEND_LABEL: String = "legend:"
const MAP_LEADS_TO: String = "Leads to:"
const MAP_GIVES_BATTLE: String = "Purrls and a move choice"
const MAP_GIVES_ELITE: String = "2× Purrls, a pouch item, and a relic choice"
const MAP_GIVES_EVENT: String = "Unknown until you step in"
const MAP_GIVES_REST: String = "Nap to heal, or practice a move"
const MAP_GIVES_SHOP_FORMAT: String = "Sells moves, items, and 1 %s relic"
const MAP_GIVES_TREASURE_FORMAT: String = "A chest with 1 %s relic"
const MAP_GIVES_BOSS: String = "The act boss"
const MAP_COMING_SOON_FORMAT: String = "%s: coming soon"
const MAP_CONTINUE: String = "Continue"
const MAP_TO_TITLE: String = "Title"

const REWARD_TITLE: String = "Battle won"
const REWARD_PURRLS_FORMAT: String = "+%d Purrls"
const REWARD_ITEM_FORMAT: String = "Pouch item: %s"
const REWARD_ITEM_INTO_FORMAT: String = "Goes in slot %d"
const REWARD_ITEM_REPLACE_FORMAT: String = "Replace %s"
const REWARD_ITEM_LEAVE: String = "Leave it"
const REWARD_LEARN_FORMAT: String = "Learn %s %s · %s"
const REWARD_OWNED: String = " (owned)"
const REWARD_SKIP_FORMAT: String = "Skip +%d Purrls"

const POUCH_TITLE: String = "Q pouch"
const POUCH_EMPTY: String = "·"
const POUCH_ITEM_ALREADY_USED: String = "One pouch item per turn."
const POUCH_NOT_ON_ELITES: String = "Smoke Bomb only works in normal battles."
const POUCH_PICK_SUIT: String = "Laser Pointer: pick the enemy's suit."
const BATTLE_FLED: String = "Fled"

const LOADOUT_EQUIPPED: String = "Equipped"
const LOADOUT_BAG: String = "Bag"
const LOADOUT_EMPTY_EQUIPPED: String = "Empty"
const LOADOUT_EMPTY_BAG: String = "—"
const LOADOUT_PICKED: String = " · picked"
const LOADOUT_RELEASE: String = "Release"
const LOADOUT_KEEP: String = "Keep"
const LOADOUT_DONE: String = "Done"
const LOADOUT_SKIP: String = "Skip"
const LOADOUT_RELEASE_CONFIRM_FORMAT: String = "Release %s? It's gone for this run."
const LOADOUT_LEARN_FORMAT: String = "New move: %s. Release a move to make room, or skip."
const LOADOUT_LAST_MOVE: String = "The cat needs at least one equipped move."
const LOADOUT_MP_FORMAT: String = "%d MP"
const LOADOUT_DAMAGE_FORMAT: String = "%d dmg"
const LOADOUT_UTILITY: String = "utility"


## Glyph for [param suit]: ♠ ♥ ♦ ♣.
static func suit_glyph(suit: Suit.Type) -> String:
	return SUIT_GLYPH[suit]


static func suit_color(suit: Suit.Type) -> Color:
	return SUIT_COLOR[suit]


## "C", "U", or "R" for a relic rarity name, or "" for anything else.
static func map_rarity_initial(rarity: String) -> String:
	match rarity:
		"common":
			return "C"
		"uncommon":
			return "U"
		"rare":
			return "R"
		_:
			return ""


## Multiplier as the buttons and odds show it: ×1.0, ×0.75, ×1.5. Always at least one decimal.
static func mult(value: float) -> String:
	var text: String = String.num(value, 2)
	if not text.contains("."):
		text += ".0"
	return "×" + text


## One intent line from an INTENT_SHOWN event: "⚔ ♠ 5", "🛡 6", "▼ weak 2", "MP −10".
## [param suit] is the enemy's suit, which the event doesn't carry.
static func intent_text(event: BattleEvent, suit: Suit.Type) -> String:
	match event.reason:
		&"attack", &"multi_attack":
			return "%s %s %d" % [ATTACK_GLYPH, suit_glyph(suit), event.amount]
		&"guard":
			return "%s %d" % [SHIELD_GLYPH, event.amount]
		&"debuff":
			return "%s %s %d" % [DEBUFF_GLYPH, event.status, event.turns]
		&"steal_mp":
			return "MP −%d" % event.amount
		_:
			return "? %s" % event.reason


## Short text for one move effect: "+10 shield", "+5 HP", "+6 MP", "weak 2". Empty for the
## effect kinds the grey-box doesn't show.
static func effect_text(effect: EffectData) -> String:
	match effect.kind:
		EffectData.Kind.SHIELD:
			return "+%d shield" % effect.amount
		EffectData.Kind.HEAL:
			return "+%d HP" % effect.amount
		EffectData.Kind.MP_GAIN:
			return "+%d MP" % effect.amount
		EffectData.Kind.STATUS:
			return "%s %d" % [effect.status, effect.turns]
		_:
			return ""


## The statuses on one combatant as "weak 2 · regen 1", or "—" when there are none.
static func status_text(statuses: Dictionary[StringName, int]) -> String:
	if statuses.is_empty():
		return NO_STATUS_TEXT
	var parts := PackedStringArray()
	for status: StringName in statuses:
		parts.append("%s %d" % [status, statuses[status]])
	return " · ".join(parts)


## The Due meter as pips: "Due ●●○○" for 2 of 4 (PRD §6.0 rule 7).
static func due_text(pips: int, pips_max: int) -> String:
	return "Due %s%s" % [PIP_FULL.repeat(pips), PIP_EMPTY.repeat(pips_max - pips)]


static func speed_text(at_speed: int) -> String:
	match at_speed:
		EventPlayer.SPEED_NORMAL:
			return "speed: 1×"
		EventPlayer.SPEED_DOUBLE:
			return "speed: 2×"
		_:
			return "speed: instant"


## One reward offer button: "Learn ♦ Gleam · uncommon", plus " (owned)" when the cat has it.
static func reward_offer(move_data: MoveData, is_owned: bool) -> String:
	var rarity_name: String = MoveData.Rarity.keys()[move_data.rarity]
	var text: String = (
		REWARD_LEARN_FORMAT
		% [suit_glyph(move_data.suit), move_data.display_name, rarity_name.to_lower()]
	)
	return text + (REWARD_OWNED if is_owned else "")


## One loadout slot: "Gleam ♦\n5 dmg", "Paw Roll ♣\n10 MP", or "Curl Up ♣\nutility", plus
## " +mod, mod" when the move carries modifiers.
static func loadout_move(move_data: MoveData, modifier_ids: Array[StringName]) -> String:
	var detail: String
	match move_data.category:
		MoveData.Category.GAMBLE:
			detail = LOADOUT_MP_FORMAT % move_data.mp_cost
		MoveData.Category.UTILITY:
			detail = LOADOUT_UTILITY
		_:
			detail = LOADOUT_DAMAGE_FORMAT % move_data.base_damage
	if not modifier_ids.is_empty():
		detail += " +" + ", ".join(modifier_ids)
	return "%s %s\n%s" % [move_data.display_name, suit_glyph(move_data.suit), detail]
