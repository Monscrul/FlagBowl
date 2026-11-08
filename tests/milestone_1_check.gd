extends SceneTree

var failures: int = 0
var player: CharacterBody2D
var camera: Camera2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func step_frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
	await process_frame

func release_movement() -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)

func run_checks() -> void:
	var scene: PackedScene = load("res://scenes/match/match.tscn")
	var match_scene: Node = scene.instantiate()
	root.add_child(match_scene)
	current_scene = match_scene
	player = match_scene.get_node("Player")
	camera = match_scene.get_node("Camera2D")
	await step_frames(2)
	# Exercise movement/colliders without snapping the rules model or starting a clock.
	player.movement_locked = false
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/match/match.tscn", "startup match configured")
	check(root.get_visible_rect().size == Vector2(640, 360), "internal viewport is 640x360")
	var expected_keys: Dictionary = {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "snap": KEY_ENTER, "sprint": KEY_SHIFT, "juke": KEY_SPACE, "switch_defender": KEY_TAB, "pause": KEY_ESCAPE}
	for action: String in expected_keys:
		var event: InputEventKey = InputMap.action_get_events(action)[0] as InputEventKey
		check(event.physical_keycode == expected_keys[action], "key binding: " + action)
	var mouse_event: InputEventMouseButton = InputMap.action_get_events("throw_ball")[0] as InputEventMouseButton
	check(mouse_event.button_index == MOUSE_BUTTON_LEFT, "left-click throw binding")
	Input.action_press("move_right")
	await step_frames(3)
	check(player.velocity.x > 0.0 and player.velocity.x < 150.0, "acceleration ramps toward maximum speed")
	await step_frames(12)
	check(is_equal_approx(player.velocity.length(), 150.0), "cardinal speed reaches 150 px/s")
	Input.action_press("move_down")
	await step_frames(12)
	check(is_equal_approx(player.velocity.length(), 150.0), "diagonal speed remains normalized")
	check(player.velocity.y > 0.0, "vertical movement works")
	release_movement()
	await step_frames(2)
	check(player.velocity.length() > 0.0 and player.velocity.length() < 150.0, "release decelerates smoothly")
	await step_frames(12)
	check(player.velocity == Vector2.ZERO, "runner stops after release")
	player.position = Vector2(740, 180)
	Input.action_press("move_right")
	await step_frames(350)
	check(player.position.x <= 1432.1 and player.position.x >= 1431.0, "right wall contains runner")
	check(camera.get_screen_center_position().is_equal_approx(Vector2(1160, 180)), "camera clamps at right edge")
	release_movement()
	Input.action_press("move_left")
	await step_frames(650)
	check(player.position.x >= 47.9 and player.position.x <= 49.0, "left wall contains runner")
	check(camera.get_screen_center_position().is_equal_approx(Vector2(320, 180)), "camera clamps at left edge")
	release_movement()
	player.position = Vector2(740, 180)
	player.velocity = Vector2.ZERO
	Input.action_press("move_up")
	await step_frames(100)
	check(player.position.y >= 47.9 and player.position.y <= 49.0, "top wall contains runner")
	check(is_equal_approx(camera.get_screen_center_position().y, 180), "camera stays vertically fixed")
	Input.action_press("move_right")
	var previous_x: float = player.position.x
	await step_frames(40)
	check(player.position.x > previous_x + 20 and player.position.y >= 47.9, "runner slides along boundary")
	release_movement()
	Input.action_press("move_down")
	await step_frames(160)
	check(player.position.y <= 312.1 and player.position.y >= 311.0, "bottom wall contains runner")
	release_movement()
	print("Milestone 1 failures: ", failures)
	quit(1 if failures else 0)
