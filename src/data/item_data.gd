class_name ItemData
extends Resource
## One pouch item (PRD §8.3): used once in battle, at most one per turn, without ending the turn.

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## Shop price in Purrls at Act 1 (PRD §8.3); shops scale it per act (T015).
@export var price: int = 0
## What it does, in order.
@export var effects: Array[EffectData] = []
## Rules text shown to the player.
@export var description: String
## Icon shown on the pouch bar.
@export var icon: Texture2D
