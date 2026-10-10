## Player-facing defeat and provisional completion screen.
extends Control

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var reason_label: Label = $Center/Panel/VBox/Reason
@onready var continue_button: Button = $Center/Panel/VBox/ContinueButton
@onready var menu_button: Button = $Center/Panel/VBox/MenuButton


func _ready() -> void:
	UiThemeProfile.current().apply(self)
	UiThemeProfile.current().style(self)
	$Background.color = UiThemeProfile.current().color("surface/base")
	var frame := GrimoireFrame.new()
	frame.prominent = true
	$Center/Panel.add_child(frame)
	$Center/Panel.theme_type_variation = "OverlayPanel"
	var victory := GameManager.current_state == GameManager.GameState.COMPLETION
	var context: Dictionary = GameManager.transition_context
	if victory:
		title_label.text = "Crown Reclaimed"
		reason_label.text = "%s\n\nThe crown is yours. Return to the title, or revisit the adventure from a safe save." % str(context.get("reason", "The final encounter is won."))
		continue_button.text = "Continue from Safe Save"
	else:
		title_label.text = "The Party Falls"
		reason_label.text = "%s\n\nLoad the latest safe save or return to the main menu." % str(context.get("reason", "The party was defeated."))
		continue_button.text = "Load Safe Save"
	continue_button.disabled = SaveManager.get_resumable_saves().is_empty()
	continue_button.pressed.connect(_on_continue_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	continue_button.theme_type_variation = "PrimaryButton" if not victory and not continue_button.disabled else "Button"
	if victory or continue_button.disabled:
		menu_button.theme_type_variation = "PrimaryButton"
	menu_button.text = "Return to title"
	var chronicle := Button.new()
	chronicle.text = "Read the final Chronicle"
	$Center/Panel/VBox.add_child(chronicle)
	chronicle.pressed.connect(_show_chronicle)


func _show_chronicle() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "OverlayPanel"
	add_child(panel)
	panel.position = (size - Vector2(800, 600)) / 2
	panel.size = Vector2(800, 600)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var rail := ActivityRailWidget.create()
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rail)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(panel.queue_free)
	box.add_child(close)
	ModalSurface.install(panel, panel.queue_free)


func _on_continue_pressed() -> void:
	var latest := SaveManager.get_latest_resumable_save()
	if latest.is_empty():
		return
	SaveManager.load_game(latest)


func _on_menu_pressed() -> void:
	GameManager.return_to_menu()
