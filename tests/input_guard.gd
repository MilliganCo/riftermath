extends Node

## Test-only isolation: the player's OS input remains unchanged in the game.
var filtered: int = 0


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey) and not event.has_meta("riftermath_qa"):
		filtered += 1
		get_viewport().set_input_as_handled()
