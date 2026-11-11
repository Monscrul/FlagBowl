class_name OffensivePlay
extends Resource
## Shared authoring data. Match instances copy routes and never mutate the asset.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var receiver_one_route: PackedVector2Array = PackedVector2Array()
@export var receiver_two_route: PackedVector2Array = PackedVector2Array()
@export_range(0.25, 2.0) var ai_read_delay: float = 0.4


func is_valid() -> bool:
	if display_name.strip_edges().is_empty() or receiver_one_route.is_empty() or receiver_two_route.is_empty():
		return false
	for route: PackedVector2Array in [receiver_one_route, receiver_two_route]:
		for point: Vector2 in route:
			if not point.is_finite():
				return false
	return is_finite(ai_read_delay) and ai_read_delay >= 0.25 and ai_read_delay <= 2.0
