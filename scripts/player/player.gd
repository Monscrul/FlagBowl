class_name FlagPlayer
extends CharacterBody2D
## Reusable runner shared by the controlled athlete and route receivers.

signal movement_state_changed(is_moving: bool)

@export var max_speed: float = 150.0
@export var acceleration: float = 1100.0
@export var deceleration: float = 1500.0
@export var control_enabled: bool = true
@export var jersey_color: Color = Color("51b9f2")
@export var role_name: String = "QB"

var ai_direction: Vector2 = Vector2.ZERO
var has_ball: bool = false
var play_active: bool = false
var movement_locked: bool = false
var is_juking: bool = false
var juke_direction: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0

var _is_moving: bool = false


func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		return
	var input_direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	) if control_enabled else ai_direction.limit_length()
	if is_juking:
		input_direction = juke_direction
	var change_rate: float = acceleration if input_direction != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(input_direction * max_speed * speed_multiplier, change_rate * delta)
	move_and_slide()
	var moving_now: bool = velocity.length_squared() > 1.0
	if moving_now != _is_moving:
		_is_moving = moving_now
		movement_state_changed.emit(_is_moving)


func _draw() -> void:
	if is_juking:
		draw_arc(Vector2.ZERO, 15, 0, TAU, 24, Color("7ee9ee"), 2.0)
	if control_enabled:
		draw_arc(Vector2.ZERO, 12, 0, TAU, 24, Color("ffe175"), 1.0)
	# Original geometric placeholder: shadow, shoes, jersey, head, and belt flags.
	draw_rect(Rect2(-8, 5, 16, 5), Color("153c34"))
	draw_rect(Rect2(-6, 3, 4, 5), Color("142433"))
	draw_rect(Rect2(2, 3, 4, 5), Color("142433"))
	draw_rect(Rect2(-7, -5, 14, 10), jersey_color)
	draw_rect(Rect2(-4, -11, 8, 7), Color("edbd91"))
	draw_rect(Rect2(-4, -12, 8, 3), Color("24364b"))
	draw_rect(Rect2(-9, 1, 3, 7), Color("ffe175"))
	draw_rect(Rect2(6, 1, 3, 7), Color("ffe175"))
	draw_rect(Rect2(-1, -3, 2, 5), Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-10, -17), role_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
