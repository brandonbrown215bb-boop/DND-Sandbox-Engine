## Settings Overlay
## Pause menu / settings panel. Lives on a high CanvasLayer and sets
## process_mode = ALWAYS so it keeps running while the tree is paused.
## Save/Load delegate to the Settings autoload (which wraps SaveManager), so
## they work from anywhere a game is in progress.
extends CanvasLayer

@onready var master_vol: HSlider = $Panel/VBox/MasterVol
@onready var sfx_vol: HSlider = $Panel/VBox/SfxVol
@onready var music_vol: HSlider = $Panel/VBox/MusicVol
@onready var screen_shake: CheckButton = $Panel/VBox/ScreenShake
@onready var high_contrast: CheckButton = $Panel/VBox/HighContrast
@onready var damage_numbers: CheckButton = $Panel/VBox/DamageNumbers
@onready var slot_list: ItemList = $Panel/VBox/SlotList
@onready var btn_save: Button = $Panel/VBox/BtnSave
@onready var btn_load: Button = $Panel/VBox/BtnLoad
@onready var btn_delete: Button = $Panel/VBox/BtnDelete
@onready var btn_resume: Button = $Panel/VBox/BtnResume
@onready var btn_quit: Button = $Panel/VBox/BtnQuit
@onready var status_lbl: Label = $Panel/VBox/Status


func _ready() -> void:
	# Keep this overlay responsive while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiThemeProfile.current().apply($Panel)
	UiThemeProfile.current().style($Panel)
	$Panel.theme_type_variation = "OverlayPanel"
	high_contrast.hide()
	$Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ModalSurface.install($Panel, Settings.close_settings)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Panel/VBox.add_child(scroll)
	$Panel/VBox.move_child(scroll, 1)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for child in $Panel/VBox.get_children():
		if child != scroll and child.name not in ["Title", "BtnResume", "BtnQuit"]:
			child.reparent(body)
	var motion := CheckButton.new()
	motion.text = "Reduce interface motion"
	motion.button_pressed = Settings.reduce_ui_motion
	motion.toggled.connect(func(enabled): Settings.reduce_ui_motion = enabled; Settings.save_settings())
	body.add_child(motion)
	body.move_child(motion, screen_shake.get_index() + 1)
	$Panel.custom_minimum_size = Vector2(600, 0)
	$Panel.size = Vector2(600, minf(680, get_viewport().get_visible_rect().size.y - 64))
	$Panel.position = (get_viewport().get_visible_rect().size - $Panel.size) / 2
	get_viewport().size_changed.connect(_resize_panel)
	$Panel/VBox/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in [["MasterVolLabel", master_vol], ["SfxVolLabel", sfx_vol], ["MusicVolLabel", music_vol]]:
		body.move_child(body.get_node(spec[0]), spec[1].get_index())

	# Reflect current settings.
	master_vol.value = Settings.master_volume
	sfx_vol.value = Settings.sfx_volume
	music_vol.value = Settings.music_volume
	screen_shake.button_pressed = Settings.screen_shake
	high_contrast.button_pressed = Settings.high_contrast
	damage_numbers.button_pressed = Settings.show_damage_numbers

	# Wire controls.
	master_vol.value_changed.connect(func(v): Settings.master_volume = v; Settings.save_settings())
	sfx_vol.value_changed.connect(func(v): Settings.sfx_volume = v; Settings.save_settings())
	music_vol.value_changed.connect(func(v): Settings.music_volume = v; Settings.save_settings())
	screen_shake.toggled.connect(func(b): Settings.screen_shake = b; Settings.save_settings())
	high_contrast.toggled.connect(func(b): Settings.high_contrast = b; Settings.save_settings())
	damage_numbers.toggled.connect(func(b): Settings.show_damage_numbers = b; Settings.save_settings())

	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_delete.pressed.connect(_on_delete_pressed)
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	_refresh_slots()
	status_lbl.text = ""

func _resize_panel() -> void:
	$Panel.size = Vector2(600, minf(680, get_viewport().get_visible_rect().size.y - 64))
	$Panel.position = (get_viewport().get_visible_rect().size - $Panel.size) / 2


func _refresh_slots() -> void:
	slot_list.clear()
	var saves := Settings.get_saves()
	if saves.is_empty():
		slot_list.add_item("(no saves)")
		slot_list.set_item_disabled(0, true)
	else:
		for s in saves:
			slot_list.add_item(s)
	btn_load.disabled = SaveManager.get_resumable_saves().is_empty()
	btn_delete.disabled = saves.is_empty()
	var save_reason := SaveManager.get_save_block_reason()
	btn_save.disabled = not save_reason.is_empty()
	if not save_reason.is_empty():
		status_lbl.text = "Save unavailable: %s." % save_reason


func _on_save_pressed() -> void:
	if btn_save.disabled:
		return
	var slot := _selected_slot()
	if slot.is_empty():
		slot = "quicksave"
	var ok := Settings.save_game(slot)
	status_lbl.text = "Saved to '%s'." % slot if ok else "Save failed."
	_refresh_slots()


func _on_load_pressed() -> void:
	var slot := _selected_slot()
	if slot.is_empty():
		status_lbl.text = "Select a save slot first."
		return
	var ok := Settings.load_game(slot)
	if ok:
		# Loading changes the scene; close the overlay first.
		Settings.close_settings()
	else:
		status_lbl.text = "Load failed for '%s'." % slot


func _on_delete_pressed() -> void:
	var slot := _selected_slot()
	if slot.is_empty():
		return
	Settings.delete_save(slot)
	status_lbl.text = "Deleted '%s'." % slot
	_refresh_slots()


func _on_resume_pressed() -> void:
	Settings.close_settings()


func _on_quit_pressed() -> void:
	Settings.close_settings()
	GameManager.return_to_menu()


func _selected_slot() -> String:
	if slot_list.is_anything_selected():
		var idx: int = slot_list.get_selected_items()[0]
		return slot_list.get_item_text(idx)
	return ""
