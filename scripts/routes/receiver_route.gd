class_name ReceiverRoute
extends Node
## World-space waypoints are formed from offsets relative to the starting spot.

signal route_completed

@export var waypoint_offsets: PackedVector2Array = PackedVector2Array()
@export var arrival_radius: float = 5.0

var active: bool = false
var waypoint_index: int = 0
var origin: Vector2
var attack_direction: int = 1
@onready var runner: FlagPlayer = get_parent() as FlagPlayer


func _ready() -> void:
	origin = runner.global_position


func start() -> void:
	waypoint_index = 0
	active = true


func stop() -> void:
	active = false
	runner.ai_direction = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if not active or runner.control_enabled:
		return
	while waypoint_index < waypoint_offsets.size():
		var displacement: Vector2 = waypoint_position(waypoint_index) - runner.global_position
		if displacement.length() > arrival_radius:
			# Slow on approach so momentum cannot orbit the last waypoint.
			runner.ai_direction = displacement.normalized() * minf(displacement.length() / 20.0, 1.0)
			return
		waypoint_index += 1
	stop()
	route_completed.emit()


func waypoint_position(index: int) -> Vector2:
	var offset: Vector2 = waypoint_offsets[index]
	return FootballField.clamp_athlete(origin + Vector2(offset.x * attack_direction, offset.y))
