extends SceneTree
## Integration fixtures place athletes deliberately; the real match/ball/AI run unchanged.

var failures: int = 0
var match_scene: Node2D
var end_events: Array[String] = []
var pull_events: int = 0
var interception_events: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func step_frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
	await process_frame


func press_key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)


func fixture() -> void:
	Input.action_release("move_right")
	Input.action_release("sprint")
	Input.action_release("juke")
	match_scene.restart_match()
	match_scene.ball.flight_speed = 400.0
	match_scene.quarterback.position = Vector2(440, 180)
	match_scene.receivers[0].position = Vector2(490, 100)
	match_scene.receivers[1].position = Vector2(490, 260)
	for route: ReceiverRoute in match_scene.routes:
		route.origin = route.runner.position
	for index: int in range(match_scene.defenders.size()):
		match_scene.defenders[index].position = Vector2(1250 + index * 25, 290)
		match_scene.defensive_brains[index].set_physics_process(false)
	for route: ReceiverRoute in match_scene.routes:
		route.set_physics_process(false)
	match_scene.snap_play()


func run_checks() -> void:
	match_scene = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(match_scene)
	current_scene = match_scene
	match_scene.play_ended.connect(func(reason: String) -> void: end_events.append(reason))
	match_scene.flag_pulled.connect(func(_defender: FlagPlayer, _carrier: FlagPlayer) -> void: pull_events += 1)
	match_scene.ball.intercepted.connect(func(_defender: FlagPlayer) -> void: interception_events += 1)
	await step_frames(3)
	check(match_scene.defenders.size() == 5, "five defenders are instantiated")
	for brain: DefenderAI in match_scene.defensive_brains:
		check(brain.assignment != null and brain.state == DefenderAI.State.IDLE, "defender has man assignment and waits for snap")
	var possession: FlagPlayer = match_scene.ball.holder
	for index: int in range(6):
		press_key(KEY_TAB)
		check(match_scene.controlled_player == match_scene.defenders[index % 5], "Tab cycles defender " + str(index % 5 + 1))
		var controlled_count: int = 0
		for athlete: FlagPlayer in match_scene._all_athletes():
			if athlete.control_enabled:
				controlled_count += 1
		check(controlled_count == 1 and match_scene.camera.target == match_scene.controlled_player, "selection is exclusive and camera follows")
	check(match_scene.ball.holder == possession, "defender switching does not change possession")
	press_key(KEY_Q)
	check(match_scene.controlled_player == match_scene.quarterback, "Q returns to offensive carrier")
	match_scene.snap_play()
	await step_frames(15)
	check(match_scene.defensive_brains[0].state == DefenderAI.State.MAN_COVERAGE, "assigned receiver activates man coverage")
	check(match_scene.defenders[0].position.x < 575, "coverage steers toward moving assignment")
	check(match_scene.defenders[2].velocity.is_zero_approx(), "QB rusher respects snap delay")
	fixture()
	var defender: FlagPlayer = match_scene.defenders[0]
	var brain: DefenderAI = match_scene.defensive_brains[0]
	defender.position = Vector2(600, 80)
	brain.set_physics_process(true)
	var carrier: FlagPlayer = match_scene.receivers[0]
	carrier.position = Vector2(520, 100)
	match_scene.ball.possess(carrier)
	match_scene._on_caught(carrier)
	var distance_before: float = defender.position.distance_to(carrier.position)
	await step_frames(15)
	check(brain.state == DefenderAI.State.PURSUIT, "catch changes coverage to carrier pursuit")
	check(defender.position.distance_to(carrier.position) < distance_before - 10, "pursuit closes distance to carrier")
	fixture()
	defender.position = Vector2(490, 180)
	brain.set_physics_process(true)
	match_scene.throw_at(Vector2(600, 180))
	await step_frames(2)
	check(brain.state == DefenderAI.State.INTERCEPT, "nearby in-flight pass activates interception state")
	await step_frames(20)
	check(match_scene.ball.holder == defender and match_scene.rules.phase == MatchRules.Phase.DEAD_BALL, "defender intercepts flight and ends play as turnover")
	check(match_scene.controlled_player == defender and defender.has_ball, "interception transfers possession and selection")
	check(not match_scene.quarterback.has_ball and interception_events == 1, "interception emits once and clears QB possession")
	check(not match_scene.throw_at(Vector2(600, 100)), "passing blocked after turnover")
	var stopped_position: Vector2 = defender.position
	Input.action_press("move_right")
	await step_frames(10)
	Input.action_release("move_right")
	check(defender.position == stopped_position, "turnover freezes movement until reset")
	fixture()
	carrier = match_scene.receivers[0]
	carrier.position = Vector2(600, 180)
	defender.position = Vector2(520, 180)
	match_scene.ball.flight_speed = 20000
	match_scene.throw_at(Vector2(680, 180))
	await step_frames(2)
	check(match_scene.ball.holder == defender, "swept interception beats receiver farther along pass")
	fixture()
	carrier.position = Vector2(520, 180)
	defender.position = Vector2(620, 180)
	match_scene.ball.flight_speed = 20000
	match_scene.throw_at(Vector2(680, 180))
	await step_frames(2)
	check(match_scene.ball.holder == carrier and match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY, "receiver catches before defender farther downfield")
	check(match_scene.controlled_player == carrier, "offensive catch still transfers control")
	var receiver_abilities: AthleteAbilities = carrier.get_node("Abilities")
	check(receiver_abilities.try_juke(Vector2.UP), "caught-ball receiver can juke")
	fixture()
	carrier.position = Vector2(540, 180)
	defender.position = carrier.position
	match_scene.ball.flight_speed = 20000
	match_scene.throw_at(Vector2(680, 180))
	await step_frames(2)
	check(match_scene.ball.holder == defender, "defense wins an exactly tied contested catch")
	fixture()
	defender.position = match_scene.quarterback.position + Vector2(17, 0)
	brain.set_physics_process(true)
	var pulls_before_flight: int = pull_events
	match_scene.throw_at(Vector2(440, 80))
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY and match_scene.ball.in_flight and pull_events == pulls_before_flight, "no flag pull during a pass with no ball carrier")
	check(not match_scene.quarterback.get_node("Abilities").try_juke(Vector2.RIGHT), "QB cannot juke after releasing ball")
	fixture()
	carrier.position = Vector2(540, 180)
	match_scene.throw_at(carrier.position)
	press_key(KEY_TAB)
	await step_frames(20)
	check(match_scene.ball.holder == carrier and match_scene.controlled_player == defender, "catch preserves explicitly selected defender")
	press_key(KEY_Q)
	check(match_scene.controlled_player == carrier, "Q returns to receiver after catch")
	fixture()
	defender.position = match_scene.quarterback.position + Vector2(19, 0)
	brain.set_physics_process(true)
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY, "outside flag range does not end play")
	defender.position = match_scene.quarterback.position + Vector2(17, 0)
	var previous_ends: int = end_events.size()
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL and pull_events == 1, "flag pull in range ends QB play")
	brain._physics_process(0.0)
	check(end_events.size() == previous_ends + 1, "flag pull emits one play-ended event")
	check(match_scene.routes[0].active == false and match_scene.quarterback.velocity == Vector2.ZERO, "flag pull stops routes and movement")
	fixture()
	carrier = match_scene.receivers[1]
	match_scene.ball.possess(carrier)
	match_scene._on_caught(carrier)
	defender.position = carrier.position + Vector2(10, 0)
	brain.set_physics_process(true)
	press_key(KEY_TAB)
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL and pull_events == 2, "user-selected defender pulls receiver flag")
	fixture()
	var qb: FlagPlayer = match_scene.quarterback
	var abilities: AthleteAbilities = qb.get_node("Abilities")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await step_frames(25)
	check(is_equal_approx(qb.velocity.length(), qb.max_speed * abilities.sprint_multiplier), "Shift increases live carrier speed")
	Input.action_release("sprint")
	await step_frames(15)
	check(is_equal_approx(qb.velocity.length(), qb.max_speed), "release Shift returns to normal speed")
	Input.action_release("move_right")
	await step_frames(15)
	Input.action_press("move_right")
	Input.action_press("juke")
	await step_frames(2)
	Input.action_release("juke")
	Input.action_release("move_right")
	check(qb.is_juking and abilities.cooldown_remaining > 1.0, "Space starts directional juke and cooldown")
	check(not abilities.try_juke(Vector2.RIGHT), "juke cannot repeat during cooldown")
	defender.position = qb.position + Vector2(10, 0)
	brain.set_physics_process(true)
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY, "juke protects carrier from flag pull")
	brain.set_physics_process(false)
	await step_frames(15)
	check(not qb.is_juking and abilities.cooldown_remaining > 0.0, "juke protection expires before cooldown")
	check(not abilities.try_juke(Vector2.RIGHT), "cooldown still blocks a second juke")
	await step_frames(70)
	check(abilities.try_juke(Vector2.DOWN), "juke available after short cooldown")
	abilities.reset()
	defender.position = qb.position + Vector2(10, 0)
	brain._physics_process(0.0)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL, "carrier can be flagged after juke expires")
	fixture()
	press_key(KEY_TAB)
	var defender_abilities: AthleteAbilities = defender.get_node("Abilities")
	check(not defender_abilities.try_juke(Vector2.RIGHT), "non-carrier defender cannot juke")
	check(not match_scene.throw_at(Vector2(600, 180)), "defender selection cannot trigger QB throw")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await step_frames(20)
	check(is_equal_approx(defender.velocity.length(), defender.max_speed * defender_abilities.sprint_multiplier), "selected defender can sprint under WASD control")
	Input.action_release("move_right")
	Input.action_release("sprint")
	fixture()
	qb.position = Vector2(1420, 180)
	abilities.try_juke(Vector2.RIGHT)
	await step_frames(15)
	check(qb.position.x <= 1432.1, "juke respects field collision walls")
	match_scene.restart_match()
	check(not qb.is_juking and abilities.cooldown_remaining == 0.0 and qb.movement_locked, "new match clears abilities and locks pre-snap player")
	check(match_scene.ball.eligible_interceptors.is_empty() and match_scene.ball.holder == qb, "reset clears turnover candidates and restores QB possession")
	check(defender.position == Vector2(530, 80), "reset restores defensive formation")
	check(not abilities.try_juke(Vector2.RIGHT), "pre-snap carrier cannot juke")
	for defensive_brain: DefenderAI in match_scene.defensive_brains:
		defensive_brain.set_physics_process(true)
	for route: ReceiverRoute in match_scene.routes:
		route.set_physics_process(true)
	match_scene.snap_play()
	await step_frames(360)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL and "FLAG PULLED" in match_scene.status.text, "normal formation AI eventually flags stationary QB")
	match_scene.restart_match()
	match_scene.snap_play()
	match_scene.throw_at(match_scene.receivers[0].position + Vector2(30, 0))
	await step_frames(20)
	check(match_scene.ball.holder == match_scene.receivers[0], "early lead pass can complete against normal live coverage")
	print("Defense failures: ", failures)
	quit(1 if failures else 0)
