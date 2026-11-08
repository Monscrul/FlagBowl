class_name FootballField
extends Node2D
## 20 pixels per yard: 50 playing yards plus two 10-yard end zones.

const FIELD_RECT: Rect2 = Rect2(40, 40, 1400, 280)
const YARD_SIZE: float = 20.0
const GOAL_LEFT: float = 240.0
const GOAL_RIGHT: float = 1240.0
const MIDFIELD: float = 740.0
const PLAYING_YARDS: float = 50.0
const CENTER_Y: float = 180.0
const PLAYER_RADIUS: float = 8.0
const CAMERA_BOUNDS: Rect2i = Rect2i(0, 0, 1480, 360)


static func progress_yards(world_x: float, direction: int) -> float:
	return (world_x - GOAL_LEFT) / YARD_SIZE if direction == 1 else (GOAL_RIGHT - world_x) / YARD_SIZE


static func world_x_from_progress(yards: float, direction: int) -> float:
	return GOAL_LEFT + yards * YARD_SIZE if direction == 1 else GOAL_RIGHT - yards * YARD_SIZE


static func carrier_out_of_bounds(point: Vector2) -> bool:
	# Character walls stop the center one radius inside the painted boundary.
	return point.y <= FIELD_RECT.position.y + PLAYER_RADIUS + 0.1 or point.y >= FIELD_RECT.end.y - PLAYER_RADIUS - 0.1 or point.x <= FIELD_RECT.position.x + PLAYER_RADIUS + 0.1 or point.x >= FIELD_RECT.end.x - PLAYER_RADIUS - 0.1


static func clamp_athlete(point: Vector2) -> Vector2:
	return point.clamp(FIELD_RECT.position + Vector2.ONE * PLAYER_RADIUS, FIELD_RECT.end - Vector2.ONE * PLAYER_RADIUS)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1480, 360), Color("142d32"))
	draw_rect(FIELD_RECT, Color("287849"))
	for stripe: int in range(10):
		if stripe % 2 == 0:
			draw_rect(Rect2(GOAL_LEFT + stripe * 100, 40, 100, 280), Color("2d8050"))
	draw_rect(Rect2(40, 40, 200, 280), Color("245882"))
	draw_rect(Rect2(GOAL_RIGHT, 40, 200, 280), Color("853d4c"))
	var line_color: Color = Color("d9ecd4")
	for yard: int in range(0, 51):
		var x: float = GOAL_LEFT + yard * YARD_SIZE
		if yard % 5 == 0:
			draw_line(Vector2(x, 40), Vector2(x, 320), line_color, 2.0)
		else:
			for y: float in [48.0, 132.0, 228.0, 306.0]:
				draw_line(Vector2(x, y), Vector2(x, y + 6), line_color, 1.0)
	# Goal lines and sidelines remain distinct from the five-yard markings.
	draw_line(Vector2(GOAL_LEFT, 40), Vector2(GOAL_LEFT, 320), Color.WHITE, 4.0)
	draw_line(Vector2(GOAL_RIGHT, 40), Vector2(GOAL_RIGHT, 320), Color.WHITE, 4.0)
	draw_rect(FIELD_RECT, Color.WHITE, false, 4.0)
	var font: Font = ThemeDB.fallback_font
	for yard: int in range(10, 50, 10):
		var label: String = str(mini(yard, 50 - yard))
		var x: float = GOAL_LEFT + yard * YARD_SIZE
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, Vector2(x - width / 2, 78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, line_color)
		draw_string(font, Vector2(x - width / 2, 298), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, line_color)
	draw_string(font, Vector2(88, 185), "FLAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("91c4e2"))
	draw_string(font, Vector2(1290, 185), "BOWL", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("edacb3"))
