extends SceneTree

var failures: int = 0
var match_scene: Node2D

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

func run_checks() -> void:
	match_scene = load("res://scenes/match/match.tscn").instantiate()
	# Isolate offensive regression checks; defense_check exercises contested passes.
	match_scene.defense_enabled = false
	root.add_child(match_scene)
	current_scene = match_scene
	await step_frames(3)
	restart_fixture()
	check(match_scene.ball.holder == match_scene.quarterback, "QB starts with possession")
	check(not match_scene.throw_at(Vector2(600, 100)), "throw rejected before snap")
	var first_start: Vector2 = match_scene.receivers[0].position
	await step_frames(20)
	check(match_scene.receivers[0].position == first_start, "receivers wait for snap")
	match_scene.snap_play()
	await step_frames(20)
	check(match_scene.receivers[0].position.x > first_start.x + 10, "first receiver runs after snap")
	check(match_scene.receivers[1].position.x > 500, "second receiver runs after snap")
	var moving_target: FlagPlayer = match_scene.receivers[0]
	check(match_scene.throw_at(moving_target.position + Vector2(45, 0)), "lead pass launches toward moving receiver")
	await step_frames(45)
	check(match_scene.ball.holder == moving_target, "moving route receiver catches lead pass")
	restart_fixture()
	match_scene.snap_play()
	await step_frames(300)
	for route: ReceiverRoute in match_scene.routes:
		check(not route.active and route.waypoint_index == route.waypoint_offsets.size(), "route reaches final waypoint")
		check(route.runner.position.distance_to(route.origin + route.waypoint_offsets[-1]) < 9, "receiver holds near route endpoint")
	for receiver: FlagPlayer in match_scene.receivers:
		restart_fixture()
		match_scene.snap_play()
		await step_frames(320)
		check(match_scene.throw_at(receiver.global_position), "QB can launch pass to " + receiver.role_name)
		check(not match_scene.throw_at(receiver.global_position), "duplicate throw rejected in flight")
		await step_frames(80)
		check(match_scene.ball.holder == receiver, "pass caught by " + receiver.role_name)
		check(match_scene.controlled_player == receiver and not match_scene.quarterback.control_enabled, "exclusive control transfers to receiver")
		check(match_scene.camera.target == receiver, "camera transfers to carrier")
		var before: Vector2 = receiver.position
		var qb_before: Vector2 = match_scene.quarterback.position
		Input.action_press("move_right")
		await step_frames(20)
		Input.action_release("move_right")
		check(receiver.position.x > before.x + 10, "WASD moves caught-ball carrier")
		check(match_scene.quarterback.position == qb_before, "WASD no longer moves QB")
		await step_frames(12)
		check(match_scene.ball.global_position.distance_to(receiver.global_position + Vector2(10, 0)) < 1, "held ball follows carrier")
	restart_fixture()
	match_scene.snap_play()
	check(not match_scene.throw_at(match_scene.quarterback.position), "zero-length aim rejected")
	check(match_scene.throw_at(Vector2(340, 180)), "empty-space pass launches")
	await step_frames(25)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL and match_scene.ball.holder == null, "missed pass drops and ends play")
	check(not match_scene.throw_at(Vector2(600, 180)), "throw rejected after incomplete")
	restart_fixture()
	check(match_scene.ball.holder == match_scene.quarterback and match_scene.controlled_player == match_scene.quarterback, "reset restores QB possession and control")
	check(match_scene.receivers[0].position == first_start, "reset restores receiver formation")
	match_scene.snap_play()
	match_scene.throw_at(Vector2(5000, 180))
	check(is_equal_approx(match_scene.ball.target_position.distance_to(match_scene.quarterback.position), 420), "throw range capped at 420 pixels")
	restart_fixture()
	match_scene.quarterback.position = Vector2(1400, 180)
	match_scene.snap_play()
	match_scene.throw_at(Vector2(1600, 180))
	await step_frames(40)
	check(match_scene.rules.phase == MatchRules.Phase.DEAD_BALL and "INCOMPLETE" in match_scene.status.text, "out-of-bounds pass is an incomplete")
	# A one-frame long sweep must still catch instead of tunnelling through a receiver.
	restart_fixture()
	match_scene.snap_play()
	for route: ReceiverRoute in match_scene.routes:
		route.stop()
	match_scene.receivers[0].position = Vector2(540, 180)
	match_scene.ball.flight_speed = 20000
	match_scene.throw_at(Vector2(700, 180))
	await step_frames(3)
	check(match_scene.ball.holder == match_scene.receivers[0], "swept detection catches high-speed pass")
	restart_fixture()
	await step_frames(3)
	check(not match_scene.ball.in_flight and match_scene.ball.holder == match_scene.quarterback, "reset clears previous flight state")
	var enter_event: InputEventKey = InputEventKey.new()
	enter_event.physical_keycode = KEY_ENTER
	enter_event.pressed = true
	root.push_input(enter_event)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY, "Enter input snaps play")
	await step_frames(2)
	var world_aim: Vector2 = Vector2(600, 80)
	var mouse_position: Vector2 = match_scene.get_canvas_transform() * world_aim
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = mouse_position
	root.push_input(motion, true)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mouse_position
	root.push_input(click, true)
	check(match_scene.ball.in_flight, "left-click input launches football")
	check(match_scene.ball.target_position.distance_to(world_aim) < 1, "mouse aim converts through scrolling camera to world position")
	root.push_input(enter_event)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY and match_scene.ball.in_flight, "Enter cannot cancel an in-flight play")
	print("Offense failures: ", failures)
	quit(1 if failures else 0)


func restart_fixture() -> void:
	# Preserve the original offense layout while isolating passing from match progression.
	match_scene.restart_match()
	match_scene.quarterback.position = Vector2(440, 180)
	match_scene.receivers[0].position = Vector2(490, 100)
	match_scene.receivers[1].position = Vector2(490, 260)
	for route: ReceiverRoute in match_scene.routes:
		route.origin = route.runner.position
