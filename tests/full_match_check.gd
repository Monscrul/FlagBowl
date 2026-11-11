extends SceneTree
## Full default-duration match using only human-facing input and automatic flow.
## No teleports, injected scores/results, manual rule advancement, or defense disabling.

var failures: int = 0
var checks: int = 0
var match_scene: Node2D
var human_snaps: int = 0
var ai_snaps: int = 0
var ai_passes: int = 0
var ai_catches: int = 0
var defense_switches: int = 0
var completed_plays: int = 0
var saw_possession_change: bool = false
var bad_human_selection: bool = false
var play_calls: Array[String] = []


func _initialize() -> void:
	call_deferred("run_match")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func key_press(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func throw_click(world_position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = match_scene.get_canvas_transform() * world_position
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func release_movement() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		Input.action_release(action)


func run_match() -> void:
	match_scene = load("res://scenes/match/match.tscn").instantiate()
	root.add_child(match_scene)
	current_scene = match_scene
	match_scene.play_started.connect(func() -> void:
		if match_scene.is_ai_offense():
			ai_snaps += 1
		else:
			human_snaps += 1
		if not play_calls.has(match_scene.selected_play().display_name):
			play_calls.append(match_scene.selected_play().display_name)
	)
	match_scene.pass_thrown.connect(func() -> void:
		if match_scene.is_ai_offense():
			ai_passes += 1
	)
	match_scene.ball.caught.connect(func(_receiver: FlagPlayer) -> void:
		if match_scene.is_ai_offense():
			ai_catches += 1
	)
	match_scene.play_ended.connect(func(_reason: String) -> void: completed_plays += 1)
	await process_frame
	check(match_scene.rules.seconds_remaining() == 300 and match_scene.rules.offense == 0, "kickoff-equivalent start is Blue own-ten at five minutes")
	var finished: bool = false
	for frame: int in range(200000):
		await physics_frame
		var rules: MatchRules = match_scene.rules
		if rules.phase == MatchRules.Phase.GAME_OVER:
			finished = true
			break
		if rules.phase == MatchRules.Phase.POSSESSION_CHANGE:
			saw_possession_change = true
		if rules.phase == MatchRules.Phase.PRE_SNAP and not match_scene.is_ai_offense():
			release_movement()
			key_press(KEY_1 + human_snaps % 5)
			key_press(KEY_ENTER)
		elif rules.phase == MatchRules.Phase.LIVE_PLAY and not match_scene.is_ai_offense():
			release_movement()
			if human_snaps % 4 == 1 and match_scene.ball.holder == match_scene.quarterback:
				# Deliberate misses exercise four-down turnovers without fixture shortcuts.
				throw_click(match_scene.quarterback.global_position + Vector2(-85, 0))
			elif match_scene.ball.holder != null:
				Input.action_press("move_right")
				Input.action_press("sprint")
		elif rules.phase == MatchRules.Phase.LIVE_PLAY and match_scene.is_ai_offense():
			if not match_scene.defenders.has(match_scene.controlled_player):
				bad_human_selection = true
			if frame % 45 == 0:
				key_press(KEY_TAB)
				defense_switches += 1
			var target: Vector2 = match_scene.ball.global_position
			var displacement: Vector2 = target - match_scene.controlled_player.global_position
			Input.action_press("move_left") if displacement.x < -4 else Input.action_release("move_left")
			Input.action_press("move_right") if displacement.x > 4 else Input.action_release("move_right")
			Input.action_press("move_up") if displacement.y < -4 else Input.action_release("move_up")
			Input.action_press("move_down") if displacement.y > 4 else Input.action_release("move_down")
			Input.action_press("sprint")
		else:
			release_movement()
	release_movement()
	await process_frame
	check(finished and match_scene.rules.phase == MatchRules.Phase.GAME_OVER, "complete default match reaches final without debugging or injected results")
	check(match_scene.rules.ticks_remaining == 0, "full five minutes of live game clock consumed")
	check(human_snaps >= 4 and ai_snaps >= 4 and completed_plays >= 8, "both offenses complete multiple real plays")
	check(ai_passes > 0, "opposing QB attempts real passes against live defense")
	check(saw_possession_change and defense_switches > 0 and not bad_human_selection, "automatic possessions preserve switchable human defensive control")
	check(play_calls.size() == 5, "all five play resources used during complete match")
	var scoreboard: Label = match_scene.get_node("HUD/Scoreboard")
	check("00:00" in scoreboard.text and "FINAL:" in match_scene.status.text, "final score and outcome are visible")
	check(match_scene.quarterback.movement_locked and not match_scene.routes[0].active and not match_scene.ball.in_flight, "game over stops routes, flight, and movement")
	var final_scores: Array[int] = match_scene.rules.scores.duplicate()
	key_press(KEY_ENTER)
	check(match_scene.rules.scores == final_scores and match_scene.rules.phase == MatchRules.Phase.GAME_OVER, "final score is stable and Enter cannot replay final down")
	key_press(KEY_R)
	check(match_scene.rules.scores == [0, 0] and match_scene.rules.seconds_remaining() == 300 and match_scene.controlled_player == match_scene.quarterback, "R restarts into selectable human offense")
	print("Full-match stats: scores=", final_scores, ", human snaps=", human_snaps, ", AI snaps=", ai_snaps, ", AI passes=", ai_passes, ", AI catches=", ai_catches, ", defensive switches=", defense_switches)
	print("Full-match checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
