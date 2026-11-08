extends SceneTree

var failures: int = 0
var checks: int = 0
var rules: MatchRules = MatchRules.new()


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func play(result: MatchRules.Result, x: float, y: float = 180) -> void:
	check(rules.snap(), "legal snap")
	check(rules.finish_play(result, Vector2(x, y)), "legal finish")


func next_formation() -> void:
	check(rules.advance(), "dead ball advances")
	if rules.phase == MatchRules.Phase.POSSESSION_CHANGE:
		check(rules.advance(), "possession change advances")


func run_checks() -> void:
	rules.start_game()
	check(rules.phase == MatchRules.Phase.PRE_SNAP and rules.down == 1, "game begins pre-snap on first down")
	check(rules.offense == 0 and rules.attack_direction() == 1 and rules.scores == [0, 0], "blue begins attacking right at 0-0")
	check(rules.line_of_scrimmage == 440 and rules.target_x() == 740 and rules.yards_to_target() == 15, "explicit starting LOS, midfield and yards")
	check(FootballField.progress_yards(240, 1) == 0 and FootballField.progress_yards(1240, -1) == 0, "both own goal coordinates")
	check(FootballField.world_x_from_progress(25, 1) == 740 and FootballField.world_x_from_progress(25, -1) == 740, "both midfield conversions")
	for frame: int in range(600):
		rules.tick()
	check(rules.seconds_remaining() == 300, "pre-snap clock stopped")
	check(not rules.advance() and not rules.finish_play(MatchRules.Result.FLAG_PULL, Vector2(500, 180)), "invalid pre-snap transitions rejected")
	check(rules.snap() and not rules.snap(), "duplicate snap rejected")
	check(not rules.advance(), "live play cannot advance or reset")
	check(not rules.finish_play(MatchRules.Result.TOUCHDOWN, Vector2(1239.99, 180)), "short goal-line touchdown rejected")
	check(not rules.finish_play(MatchRules.Result.FLAG_PULL, Vector2(NAN, 180)), "nonfinite spot rejected")
	check(rules.finish_play(MatchRules.Result.FLAG_PULL, Vector2(600, 180)), "flag ends live play")
	check(rules.line_of_scrimmage == 600 and rules.down == 2 and rules.phase == MatchRules.Phase.DEAD_BALL, "gain updates spot and down")
	check(not rules.finish_play(MatchRules.Result.FLAG_PULL, Vector2(700, 180)), "duplicate end cannot consume another down")
	for frame: int in range(120):
		rules.tick()
	check(rules.seconds_remaining() == 300, "dead-ball clock stopped")
	next_formation()
	play(MatchRules.Result.INCOMPLETE, 1000)
	check(rules.line_of_scrimmage == 600 and rules.down == 3 and not rules.midfield_earned, "incomplete preserves LOS and cannot earn midfield")
	next_formation()
	play(MatchRules.Result.FLAG_PULL, 739.99)
	check(not rules.midfield_earned and rules.down == 4, "just short of midfield does not reset downs")
	next_formation()
	play(MatchRules.Result.FLAG_PULL, 740)
	check(rules.midfield_earned and rules.down == 1 and not rules.pending_possession, "exact midfield on fourth down grants four downs to score")
	check(rules.target_x() == 1240 and rules.yards_to_target() == 25, "goal-to-go target updates")
	next_formation()
	play(MatchRules.Result.FLAG_PULL, 700)
	check(rules.midfield_earned and rules.down == 2, "losing midfield does not restore another midfield first down")
	next_formation()
	play(MatchRules.Result.FLAG_PULL, 760)
	check(rules.down == 3, "recrossing midfield does not reset downs")
	next_formation()
	play(MatchRules.Result.OUT_OF_BOUNDS, 900, 48)
	check(rules.down == 4 and rules.line_of_scrimmage == 900, "runner sideline exit updates LOS")
	next_formation()
	play(MatchRules.Result.INCOMPLETE, 1200)
	check(rules.pending_possession and rules.last_result == "TURNOVER ON DOWNS", "fourth-down incomplete turns possession over")
	check(rules.offense == 0, "possession not changed during dead-ball display")
	check(rules.advance() and rules.phase == MatchRules.Phase.POSSESSION_CHANGE, "possession-change state is explicit and observable")
	check(rules.offense == 1 and rules.attack_direction() == -1 and rules.line_of_scrimmage == 900 and rules.down == 1, "turnover uses actual spot, reverses direction and resets downs")
	check(not rules.midfield_earned and rules.yards_to_target() == 8, "red has correct mirrored midfield distance")
	check(not rules.snap(), "cannot snap during possession-change state")
	var saved_ticks: int = rules.ticks_remaining
	rules.tick()
	check(rules.ticks_remaining == saved_ticks, "possession-change clock stopped")
	check(rules.advance(), "possession-change prepares snap")
	play(MatchRules.Result.FLAG_PULL, 740)
	check(rules.midfield_earned and rules.down == 1 and rules.target_x() == 240, "red earns mirrored midfield first down")
	next_formation()
	play(MatchRules.Result.TOUCHDOWN, 240)
	check(rules.scores == [0, 6] and rules.pending_possession, "red touchdown at exact left goal line scores six once")
	check(not rules.finish_play(MatchRules.Result.TOUCHDOWN, Vector2(240, 180)) and rules.scores == [0, 6], "duplicate score ignored")
	next_formation()
	check(rules.offense == 0 and rules.line_of_scrimmage == 440 and not rules.midfield_earned, "after touchdown opponent starts at own ten")
	play(MatchRules.Result.FLAG_PULL, 1240)
	check(rules.scores == [6, 6], "goal-line carrier takes precedence over flag pull")
	next_formation()
	check(rules.offense == 1 and rules.line_of_scrimmage == 1040, "mirrored new drive after blue touchdown")
	play(MatchRules.Result.INTERCEPTION, 500)
	next_formation()
	check(rules.offense == 0 and rules.line_of_scrimmage == 500, "interception retains field spot")
	play(MatchRules.Result.INTERCEPTION, 1300)
	next_formation()
	check(rules.offense == 1 and rules.line_of_scrimmage == 1040, "interception in new own end zone is a touchback")
	play(MatchRules.Result.INTERCEPTION, 700)
	next_formation()
	check(rules.offense == 0 and rules.midfield_earned == false, "interception on own side still requires midfield")
	play(MatchRules.Result.INTERCEPTION, 600)
	next_formation()
	check(rules.offense == 1 and rules.midfield_earned and rules.down == 1 and rules.target_x() == 240, "new drive beyond midfield starts goal-to-go")
	play(MatchRules.Result.FLAG_PULL, 1300)
	check(rules.pending_possession and rules.last_result == "OWN END ZONE / TURNOVER" and rules.scores == [6, 6], "own end-zone stop turns over without safety points")
	next_formation()
	check(rules.line_of_scrimmage == 440 and rules.offense == 0, "own end-zone turnover gives opponent own-ten start")
	rules.start_game()
	rules.snap()
	check(not rules.is_touchdown(Vector2(1240, 48)) and not rules.is_touchdown(Vector2(1240, 312)), "sideline/end-zone corners are out, not touchdowns")
	check(rules.is_touchdown(Vector2(1240, 48.11)), "in-bounds exact goal line is a touchdown")
	check(not rules.is_touchdown(Vector2(1239.99, 180)), "subpixel short of goal is not a touchdown")
	check(not rules.finish_play(MatchRules.Result.TOUCHDOWN, Vector2(1240, 48)), "invalid corner score rejected")
	rules.finish_play(MatchRules.Result.OUT_OF_BOUNDS, Vector2(1240, 48))
	check(rules.scores == [0, 0] and rules.line_of_scrimmage < 1240, "corner exit does not score or place LOS inside end zone")
	rules.start_game(1, 60)
	rules.snap()
	for frame: int in range(59):
		rules.tick()
	check(rules.ticks_remaining == 1 and rules.seconds_remaining() == 1, "fixed-tick clock rounds display up")
	rules.tick()
	check(rules.phase == MatchRules.Phase.LIVE_PLAY and rules.ticks_remaining == 0, "clock horn allows last live play to finish")
	for frame: int in range(600):
		rules.tick()
	check(rules.ticks_remaining == 0, "clock cannot become negative")
	rules.finish_play(MatchRules.Result.TOUCHDOWN, Vector2(1240, 180))
	check(rules.phase == MatchRules.Phase.GAME_OVER and rules.scores == [6, 0], "last-play touchdown counts before game over")
	check(not rules.advance() and not rules.snap() and not rules.pending_possession, "game over prevents another drive")
	rules.start_game(1, 1)
	rules.snap()
	rules.tick()
	rules.finish_play(MatchRules.Result.INTERCEPTION, Vector2(600, 180))
	check(rules.phase == MatchRules.Phase.GAME_OVER and rules.scores == [0, 0], "last-play turnover ends tied game without extra possession")
	rules.start_game(0)
	check(rules.phase == MatchRules.Phase.GAME_OVER and not rules.snap(), "zero-duration match cannot snap")
	rules.start_game(-1, 0)
	check(rules.phase == MatchRules.Phase.GAME_OVER and rules.ticks_remaining == 0 and rules.ticks_per_second == 1, "invalid duration/tick rate clamped safely")
	var first_run: String = deterministic_sequence()
	check(first_run == deterministic_sequence(), "same events and physics ticks produce identical match state")
	print("Rules checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)


func deterministic_sequence() -> String:
	var model: MatchRules = MatchRules.new()
	model.start_game(5, 60)
	for index: int in range(4):
		model.snap()
		for frame: int in range(17):
			model.tick()
		model.finish_play(MatchRules.Result.INCOMPLETE, Vector2(1000, 180))
		model.advance()
	return str([model.phase, model.offense, model.down, model.scores, model.line_of_scrimmage, model.midfield_earned, model.ticks_remaining, model.last_result])
