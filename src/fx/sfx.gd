extends Node
## Sound effects and music, as an autoload named Sfx (arch §5). Stub until T042: calls do nothing
## yet, so screens can call Sfx now and the audio bus work lands later without touching them.


## Plays the sound effect [param id]. [param pitch_step] climbs the pitch for stacked hits when
## Settings.pitch_stacking is on (T042).
func play(_id: StringName, _pitch_step: int = 0) -> void:
	pass


## Switches the background music to [param id] (T042).
func music(_id: StringName) -> void:
	pass
