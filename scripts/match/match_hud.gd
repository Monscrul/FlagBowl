extends CanvasLayer
## Read-only projection of rules and selected-athlete abilities.

@onready var director: Node2D = get_parent()
@onready var scoreboard: Label = $Scoreboard
@onready var controls: Label = $Controls


func _process(_delta: float) -> void:
	var rules: MatchRules = director.rules
	var seconds: int = rules.seconds_remaining()
	var team: String = "BLUE >" if rules.offense == 0 else "< RED"
	var target: String = "GOAL" if rules.midfield_earned else "MIDFIELD"
	scoreboard.text = "BLUE %02d   RED %02d   |   %02d:%02d   |   %s BALL" % [rules.scores[0], rules.scores[1], seconds / 60, seconds % 60, team]
	scoreboard.text += "\nDOWN %d/4  |  %.1f Y TO %s  |  %s" % [rules.down, rules.yards_to_target(), target, MatchRules.Phase.keys()[rules.phase]]
	var hint: String
	match rules.phase:
		MatchRules.Phase.PRE_SNAP:
			hint = "ENTER: SNAP"
		MatchRules.Phase.LIVE_PLAY:
			hint = "CLICK: THROW" if director.ball.holder == director.quarterback else "PASS / RUN"
			if rules.ticks_remaining == 0:
				hint += " | FINAL PLAY"
		MatchRules.Phase.GAME_OVER:
			hint = "FINAL: " + ("TIE" if rules.scores[0] == rules.scores[1] else ("BLUE WINS" if rules.scores[0] > rules.scores[1] else "RED WINS")) + " | R: NEW GAME"
		_:
			hint = "ENTER: " + ("CHANGE POSSESSION" if rules.pending_possession else "NEXT FORMATION")
	var abilities: AthleteAbilities = director.controlled_player.get_node("Abilities")
	controls.text = (rules.last_result + " | " if not rules.last_result.is_empty() else "") + hint
	controls.text += "\n%s | WASD | SHIFT: SPRINT | SPACE: JUKE %.1f | TAB: DEF | Q: OFF" % [director.controlled_player.role_name, abilities.cooldown_remaining]
