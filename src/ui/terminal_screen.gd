## Player-facing defeat and provisional completion screen.
extends Control

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var reason_label: Label = $Center/Panel/VBox/Reason
@onready var continue_button: Button = $Center/Panel/VBox/ContinueButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	var victory := GameManager.current_state == GameManager.GameState.COMPLETION
	var context: Dictionary = GameManager.transition_context
	if victory:
		title_label.text = "Crown Reclaimed"
		reason_label.text = "%s\n\nThe campaign is complete. This is a provisional ending; post-game systems are not active." % str(context.get("reason", "The final encounter is won."))
		continue_button.text = "Continue from Safe Save"
	else:
		title_label.text = "The Party Falls"
		reason_label.text = "%s\n\nLoad the latest safe save or return to the main menu." % str(context.get("reason", "The party was defeated."))
		continue_button.text = "Load Safe Save"
	continue_button.disabled = SaveManager.get_resumable_saves().is_empty()
	continue_button.pressed.connect(_on_continue_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _on_continue_pressed() -> void:
	var saves := SaveManager.get_resumable_saves()
	if saves.is_empty():
		return
	SaveManager.load_game(saves[0])


func _on_menu_pressed() -> void:
	GameManager.return_to_menu()
