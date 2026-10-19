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
## Boss phase banners by boss id, indexed by phase (D25). Phase 0 has no banner.
const BOSS_BANNERS: Dictionary[StringName, PackedStringArray] = {
	&"big_lou": ["", "Lou gets sentimental."],
}
const BOSS_REWARD_TITLE: String = "Boss down"
const BOSS_REWARD_SIGNATURE_FORMAT: String = "Signature unlocked: %s"
const BOSS_REWARD_TAKE_FORMAT: String = "Take %s (%s)"
const BOSS_REWARD_SKIP_FORMAT: String = "Skip (+%d Purrls)"
const BOSS_REWARD_NEXT_ACT: String = "Then heal 50% and head for the next act."
const ITEM_FOUND_FORMAT: String = "Found %s!"
const COIN_CASH_OUT: String = "Cash out"
const COIN_FLIP_AGAIN: String = "Flip again"
const COIN_HEADS: String = "H"
const COIN_TAILS: String = "T"
const COIN_UNFLIPPED: String = "?"
const COIN_PENDING_FORMAT: String = "Pending %d"
const STREAK_FORMAT: String = "Streak %d"
const CARDS_HIT: String = "Hit"
const CARDS_STAND: String = "Stand"
const CARDS_SWAP: String = "Swap order"
const CARDS_CONFIRM: String = "Confirm order"
const CARDS_PICK: String = "Pick a card to keep"
const CARDS_ORDER_FORMAT: String = "Top: %d, then %d"
const CARDS_SAVED_FORMAT: String = "Saved: %d"
const NINE_LIVES_FORGIVEN: String = "Nine lives: forgiven"
const ODDS_STAND_AT_FORMAT: String = "If you hit below %d:"
const ODDS_FORGIVENESS_READY: String = "Nine lives: next bust is forgiven"
## A gamble result line: "2 heads → 32".
const GAMBLE_RESULT_FORMAT: String = "%s → %d"
## Tooltip on the Due meter (PRD §6.0 rule 7).
const DUE_TOOLTIP: String = "Due: each bad result adds a pip (+5 Luck); a top result empties it."
const DECK_HEADER: String = "Deck"
const DECK_TOOLTIP: String = "Cards left in the battle deck, by value."
## Special intents by special_id (PRD §9.3).
const SPECIAL_INTENT_TEXT: Dictionary[StringName, String] = {
	&"cheat_suit": "★ Cheat: takes the suit that beats yours",
}
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
const REWARD_ITEM_POUCH: String = "Use it in battle from your pouch."
const REWARD_ITEM_REPLACE_FORMAT: String = "Replace %s"
const REWARD_ITEM_LEAVE: String = "Leave it"
const REWARD_LEARN_FORMAT: String = "Learn %s %s · %s"
const REWARD_OWNED: String = " · already owned"
const REWARD_SWAP_HINT: String = "Swap moves at shops and rest sites."
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

const SHOP_TITLES: PackedStringArray = ["Back-alley stall", "Cashier cage", "Concierge desk"]
const SHOP_HUD_FORMAT: String = "♥ %d/%d   ◉ %d Purrls"
const SHOP_PRICE_FORMAT: String = "%d Purrls"
const SHOP_SOLD: String = "Sold"
const SHOP_KIND_MOVE: String = "Move"
const SHOP_KIND_RELIC: String = "Relic"
const SHOP_KIND_MODIFIER: String = "Modifier"
const SHOP_KIND_ITEM: String = "Item"
const SHOP_HEAL_FORMAT: String = "Heal %d HP · %d Purrls"
const SHOP_REROLL_FORMAT: String = "Reroll stock · %d Purrls"
const SHOP_REARRANGE: String = "Rearrange (free)"
const SHOP_LEAVE: String = "Leave"
const SHOP_TOO_POOR: String = "Not enough Purrls."
const SHOP_POUCH_FULL: String = "Your pouch is full."
const SHOP_LOADOUT_FULL: String = "Equipped and bag are full. Rearrange or release a move first."
const SHOP_OWNED: String = "Already owned."
const SHOP_PICK_MOVE_FORMAT: String = "Attach %s to which move?"
const SHOP_PICK_SUIT: String = "Pick the new suit."
const SHOP_CANCEL: String = "Cancel"
const SHOP_FULL_HP: String = "Already at full HP."

## Chest names by act (PRD §10.4).
const TREASURE_TITLES: PackedStringArray = ["A dropped purse", "A vault box", "A jewelry case"]
const TREASURE_RARITY_FORMAT: String = "Holds 1 %s relic."
const TREASURE_OPEN: String = "Open it"
const TREASURE_EMPTY: String = "Empty. The cat already owns everything in here."

const SUMMARY_TITLE_WON: String = "The house is beaten"
const SUMMARY_TITLE_LOST: String = "Out cold"
## "Act 2 · row 9 · 31:40 · KITTY-7731" (PRD §13.8).
const SUMMARY_LINE_FORMAT: String = "Act %d · row %d · %d:%02d · %s"
const SUMMARY_BUILD_LABEL: String = "Build:"
const SUMMARY_RELICS_LABEL: String = "Relics:"
const SUMMARY_NONE: String = "none"

const REST_TITLE: String = "Cardboard campfire"
const REST_NAP_FORMAT: String = "Nap · heal %d HP"
const REST_PRACTICE: String = "Practice"
const REST_REARRANGE: String = "Rearrange"
const REST_NO_FREE_SLOT: String = "No move has a free slot for Practice."
const REST_PICK_MOVE: String = "Practice which move?"
const REST_PRACTICE_OPTION_FORMAT: String = "%s %s · +%s"

const EVENT_ODDS_FORMAT: String = "%.1f%% %s"
const EVENT_ODDS_SEPARATOR: String = " · "
const EVENT_NEED_PURRLS_FORMAT: String = "Need %d more Purrls."
const EVENT_POUCH_FULL: String = "Your pouch is full."
const EVENT_LOADOUT_FULL: String = "Equipped and bag are full."
const EVENT_NO_TARGET_FORMAT: String = "No move can take %s."
const EVENT_NO_GAMBLE: String = "Needs a gamble move."
const EVENT_CONTINUE: String = "Continue"
const EVENT_PICK_MOVE_FORMAT: String = "Put %s on which move?"
const EFFECT_PURRLS_GAIN: String = "+%d Purrls"
const EFFECT_PURRLS_LOSS: String = "−%d Purrls"
const EFFECT_HP_GAIN: String = "+%d HP"
const EFFECT_HP_LOSS: String = "−%d HP"
const EFFECT_HP_FLOOR: String = " (→ 1 HP)"
const EFFECT_MAX_HP: String = "+%d max HP"
const EFFECT_ITEM_RANDOM: String = "a pouch item"
const EFFECT_RELIC_RANDOM: String = "a relic"
const EFFECT_LEARN_FORMAT: String = "learn %s"
const EFFECT_MODIFIER_FORMAT: String = "%s on a move"
const EFFECT_BATTLE_FORMAT: String = "fight %s"
const EFFECT_NEXT_MP_FORMAT: String = "+%d MP next battle"
const EFFECT_NOTHING: String = "nothing"

const PAUSE_TITLE: String = "Paused"
const PAUSE_RESUME: String = "Resume"
const PAUSE_SETTINGS: String = "Settings"
const PAUSE_SAVE_QUIT: String = "Save & Quit"
const PAUSE_ABANDON: String = "Abandon run"
const ABANDON_CONFIRM: String = "Fold this run? It goes in the history as a loss."
const ABANDON_YES: String = "Fold"
const ABANDON_NO: String = "Keep playing"
const SAVE_CODE_BUTTON: String = "Save code"
const SAVE_CODE_EXPORT_HINT: String = "Your run and progress in one line. Keep it somewhere safe."
const SAVE_CODE_COPY: String = "Copy"
const SAVE_CODE_COPIED: String = "Copied."
const SAVE_CODE_IMPORT_HINT: String = "Paste a save code. It replaces the saves on this device."
const SAVE_CODE_LOAD: String = "Load code"
const SAVE_CODE_LOADED: String = "Loaded. Your run is waiting on the title."
const SAVE_CODE_BAD: String = "That code doesn't add up. Copy the whole line and try again."
const SAVE_CODE_TOO_NEW: String = "That code is from a newer version of the game."
const SAVE_CODE_WRITE_FAILED: String = "The code is fine, but this device couldn't save it."


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


## The suit matchup behind a multiplier: "♦ beats ♠ ×1.5", "♦ resists ♠ ×0.75", or just "×1.0".
static func matchup_text(attacker: Suit.Type, defender: Suit.Type, value: float) -> String:
	if value > 1.0:
		return "%s beats %s %s" % [suit_glyph(attacker), suit_glyph(defender), mult(value)]
	if value < 1.0:
		return "%s resists %s %s" % [suit_glyph(defender), suit_glyph(attacker), mult(value)]
	return mult(value)


## A resolved gamble in words: "Tails: 0 damage, 3 backfire" or "2 heads: 32 damage".
static func gamble_result(tier: StringName, payout: int, backfire: int) -> String:
	var text: String = "%s: %d damage" % [tier, payout]
	if backfire > 0:
		text += ", %d backfire" % backfire
	return text


## One intent line from an INTENT_SHOWN event: "⚔ ♠ 5", "🛡 6", "▼ weak 2", "MP −10".
## [param suit] is the enemy's suit, which the event doesn't carry.
static func intent_text(event: BattleEvent, suit: Suit.Type) -> String:
	match event.reason:
		&"attack":
			return "%s %s %d" % [ATTACK_GLYPH, suit_glyph(suit), event.amount]
		&"multi_attack":
			return "%s×%d %s %d" % [ATTACK_GLYPH, event.hits, suit_glyph(suit), event.amount]
		&"guard":
			return "%s %d" % [SHIELD_GLYPH, event.amount]
		&"debuff":
			return "%s %s %d" % [DEBUFF_GLYPH, String(event.status).capitalize(), event.turns]
		&"steal_mp":
			return "✋ −%d MP" % event.amount
		&"buff":
			return "▲ +%d dmg" % event.amount
		&"heal":
			return "✚ %d" % event.amount
		&"special":
			return SPECIAL_INTENT_TEXT.get(event.status, "★ %s" % event.status)
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


## Nine Lives' running line: "Total 17 · Bust next: 39%" (PRD §6.3). No bust line at 21 or more.
static func cards_total_text(total: int, bust_chance: float) -> String:
	if total >= CardFamily.BLACKJACK_TOTAL:
		return "Total %d" % total
	return "Total %d · Bust next: %d%%" % [total, roundi(bust_chance * 100.0)]


## One deck count: "7 ●○" for one 7 left of two (PRD §6.3).
static func deck_count_text(value: int, count: int) -> String:
	return (
		"%d %s%s"
		% [
			value,
			PIP_FULL.repeat(count),
			PIP_EMPTY.repeat(maxi(CardFamily.COPIES_PER_VALUE - count, 0)),
		]
	)


static func speed_text(at_speed: int) -> String:
	match at_speed:
		EventPlayer.SPEED_NORMAL:
			return "speed: 1× [F]"
		EventPlayer.SPEED_DOUBLE:
			return "speed: 2× [F]"
		_:
			return "speed: instant [F]"


## One reward offer button: "Learn ♦ Gleam · uncommon", plus " · already owned" when the cat has it.
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


## One shop card: "Move · Gleam ♦\n45 Purrls". [param detail] follows the name (a suit glyph or a
## rarity); [param price_text] is the price, or "Sold".
static func shop_card(
	kind_label: String, name: String, detail: String, price_text: String
) -> String:
	return "%s · %s%s\n%s" % [kind_label, name, detail, price_text]


## One event effect as the player reads it: "+20 Purrls", "−6 HP (→ 1 HP)", "learn Pounce".
## Mirrors what EventRules applies, so the odds line is true.
static func event_effect(effect: RunEffectData, run: RunState, db: ContentDb) -> String:
	match effect.kind:
		RunEffectData.Kind.PURRLS:
			var purrls_format: String = (
				EFFECT_PURRLS_GAIN if effect.amount >= 0 else EFFECT_PURRLS_LOSS
			)
			return purrls_format % absi(effect.amount)
		RunEffectData.Kind.HP:
			return _event_hp(effect.amount, run)
		RunEffectData.Kind.HP_PCT:
			return _event_hp(floori(run.max_hp * effect.amount / 100.0 + 0.5), run)
		RunEffectData.Kind.MAX_HP:
			return EFFECT_MAX_HP % effect.amount
		RunEffectData.Kind.GAIN_ITEM:
			return EFFECT_ITEM_RANDOM if effect.id == &"" else db.item(effect.id).display_name
		RunEffectData.Kind.GAIN_RELIC:
			return EFFECT_RELIC_RANDOM if effect.id == &"" else db.relic(effect.id).display_name
		RunEffectData.Kind.LEARN_MOVE:
			return EFFECT_LEARN_FORMAT % db.move(effect.id).display_name
		RunEffectData.Kind.ADD_MODIFIER:
			return EFFECT_MODIFIER_FORMAT % db.modifier(effect.id).display_name
		RunEffectData.Kind.START_BATTLE:
			return EFFECT_BATTLE_FORMAT % db.enemy(effect.id).display_name
		RunEffectData.Kind.START_NEXT_BATTLE_MP:
			return EFFECT_NEXT_MP_FORMAT % effect.amount
		_:
			return EFFECT_NOTHING


## An outcome's effects as one line: "+20 Purrls, −3 HP".
static func event_outcome(outcome: EventOutcomeData, run: RunState, db: ContentDb) -> String:
	var parts := PackedStringArray()
	for effect: RunEffectData in outcome.effects:
		parts.append(event_effect(effect, run, db))
	return ", ".join(parts)


## A choice's odds line: the lone outcome for a safe choice, else "41.7% −5 HP · 58.3% +20 Purrls".
static func event_odds(choice: EventChoiceData, run: RunState, db: ContentDb) -> String:
	if choice.outcomes.size() == 1:
		return event_outcome(choice.outcomes[0], run, db)
	var parts := PackedStringArray()
	for outcome: EventOutcomeData in choice.outcomes:
		parts.append(
			EVENT_ODDS_FORMAT % [outcome.probability * 100.0, event_outcome(outcome, run, db)]
		)
	return EVENT_ODDS_SEPARATOR.join(parts)


## Why an event choice is disabled, from EventRules.disabled_reason, or "" for an unknown reason.
static func event_disabled(
	reason: StringName, choice: EventChoiceData, run: RunState, db: ContentDb
) -> String:
	match reason:
		&"purrls":
			return EVENT_NEED_PURRLS_FORMAT % (choice.min_purrls - run.purrls)
		&"pouch_full":
			return EVENT_POUCH_FULL
		&"loadout_full":
			return EVENT_LOADOUT_FULL
		&"no_target":
			for outcome: EventOutcomeData in choice.outcomes:
				for effect: RunEffectData in outcome.effects:
					if effect.kind == RunEffectData.Kind.ADD_MODIFIER:
						return EVENT_NO_TARGET_FORMAT % db.modifier(effect.id).display_name
			return ""
		&"no_gamble":
			return EVENT_NO_GAMBLE
		_:
			return ""


static func _event_hp(amount: int, run: RunState) -> String:
	if amount >= 0:
		return EFFECT_HP_GAIN % amount
	var text: String = EFFECT_HP_LOSS % absi(amount)
	return text + (EFFECT_HP_FLOOR if run.hp + amount < 1 else "")
