extends Node2D
## Scene adapter: rules own all match data; nodes own movement and ball flight.

signal play_started
signal pass_thrown
signal possession_changed(carrier: FlagPlayer)
signal play_ended(reason: String)
signal control_changed(athlete: FlagPlayer)
signal flag_pulled(defender: FlagPlayer, carrier: FlagPlayer)

@export var defense_enabled: bool = true
@export_range(0, 3600) var game_duration_seconds: int = 300

var rules: MatchRules = MatchRules.new()
var controlled_player: FlagPlayer
var receivers: Array[FlagPlayer] = []
var routes: Array[ReceiverRoute] = []
var defenders: Array[FlagPlayer] = []
var defensive_brains: Array[DefenderAI] = []
var _defender_index: int = -1

@onready var quarterback: FlagPlayer = $Player
@onready var ball: Football = $Football
@onready var camera: Camera2D = $Camera2D
@onready var status: Label = $HUD/Controls


func _ready() -> void:
	receivers.assign([$ReceiverOne, $ReceiverTwo])
	routes.assign([$ReceiverOne/Route, $ReceiverTwo/Route])
	defenders.assign([$DefenderOne, $DefenderTwo, $DefenderThree, $DefenderFour, $DefenderFive])
	var assignments: Array[FlagPlayer] = [receivers[0], receivers[1], quarterback, receivers[0], receivers[1]]
	for index: int in range(defenders.size()):
		var brain: DefenderAI = defenders[index].get_node("DefenseAI")
		brain.director = self
		brain.assignment = assignments[index]
		brain.rush_delay = 1.5 if index == 2 else 0.0
		brain.flag_pull_requested.connect(_on_flag_pull_requested)
		defensive_brains.append(brain)
	ball.caught.connect(_on_caught)
	ball.dropped.connect(_on_dropped)
	ball.intercepted.connect(_on_intercepted)
	restart_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("snap") and not event.is_echo():
		if rules.phase == MatchRules.Phase.PRE_SNAP:
			snap_play()
		else:
			advance_play()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_match") and not event.is_echo():
		if rules.phase == MatchRules.Phase.GAME_OVER:
			restart_match()
	elif event.is_action_pressed("switch_defender") and not event.is_echo():
		switch_defender()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("control_offense") and not event.is_echo():
		select_offense()
	elif event.is_action_pressed("throw_ball"):
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null:
			throw_at(get_canvas_transform().affine_inverse() * click.position)


func restart_match() -> void:
	rules.start_game(game_duration_seconds, Engine.physics_ticks_per_second)
	reset_play()


func advance_play() -> bool:
	if not rules.advance():
		return false
	reset_play()
	return true


func snap_play() -> void:
	if not rules.snap():
		return
	for athlete: FlagPlayer in _all_athletes():
		athlete.play_active = true
		athlete.movement_locked = false
	for route: ReceiverRoute in routes:
		route.start()
	play_started.emit()


func throw_at(world_position: Vector2) -> bool:
	if rules.phase != MatchRules.Phase.LIVE_PLAY or controlled_player != quarterback:
		return false
	# Ball state distinguishes a held ball, a pass in flight, and a catch.
	if ball.holder != quarterback:
		return false
	var interceptors: Array[FlagPlayer] = []
	if defense_enabled:
		interceptors.assign(defenders)
	if not ball.launch(world_position, receivers, interceptors):
		return false
	pass_thrown.emit()
	return true


func reset_play() -> void:
	# Formation placement cannot reset a live play or undo a down.
	if rules.phase not in [MatchRules.Phase.PRE_SNAP, MatchRules.Phase.POSSESSION_CHANGE, MatchRules.Phase.GAME_OVER]:
		return
	_freeze_athletes()
	MatchFormation.arrange(rules, quarterback, receivers, defenders, routes)
	var direction: int = rules.attack_direction()
	var offsets: Array[Vector2] = [Vector2(32, -12), Vector2(32, 12), Vector2.ZERO, Vector2(95, 25), Vector2(95, -25)]
	for index: int in range(defensive_brains.size()):
		defensive_brains[index].reset()
		defensive_brains[index].coverage_offset = Vector2(offsets[index].x * direction, offsets[index].y)
	ball.eligible_interceptors.clear()
	ball.eligible_receivers.clear()
	for athlete: FlagPlayer in _all_athletes():
		athlete.has_ball = false
	_defender_index = -1
	ball.possess(quarterback)
	_set_control(quarterback)
	possession_changed.emit(quarterback)


func _freeze_athletes() -> void:
	for route: ReceiverRoute in routes:
		route.stop()
	for athlete: FlagPlayer in _all_athletes():
		athlete.play_active = false
		athlete.movement_locked = true
		athlete.velocity = Vector2.ZERO
		athlete.ai_direction = Vector2.ZERO
		athlete.get_node("Abilities").reset()
	ball.in_flight = false


func _all_athletes() -> Array[FlagPlayer]:
	var athletes: Array[FlagPlayer] = [quarterback]
	athletes.append_array(receivers)
	athletes.append_array(defenders)
	return athletes


func _set_control(athlete: FlagPlayer) -> void:
	for player: FlagPlayer in _all_athletes():
		player.control_enabled = player == athlete
		player.ai_direction = Vector2.ZERO
		player.queue_redraw()
	controlled_player = athlete
	camera.target = athlete
	control_changed.emit(athlete)


func switch_defender() -> void:
	if not defense_enabled or rules.phase not in [MatchRules.Phase.PRE_SNAP, MatchRules.Phase.LIVE_PLAY]:
		return
	_defender_index = (_defender_index + 1) % defenders.size()
	_set_control(defenders[_defender_index])


func select_offense() -> void:
	if rules.phase not in [MatchRules.Phase.PRE_SNAP, MatchRules.Phase.LIVE_PLAY]:
		return
	_defender_index = -1
	_set_control(ball.holder if ball.holder != null else quarterback)


func _on_caught(receiver: FlagPlayer) -> void:
	if rules.phase != MatchRules.Phase.LIVE_PLAY:
		return
	for route: ReceiverRoute in routes:
		route.stop()
	receiver.velocity = Vector2.ZERO
	if not defenders.has(controlled_player):
		_set_control(receiver)
	possession_changed.emit(receiver)
	_resolve_carrier()


func _on_dropped(_reason: String) -> void:
	# An out-of-bounds pass is incomplete, never a gain to the projectile spot.
	_end_play(MatchRules.Result.INCOMPLETE, Vector2(rules.line_of_scrimmage, 180))


func _on_intercepted(defender: FlagPlayer) -> void:
	if rules.phase != MatchRules.Phase.LIVE_PLAY:
		return
	_set_control(defender)
	possession_changed.emit(defender)
	_end_play(MatchRules.Result.INTERCEPTION, defender.global_position)


func _on_flag_pull_requested(defender: FlagPlayer, carrier: FlagPlayer) -> void:
	if rules.phase != MatchRules.Phase.LIVE_PLAY or not defense_enabled:
		return
	if carrier != ball.holder or carrier.is_juking or not defenders.has(defender):
		return
	var brain: DefenderAI = defender.get_node("DefenseAI")
	if defender.global_position.distance_to(carrier.global_position) > brain.flag_pull_range:
		return
	# Goal-line/sideline resolution has priority over a simultaneous flag pull.
	if _resolve_carrier():
		return
	if _end_play(MatchRules.Result.FLAG_PULL, carrier.global_position):
		flag_pulled.emit(defender, carrier)


func _end_play(result: MatchRules.Result, spot: Vector2) -> bool:
	if not rules.finish_play(result, spot):
		return false
	_freeze_athletes()
	status.text = rules.last_result
	play_ended.emit(rules.last_result)
	return true


func _resolve_carrier() -> bool:
	if rules.phase != MatchRules.Phase.LIVE_PLAY or ball.holder == null or defenders.has(ball.holder):
		return false
	var point: Vector2 = ball.holder.global_position
	if FootballField.carrier_out_of_bounds(point):
		return _end_play(MatchRules.Result.OUT_OF_BOUNDS, point)
	if rules.is_touchdown(point):
		return _end_play(MatchRules.Result.TOUCHDOWN, point)
	return false


func _physics_process(_delta: float) -> void:
	rules.tick()
	_resolve_carrier()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(quarterback):
		return
	# Blue LOS and gold line-to-gain come directly from rules, never scene positions.
	draw_line(Vector2(rules.line_of_scrimmage, 42), Vector2(rules.line_of_scrimmage, 318), Color("7ed9ff"), 2)
	draw_line(Vector2(rules.target_x(), 42), Vector2(rules.target_x(), 318), Color("ffe175"), 2)
	if rules.phase == MatchRules.Phase.PRE_SNAP:
		for route: ReceiverRoute in routes:
			var previous: Vector2 = route.origin
			for index: int in range(route.waypoint_offsets.size()):
				var point: Vector2 = route.waypoint_position(index)
				draw_dashed_line(previous, point, Color(1, 0.9, 0.5, 0.6), 1, 5)
				previous = point
	if rules.phase in [MatchRules.Phase.PRE_SNAP, MatchRules.Phase.LIVE_PLAY] and ball.holder == quarterback and controlled_player == quarterback:
		var start: Vector2 = quarterback.global_position
		var aim: Vector2 = start + (get_global_mouse_position() - start).limit_length(ball.max_range)
		draw_dashed_line(start, aim, Color(1, 1, 1, 0.6), 1, 5)
		draw_arc(aim, 5, 0, TAU, 16, Color.WHITE)
