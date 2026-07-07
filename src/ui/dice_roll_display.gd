## Dice Roll Display UI
## Connects to the Dice singleton, showing an animated rolling dialog whenever a roll is requested.
class_name DiceRollDisplay
extends PanelContainer

@onready var number_label: Label = $VBoxContainer/NumberLabel
@onready var formula_label: Label = $VBoxContainer/FormulaLabel
@onready var animation_timer: Timer = $AnimationTimer

var rolling_sides := 20
var roll_result := 0
var animation_ticks := 0
const MAX_TICKS := 12


func _ready() -> void:
	# Connect to Dice autoload signal
	Dice.dice_rolled.connect(_on_dice_rolled)
	animation_timer.timeout.connect(_on_animation_tick)
	visible = false


func _on_dice_rolled(data: Dictionary) -> void:
	# Skip displaying rolls if we are in silent mode (can be toggled)
	rolling_sides = data.get("sides", 20)
	roll_result = data.get("total", 0)
	
	# Format formula label
	var type: String = data.get("type", "single")
	if type == "advantage":
		formula_label.text = "Roll 1d%d with ADVANTAGE" % rolling_sides
	elif type == "disadvantage":
		formula_label.text = "Roll 1d%d with DISADVANTAGE" % rolling_sides
	elif type == "multiple":
		formula_label.text = "Roll %dd%d" % [data.get("count", 1), rolling_sides]
	else:
		formula_label.text = "Roll 1d%d" % rolling_sides

	# Start rolling animation
	visible = true
	animation_ticks = 0
	animation_timer.start(0.06)


func _on_animation_tick() -> void:
	animation_ticks += 1
	if animation_ticks < MAX_TICKS:
		# Show random flashing numbers
		number_label.text = str(randi_range(1, rolling_sides))
	else:
		# Show final result
		animation_timer.stop()
		number_label.text = str(roll_result)
		
		# Flash green for high results, red for 1
		if roll_result == rolling_sides:
			number_label.add_theme_color_override("font_color", Color.GOLD)
		elif roll_result == 1:
			number_label.add_theme_color_override("font_color", Color.RED)
		else:
			number_label.add_theme_color_override("font_color", Color.WHITE)

		# Fade out after a short pause
		await get_tree().create_timer(1.0).timeout
		
		# Reset colors
		number_label.add_theme_color_override("font_color", Color.WHITE)
		visible = false
