class_name RelicData
extends Resource
## One relic (PRD §8.2): a passive effect for the whole run. No relic has a drawback (rule 6).

enum Rarity { COMMON, UNCOMMON, RARE }

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## How rare it is in shops, chests, and relic choices.
@export var rarity: Rarity
## The build it feeds (PRD §8.4), e.g. &"loaded_dice".
@export var build_tag: StringName
## Its effects, applied in this order.
@export var hooks: Array[HookData] = []
## Rules text shown to the player.
@export var description: String
## One-line flavour text.
@export var flavor: String
## Icon shown on the relic bar and in shops.
@export var icon: Texture2D
