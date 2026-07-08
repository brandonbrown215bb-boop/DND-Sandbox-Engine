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

# Dedicated one-shot timer for the post-roll fade. Using a real Timer (not an
# awaited create_timer) means the hide can never be orphaned by a re-entrant
# roll or a cancelled coroutine -- which previously left the overlay stuck
# visible AND blocking input (e.g. End Turn).
var _hide_timer: Timer


func _ready() -> void:
	# Connect to Dice autoload signal
	Dice.dice_rolled.connect(_on_dice_rolled)
	animation_timer.timeout.connect(_on_animation_tick)
	animation_timer.one_shot = false

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = 1.0
	_hide_timer.timeout.connect(_on_hide_timer)
	add_child(_hide_timer)

	# The overlay is purely visual feedback -- it must never intercept clicks
	# (otherwise it blocks buttons like End Turn while shown).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	visible = false


func _on_dice_rolled(data: Dictionary) -> void:
	# Cancel any pending hide -- a new roll restarts the sequence.
	_hide_timer.stop()

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
	# The display may receive a roll before it is parented in the tree (e.g.
	# when spawned inside a SubViewport harness where the timer node isn't
	# ready yet). Guard so we never throw "Unable to start the timer".
	if is_inside_tree():
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

		# Fade out after a short pause (driven by _hide_timer so it can't hang).
		if is_inside_tree():
			_hide_timer.start()


func _on_hide_timer() -> void:
	number_label.add_theme_color_override("font_color", Color.WHITE)
	visible = false
