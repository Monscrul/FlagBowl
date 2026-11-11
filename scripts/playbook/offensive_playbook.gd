class_name OffensivePlaybook
extends Resource

@export var plays: Array[OffensivePlay] = []


func is_valid() -> bool:
	if plays.size() != 5:
		return false
	var names: Array[String] = []
	for play: OffensivePlay in plays:
		if play == null or not play.is_valid() or names.has(play.display_name):
			return false
		names.append(play.display_name)
	return true
