class_name EventData
extends Resource
## One map event (PRD §10.3): at most 60 words, at most 3 choices, at least one safe choice and one
## gamble.

## Permanent id. Saves store it, so it never changes after release.
@export var id: StringName
## Act it appears in, 1 to 3.
@export var act: int = 1
## Title shown above the text.
@export var title: String
## Scene text, at most 60 words.
@export var text: String
## Picture shown with the text; a placeholder until T043.
@export var illustration: Texture2D
## 1 to 3 choices.
@export var choices: Array[EventChoiceData] = []
