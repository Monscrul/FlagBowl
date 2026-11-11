extends PanelContainer
## Only the human offense may edit a pre-snap call. Buttons never steal Enter.

var buttons: Array[Button] = []
var description: Label
@onready var director: Node2D = get_parent().get_parent()


func _ready() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	add_child(layout)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(row)
	for index: int in range(5):
		var button: Button = Button.new()
		button.text = "%d %s" % [index + 1, director.playbook.plays[index].display_name]
		button.add_theme_font_size_override("font_size", 12)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(func() -> void: director.select_play(index))
		row.add_child(button)
		buttons.append(button)
	description = Label.new()
	description.add_theme_font_size_override("font_size", 11)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(description)


func _process(_delta: float) -> void:
	visible = director.rules.phase == MatchRules.Phase.PRE_SNAP and not director.is_ai_offense()
	if not visible:
		return
	for index: int in range(buttons.size()):
		buttons[index].set_pressed_no_signal(index == director.human_play_index)
	description.text = director.selected_play().description
