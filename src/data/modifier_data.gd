class_name ModifierData
extends Resource
## One move modifier (PRD §8.1): attaches to one move for the run, 2 per move, applied in attach
## order.

## Which moves a modifier can attach to (PRD §8.1 "Fits").
enum Fit { BASIC, ANY, GAMBLE, DICE_NOT_SNAKE_EYES, COIN, CARDS }

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Name shown to the player.
@export var display_name: String
## Which moves it fits.
@export var fit: Fit
## Its effects, applied in this order.
@export var hooks: Array[HookData] = []
## Rules text shown to the player.
@export var description: String
## Icon shown on move buttons and in shops.
@export var icon: Texture2D
