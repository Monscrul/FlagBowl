class_name Football
extends Node2D
## Straight arcade pass with swept catches, bounded range, and deterministic drops.

signal caught(receiver: FlagPlayer)
signal dropped(reason: String)
signal intercepted(defender: FlagPlayer)

@export var flight_speed: float = 400.0
@export var max_range: float = 420.0
@export var catch_radius: float = 14.0

var holder: FlagPlayer
var in_flight: bool = false
var target_position: Vector2
var eligible_receivers: Array[FlagPlayer] = []
var eligible_interceptors: Array[FlagPlayer] = []


func possess(player: FlagPlayer) -> void:
	if is_instance_valid(holder):
		holder.has_ball = false
	holder = player
	holder.has_ball = true
	in_flight = false
	rotation = 0.0
	global_position = holder.global_position + Vector2(10, 0)


func launch(aim_position: Vector2, receivers: Array[FlagPlayer], defenders: Array[FlagPlayer] = []) -> bool:
	if in_flight or not is_instance_valid(holder):
		return false
	var start: Vector2 = holder.global_position
	var displacement: Vector2 = (aim_position - start).limit_length(max_range)
	if displacement.length() < 12.0:
		return false
	global_position = start
	target_position = start + displacement
	eligible_receivers = receivers.duplicate()
	eligible_interceptors = defenders.duplicate()
	holder.has_ball = false
	holder = null
	in_flight = true
	rotation = displacement.angle()
	return true


func _physics_process(delta: float) -> void:
	if is_instance_valid(holder):
		global_position = holder.global_position + Vector2(10, 0)
		return
	if not in_flight:
		return
	var previous: Vector2 = global_position
	var next: Vector2 = previous.move_toward(target_position, flight_speed * delta)
	# Select the first receiver along the swept segment, avoiding tunnelling.
	var candidate: FlagPlayer = null
	var nearest_distance: float = INF
	var candidates: Array[FlagPlayer] = eligible_interceptors.duplicate()
	candidates.append_array(eligible_receivers)
	for receiver: FlagPlayer in candidates:
		if not is_instance_valid(receiver):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(receiver.global_position, previous, next)
		if closest.distance_to(receiver.global_position) <= catch_radius:
			var distance: float = previous.distance_squared_to(closest)
			if distance < nearest_distance:
				nearest_distance = distance
				candidate = receiver
	if candidate != null:
		var is_interception: bool = eligible_interceptors.has(candidate)
		possess(candidate)
		if is_interception:
			intercepted.emit(candidate)
		else:
			caught.emit(candidate)
		return
	global_position = next
	if not FootballField.FIELD_RECT.has_point(global_position):
		_drop("OUT OF BOUNDS")
	elif global_position.is_equal_approx(target_position):
		_drop("INCOMPLETE / DROP")


func _drop(reason: String) -> void:
	in_flight = false
	eligible_receivers.clear()
	eligible_interceptors.clear()
	dropped.emit(reason)


func _draw() -> void:
	draw_rect(Rect2(-5, -3, 10, 6), Color("914b2e"))
	draw_rect(Rect2(-3, -1, 6, 2), Color("fff0d2"))
