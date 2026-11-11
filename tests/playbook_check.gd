extends SceneTree

var failures: int = 0
var checks: int = 0
var match_scene: Node2D
var ai_passes: int = 0


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


func key_press(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)


func red_fixture() -> void:
	Input.action_release("move_right")
	match_scene.restart_match()
	match_scene.auto_flow_enabled = false
	match_scene.defense_enabled = true
	# Legal rule events establish an opposing drive without assigning team/phase fields.
	for down: int in range(4):
		match_scene.snap_play()
		match_scene._end_play(MatchRules.Result.INCOMPLETE, Vector2(440, 180))
		match_scene.advance_play()
	match_scene.advance_play()


func run_checks() -> void:
	var book: OffensivePlaybook = load("res://resources/playbook/default_playbook.tres")
	check(book.is_valid() and book.plays.size() == 5, "five valid typed play Resources load from disk")
	var names: Array[String] = ["Cross", "Slants", "Outs", "Curls", "Streaks"]
	for index: int in range(5):
		check(book.plays[index].display_name == names[index] and book.plays[index].is_valid(), "authored play: " + names[index])
	var invalid: OffensivePlay = OffensivePlay.new()
	check(not invalid.is_valid(), "empty play rejected")
	invalid.display_name = "Invalid"
	invalid.receiver_one_route = PackedVector2Array([Vector2(NAN, 0)])
	invalid.receiver_two_route = PackedVector2Array([Vector2.ONE])
	check(not invalid.is_valid(), "nonfinite route rejected")
	match_scene = load("res://scenes/match/match.tscn").instantiate()
	match_scene.auto_flow_enabled = false
	root.add_child(match_scene)
	current_scene = match_scene
	match_scene.pass_thrown.connect(func() -> void:
		if match_scene.is_ai_offense():
			ai_passes += 1
	)
	await step_frames(3)
	var selection: PanelContainer = match_scene.get_node("HUD/PlaySelection")
	check(selection.visible and selection.buttons.size() == 5, "human pre-snap play selection visible")
	key_press(KEY_TAB)
	check(match_scene.controlled_player == match_scene.quarterback, "human offense cannot take over opposing defenders")
	for index: int in range(5):
		key_press(KEY_1 + index)
		check(match_scene.selected_play() == book.plays[index], "number key selects " + names[index])
		check(match_scene.routes[0].waypoint_offsets == book.plays[index].receiver_one_route and match_scene.routes[1].waypoint_offsets == book.plays[index].receiver_two_route, "both receiver routes use selected Resource")
		selection.buttons[(index + 1) % 5].pressed.emit()
		check(match_scene.human_play_index == (index + 1) % 5, "button binds its own play index")
	match_scene.select_play(0)
	var original: PackedVector2Array = book.plays[0].receiver_one_route.duplicate()
	match_scene.routes[0].waypoint_offsets[0] = Vector2(999, 999)
	check(book.plays[0].receiver_one_route == original, "editing runtime route cannot mutate shared Resource")
	match_scene.select_play(0)
	check(match_scene.routes[0].waypoint_offsets == original, "selection restores authored data")
	check(not match_scene.select_play(-1) and not match_scene.select_play(5), "out-of-range play selection rejected")
	match_scene.snap_play()
	await step_frames(3)
	check(not selection.visible and not match_scene.select_play(3), "selection hidden and locked after snap")
	check(not match_scene.request_ai_throw(Vector2(600, 180)), "AI throw entry cannot control human offense")
	for index: int in range(5):
		match_scene.restart_match()
		match_scene.select_play(index)
		match_scene.snap_play()
		match_scene.defense_enabled = false
		await step_frames(330)
		check(not match_scene.routes[0].active and not match_scene.routes[1].active, "both routes complete for " + names[index])
	red_fixture()
	await step_frames(2)
	check(match_scene.is_ai_offense() and match_scene.controlled_player == match_scene.defenders[0], "opposing possession selects a human defender")
	check(not selection.visible and not match_scene.select_play(2), "human cannot call opposing plays")
	key_press(KEY_Q)
	check(match_scene.controlled_player == match_scene.defenders[0], "Q cannot take over AI quarterback")
	for index: int in range(1, 6):
		key_press(KEY_TAB)
		check(match_scene.controlled_player == match_scene.defenders[index % 5], "Tab switches human defender during opposing possession")
	match_scene.defense_enabled = false
	match_scene.auto_flow_enabled = true
	await step_frames(95)
	check(match_scene.rules.phase == MatchRules.Phase.LIVE_PLAY, "opposing offense snaps automatically")
	check(not match_scene.throw_at(Vector2(300, 180)), "human throw blocked during defensive possession")
	check(match_scene.routes[0].attack_direction == -1 and match_scene.receivers[0].position.x < 440, "opposing receiver follows mirrored Resource route")
	var defensive_start: Vector2 = match_scene.controlled_player.position
	Input.action_press("move_right")
	await step_frames(6)
	Input.action_release("move_right")
	check(match_scene.controlled_player.position.x > defensive_start.x + 2, "WASD moves the human defender while AI controls offense")
	match_scene.auto_flow_enabled = false
	var caught: bool = false
	for frame: int in range(180):
		await step_frames(1)
		if match_scene.receivers.has(match_scene.ball.holder):
			caught = true
			break
	check(ai_passes > 0 and caught, "AI reads, leads and completes a pass to a moving receiver")
	if caught:
		var receiver: FlagPlayer = match_scene.ball.holder
		var before: float = receiver.position.x
		var selected: FlagPlayer = match_scene.controlled_player
		await step_frames(20)
		check(receiver.position.x < before - 10, "AI caught-ball carrier runs toward opponent goal")
		check(match_scene.controlled_player == selected and match_scene.defenders.has(selected), "AI catch preserves human defensive control")
	await step_frames(240)
	check(match_scene.rules.scores[1] == 6, "AI can finish a drive with a touchdown")
	red_fixture()
	match_scene.defense_enabled = true
	for brain: DefenderAI in match_scene.defensive_brains:
		brain.set_physics_process(false)
	match_scene.defenders[0].position = match_scene.quarterback.position
	match_scene.snap_play()
	await step_frames(30)
	check(match_scene.opposing_offense.best_receiver() == null, "AI rejects passing lanes occupied by a defender")
	var qb_before: float = match_scene.quarterback.position.x
	await step_frames(60)
	check(not match_scene.opposing_offense.last_decision.is_empty(), "covered receivers produce a bounded-time QB decision")
	check(match_scene.quarterback.position.x < qb_before, "QB scrambles upfield when reads are covered")
	# Iterate AI play calls through legal plays, checking a deterministic five-play cycle.
	red_fixture()
	match_scene.defense_enabled = false
	for index: int in range(5):
		check(match_scene.selected_play() == book.plays[index], "opponent calls Resource " + names[index])
		check(match_scene.routes[0].waypoint_position(0).x <= match_scene.routes[0].origin.x, "AI route remains mirrored for " + names[index])
		match_scene.snap_play()
		match_scene._end_play(MatchRules.Result.FLAG_PULL, Vector2(440 - (index + 1) * 10, 180))
		if match_scene.rules.pending_possession:
			# Start a fresh Red drive through Blue's four downs; AI play count persists.
			match_scene.advance_play()
			match_scene.advance_play()
			for down: int in range(4):
				match_scene.snap_play()
				match_scene._end_play(MatchRules.Result.INCOMPLETE, Vector2(match_scene.rules.line_of_scrimmage, 180))
				match_scene.advance_play()
			match_scene.advance_play()
		else:
			match_scene.advance_play()
	# A final stalled play is guaranteed to finish even with no defense.
	match_scene.restart_match()
	match_scene.game_duration_seconds = 1
	match_scene.restart_match()
	match_scene.auto_flow_enabled = false
	match_scene.snap_play()
	await step_frames(1210)
	check(match_scene.rules.phase == MatchRules.Phase.GAME_OVER and match_scene.rules.ticks_remaining == 0, "20-second live limit finishes a stalled final play")
	check(match_scene.quarterback.movement_locked and not match_scene.routes[0].active, "play limit freezes scene along with rules")
	# Invalid authoring data falls back before child UI initialization.
	var other: Node2D = load("res://scenes/match/match.tscn").instantiate()
	other.playbook = OffensivePlaybook.new()
	root.add_child(other)
	check(other.playbook == book, "invalid exported playbook uses valid default before UI reads it")
	other.queue_free()
	print("Playbook/AI checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
