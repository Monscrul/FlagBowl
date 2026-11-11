extends SceneTree

var failures: int = 0
var checks: int = 0
var match_scene: Node2D
var end_count: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func step_frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
	await process_frame


func key_press(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func run_checks() -> void:
	match_scene = load("res://scenes/match/match.tscn").instantiate()
	# Isolate legacy manual progression; playbook tests cover default AI/auto flow.
	match_scene.opponent_enabled = false
	match_scene.auto_flow_enabled = false
	match_scene.defense_enabled = false
	root.add_child(match_scene)
	current_scene = match_scene
	match_scene.play_ended.connect(func(_reason: String) -> void: end_count += 1)
	await step_frames(3)
	var rules: MatchRules = match_scene.rules
	check(rules.phase == MatchRules.Phase.PRE_SNAP and rules.line_of_scrimmage == 440, "scene starts from authoritative pre-snap model")
	check(match_scene.quarterback.position == Vector2(400, 180) and match_scene.receivers[0].position == Vector2(440, 100), "formation places QB behind LOS and receiver on LOS")
	var initial: Vector2 = match_scene.quarterback.position
	Input.action_press("move_right")
	await step_frames(20)
	Input.action_release("move_right")
	check(match_scene.quarterback.position == initial and rules.ticks_remaining == 18000, "pre-snap locks movement and clock")
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.LIVE_PLAY and match_scene.routes[0].active, "Enter snaps model and starts routes")
	await step_frames(5)
	check(rules.ticks_remaining < 18000, "scene physics advances game clock")
	var old_ticks: int = rules.ticks_remaining
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.LIVE_PLAY and rules.ticks_remaining == old_ticks, "Enter during live play cannot refund a down or clock")
	match_scene.reset_play()
	check(rules.phase == MatchRules.Phase.LIVE_PLAY, "formation reset cannot undo live play")
	match_scene.quarterback.position = Vector2(740, 180)
	check(match_scene._end_play(MatchRules.Result.FLAG_PULL, match_scene.quarterback.position), "carrier dead-ball spot accepted")
	check(rules.down == 1 and rules.midfield_earned and rules.line_of_scrimmage == 740, "scene first down updates LOS and target")
	check(match_scene.quarterback.movement_locked and not match_scene.routes[0].active, "dead ball freezes athletes and routes")
	old_ticks = rules.ticks_remaining
	await step_frames(10)
	check(rules.ticks_remaining == old_ticks, "dead-ball scene stops clock")
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.PRE_SNAP and match_scene.quarterback.position.x == 700, "next formation uses advanced LOS")
	check(match_scene.routes[0].origin == match_scene.receivers[0].position, "routes rebase to new formation")
	key_press(KEY_ENTER)
	match_scene.quarterback.position = Vector2(1240, 180)
	await step_frames(2)
	check(rules.scores == [6, 0] and rules.phase == MatchRules.Phase.DEAD_BALL, "running across goal scores touchdown")
	check(end_count == 2, "first down and touchdown each end play once")
	await step_frames(5)
	check(rules.scores == [6, 0] and end_count == 2, "remaining in end zone cannot score repeatedly")
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.POSSESSION_CHANGE and rules.offense == 1, "Enter enters observable possession change")
	check(rules.line_of_scrimmage == 1040 and match_scene.quarterback.position.x == 1080, "new team formation mirrors from own ten")
	check(match_scene.receivers[0].jersey_color != Color("51b9f2") and match_scene.defenders[0].jersey_color == Color("51b9f2"), "offense and defense team colors swap")
	check(match_scene.routes[0].waypoint_position(0).x < match_scene.routes[0].origin.x, "receiver waypoints mirror leftward")
	check(match_scene.defensive_brains[0].coverage_offset.x < 0, "coverage cushion mirrors with direction")
	check(match_scene.quarterback.movement_locked and match_scene.camera.target == match_scene.quarterback, "possession-change camera and freeze reset")
	old_ticks = rules.ticks_remaining
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.PRE_SNAP and rules.ticks_remaining == old_ticks, "possession-change advances without clock loss")
	key_press(KEY_ENTER)
	await step_frames(15)
	check(match_scene.receivers[0].position.x < 1040, "mirrored route actually moves left")
	match_scene.quarterback.position = Vector2(240, 180)
	await step_frames(2)
	check(rules.scores == [6, 6], "leftward run scores for red")
	# Return to blue, then exercise real swept catches and interceptions.
	match_scene.advance_play()
	match_scene.advance_play()
	match_scene.snap_play()
	for route: ReceiverRoute in match_scene.routes:
		route.stop()
	match_scene.receivers[0].position = Vector2(1240, 180)
	match_scene.quarterback.position = Vector2(1100, 180)
	check(match_scene.throw_at(Vector2(1240, 180)), "end-zone pass launches through normal passing API")
	await step_frames(25)
	check(rules.scores == [12, 6] and match_scene.ball.holder == match_scene.receivers[0], "end-zone catch awards touchdown and preserves catch possession")
	match_scene.restart_match()
	match_scene.defense_enabled = true
	match_scene.snap_play()
	for brain: DefenderAI in match_scene.defensive_brains:
		brain.set_physics_process(false)
	for route: ReceiverRoute in match_scene.routes:
		route.stop()
	for defender: FlagPlayer in match_scene.defenders:
		defender.position = Vector2(1000, 290)
	match_scene.defenders[0].position = Vector2(500, 180)
	match_scene.throw_at(Vector2(600, 180))
	await step_frames(25)
	check(rules.pending_possession and rules.last_result == "INTERCEPTION / TURNOVER", "real pass interception schedules possession change")
	check(rules.phase == MatchRules.Phase.DEAD_BALL and match_scene.ball.holder == match_scene.defenders[0], "interception freezes in dead ball with defensive holder")
	key_press(KEY_ENTER)
	check(rules.offense == 1 and rules.line_of_scrimmage == 500 and rules.midfield_earned, "interception at opposing-side spot starts goal-to-go drive")
	check(match_scene.ball.holder == match_scene.quarterback and match_scene.ball.eligible_interceptors.is_empty(), "formation clears pass candidates and reassigns QB possession")
	match_scene.restart_match()
	match_scene.defense_enabled = false
	for attempt: int in range(4):
		match_scene.snap_play()
		match_scene.throw_at(Vector2(300, 180))
		await step_frames(20)
		check(rules.line_of_scrimmage == 440, "incomplete pass keeps original LOS")
		if attempt < 3:
			key_press(KEY_ENTER)
	check(rules.pending_possession and rules.down == 4, "four scene incompletes cause turnover on downs")
	key_press(KEY_ENTER)
	check(rules.offense == 1 and rules.line_of_scrimmage == 440, "turnover on downs swaps team at unchanged spot")
	match_scene.restart_match()
	match_scene.snap_play()
	match_scene.quarterback.position = Vector2(650, 48)
	await step_frames(2)
	check(rules.phase == MatchRules.Phase.DEAD_BALL and rules.line_of_scrimmage == 650 and rules.down == 2, "solid sideline wall triggers runner out-of-bounds and updates down")
	match_scene.game_duration_seconds = 1
	match_scene.restart_match()
	match_scene.snap_play()
	await step_frames(65)
	check(rules.ticks_remaining == 0 and rules.phase == MatchRules.Phase.LIVE_PLAY, "live final play remains after clock horn")
	match_scene.quarterback.position = Vector2(1240, 180)
	await step_frames(2)
	check(rules.phase == MatchRules.Phase.GAME_OVER and rules.scores == [6, 0], "final live score enters game over")
	check(not match_scene.throw_at(Vector2(1200, 180)), "game-over passing blocked")
	key_press(KEY_ENTER)
	check(rules.phase == MatchRules.Phase.GAME_OVER, "Enter cannot start another play after game over")
	await step_frames(2)
	var scoreboard: Label = match_scene.get_node("HUD/Scoreboard")
	check("BLUE 06" in scoreboard.text and "RED 00" in scoreboard.text and "00:00" in scoreboard.text, "scoreboard reflects authoritative score and expired clock")
	check("BLUE WINS" in match_scene.status.text, "HUD reports winner at game over")
	key_press(KEY_R)
	check(rules.phase == MatchRules.Phase.PRE_SNAP and rules.scores == [0, 0] and rules.ticks_remaining == 60, "R starts clean game after game over")
	check(match_scene.quarterback.movement_locked and match_scene.ball.holder == match_scene.quarterback, "new game resets formation, possession, and pre-snap lock")
	print("Match integration checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
