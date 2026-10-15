## Main Menu Controller
## Handles campaign selection, player count, mod list, and starting the game.
extends Control

@onready var campaign_list: ItemList = $MarginContainer/HBoxContainer/LeftPanel/CampaignSection/CampaignList
@onready var campaign_desc: RichTextLabel = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/DescText
@onready var player_count_label: Label = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/PlayerCountLabel
@onready var start_button: Button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/StartButton
@onready var error_log: RichTextLabel = $MarginContainer/HBoxContainer/LeftPanel/ModSection/ErrorLog
@onready var btn_load: Button = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/BtnLoad
@onready var save_slot_list: ItemList = $MarginContainer/HBoxContainer/RightPanel/VBoxContainer/LoadSection/SaveSlotList

var campaigns_list: Array = []
var selected_campaign_idx: int = -1
var selected_player_count: int = 2
var _title_page: CenterContainer
var _setup_close: Button
var _diagnostics: PanelContainer


func _ready() -> void:
	get_window().min_size = Vector2i(1280, 720)
	get_window().gui_embed_subwindows = true
	UiThemeProfile.current().apply(self)
	UiThemeProfile.current().style(self)
	$Background.color = UiThemeProfile.current().color("surface/base")
	# Connect signals
	campaign_list.item_selected.connect(_on_campaign_selected)
	$MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnMinus.pressed.connect(_on_minus_pressed)
	$MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection/HBoxContainer/BtnPlus.pressed.connect(_on_plus_pressed)
	start_button.pressed.connect(_on_start_pressed)
	btn_load.pressed.connect(_on_load_pressed)

	# Populate available saves
	_refresh_save_slots()

	# Load campaigns
	_populate_campaigns()
	_display_mod_errors()
	_build_title_page()


func _build_title_page() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = UiThemeProfile.current().icons.get("title_backdrop")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var setup := $MarginContainer
	setup.hide()
	ModalSurface.install(setup, _close_setup)
	_setup_close = Button.new()
	_setup_close.text = "Back to title"
	_setup_close.pressed.connect(_close_setup)
	$MarginContainer/HBoxContainer/LeftPanel.add_child(_setup_close)
	$MarginContainer/HBoxContainer/LeftPanel/SubtitleLabel.text = "Choose an adventure and your local players"
	$MarginContainer/HBoxContainer/LeftPanel/ModSection.hide()
	_title_page = CenterContainer.new()
	add_child(_title_page)
	_title_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "OverlayPanel"
	panel.custom_minimum_size = Vector2(620, 580)
	_title_page.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var crest := TextureRect.new()
	crest.texture = UiThemeProfile.current().icons.get("crest", UiThemeProfile.current().icons.get("crown"))
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.custom_minimum_size = Vector2(0, 56)
	box.add_child(crest)
	var title := Label.new()
	title.theme_type_variation = "DisplayLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.text = "Crown & Company"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "The Lost Crown"
	subtitle.theme_type_variation = "TitleLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(HSeparator.new())
	var latest := SaveManager.get_latest_resumable_save()
	for label in ["Continue", "New Campaign", "Load", "Settings", "Quit"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(360, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(button)
		match label:
			"Continue":
				button.theme_type_variation = "PrimaryButton"
				button.disabled = latest.is_empty()
				button.tooltip_text = "No resumable campaign yet" if latest.is_empty() else "Resume your most recent safe save"
				button.pressed.connect(func(): SaveManager.load_game(SaveManager.get_latest_resumable_save()))
			"New Campaign":
				if latest.is_empty(): button.theme_type_variation = "PrimaryButton"
				button.pressed.connect(_open_setup.bind(false))
			"Load":
				button.disabled = latest.is_empty()
				button.pressed.connect(_open_setup.bind(true))
			"Settings": button.pressed.connect(func(): Settings.open_settings(self))
			"Quit": button.pressed.connect(func(): get_tree().quit())
	var diagnostics_button := Button.new()
	diagnostics_button.text = "Content diagnostics"
	diagnostics_button.custom_minimum_size.y = 40
	diagnostics_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	diagnostics_button.pressed.connect(_show_diagnostics)
	box.add_child(diagnostics_button)
	var frame := GrimoireFrame.new()
	frame.prominent = true
	panel.add_child(frame)


func _open_setup(load_only: bool) -> void:
	_title_page.hide()
	$MarginContainer.show()
	$MarginContainer/HBoxContainer/LeftPanel/CampaignSection.visible = not load_only
	$MarginContainer/HBoxContainer/RightPanel/VBoxContainer/PlayerCountSection.visible = not load_only
	$MarginContainer/HBoxContainer/RightPanel/VBoxContainer/DescText.visible = not load_only
	$MarginContainer/HBoxContainer/RightPanel/VBoxContainer/LoadSection.visible = load_only
	btn_load.visible = load_only
	start_button.visible = not load_only
	start_button.text = "Create your party"
	if load_only: save_slot_list.grab_focus()
	else: campaign_list.grab_focus()


func _close_setup() -> void:
	$MarginContainer.hide()
	_title_page.show()


func _show_diagnostics() -> void:
	if _diagnostics == null:
		_diagnostics = PanelContainer.new()
		_diagnostics.theme_type_variation = "OverlayPanel"
		add_child(_diagnostics)
		var box := VBoxContainer.new()
		_diagnostics.add_child(box)
		var title := Label.new()
		title.text = "Content diagnostics"
		title.theme_type_variation = "TitleLabel"
		box.add_child(title)
		error_log.reparent(box)
		error_log.custom_minimum_size = Vector2(700, 350)
		var close := Button.new()
		close.text = "Close"
		close.pressed.connect(_diagnostics.hide)
		box.add_child(close)
		ModalSurface.install(_diagnostics, _diagnostics.hide)
	_diagnostics.position = (size - Vector2(750, 470)) / 2
	_diagnostics.size = Vector2(750, 470)
	_diagnostics.show()


func _populate_campaigns() -> void:
	campaign_list.clear()
	campaigns_list = DataLoader.get_all_campaigns()

	for i in campaigns_list.size():
		var campaign: Dictionary = campaigns_list[i]
		var campaign_name: String = campaign.get("name", "Unnamed Campaign")
		campaign_list.add_item(campaign_name)

	if not campaigns_list.is_empty():
		campaign_list.select(0)
		_on_campaign_selected(0)
	else:
		campaign_desc.text = "[color=%s]No campaigns found. Open Content diagnostics for details.[/color]" % UiThemeProfile.current().color("state/danger").to_html()
		start_button.disabled = true


func _display_mod_errors() -> void:
	var errors := DataLoader.get_load_errors()
	if errors.is_empty():
		error_log.text = "[color=%s]All core and mod assets loaded successfully.[/color]" % UiThemeProfile.current().color("state/success").to_html()
	else:
		var err_text := "[color=%s]Content warnings and errors:[/color]\n" % UiThemeProfile.current().color("state/warning").to_html()
		for err in errors:
			err_text += "- %s\n" % err
		error_log.text = err_text


func _on_campaign_selected(index: int) -> void:
	selected_campaign_idx = index
	var campaign: Dictionary = campaigns_list[index]
	var name_str: String = campaign.get("name", "Unnamed Campaign")
	var desc_str: String = campaign.get("description", "No description provided.")
	var author_str: String = campaign.get("author", "Unknown Creator")
	
	campaign_desc.text = "[font_size=20][b]%s[/b][/font_size]\n[color=%s]Created by %s[/color]\n\n%s" % [name_str, UiThemeProfile.current().color("text/muted").to_html(), author_str, desc_str]

	# Get campaign player count limits
	var limits: Dictionary = campaign.get("player_count", {"min": 2, "max": 4})
	var min_p: int = int(limits.get("min", 2))
	var max_p: int = int(limits.get("max", 4))

	# Clamp current selection to new limits
	selected_player_count = clamp(selected_player_count, min_p, max_p)
	_update_player_count_ui(min_p, max_p)


func _on_minus_pressed() -> void:
	if selected_campaign_idx < 0: return
	var campaign: Dictionary = campaigns_list[selected_campaign_idx]
	var limits: Dictionary = campaign.get("player_count", {"min": 2, "max": 4})
	var min_p: int = int(limits.get("min", 2))
	var max_p: int = int(limits.get("max", 4))

	if selected_player_count > min_p:
		selected_player_count -= 1
		_update_player_count_ui(min_p, max_p)


func _on_plus_pressed() -> void:
	if selected_campaign_idx < 0: return
	var campaign: Dictionary = campaigns_list[selected_campaign_idx]
	var limits: Dictionary = campaign.get("player_count", {"min": 2, "max": 4})
	var min_p: int = int(limits.get("min", 2))
	var max_p: int = int(limits.get("max", 4))

	if selected_player_count < max_p:
		selected_player_count += 1
		_update_player_count_ui(min_p, max_p)


func _update_player_count_ui(min_p: int, max_p: int) -> void:
	player_count_label.text = "%d Players" % selected_player_count


func _on_start_pressed() -> void:
	if selected_campaign_idx < 0: return
	var campaign: Dictionary = campaigns_list[selected_campaign_idx]
	var campaign_id: String = campaign.get("id", "")
	if not campaign_id.is_empty():
		GameManager.start_new_game(campaign_id, selected_player_count)


## Populate the saved-game list. Only lists saves that actually hold an
## in-progress game (resumable); a menu-only quicksave is hidden so the player
## can't click Load and get a silent no-op.
func _refresh_save_slots() -> void:
	save_slot_list.clear()
	var resumable := SaveManager.get_resumable_saves()
	if resumable.is_empty():
		save_slot_list.add_item("(no saved games)")
		save_slot_list.set_item_disabled(0, true)
		btn_load.disabled = true
	else:
		for s in resumable:
			save_slot_list.add_item(s)
		btn_load.disabled = false
	for legacy_slot in SaveManager.get_legacy_save_names():
		save_slot_list.add_item("%s (legacy rules - incompatible)" % legacy_slot)
		var legacy_index := save_slot_list.item_count - 1
		save_slot_list.set_item_disabled(legacy_index, true)
		save_slot_list.set_item_tooltip(legacy_index, "Preserved unchanged. Use the earlier game version to continue this campaign.")


## Load the selected save (or the first if none selected) into the game.
func _on_load_pressed() -> void:
	var resumable := SaveManager.get_resumable_saves()
	if resumable.is_empty():
		return
	var slot: String
	if save_slot_list.is_anything_selected():
		slot = save_slot_list.get_item_text(save_slot_list.get_selected_items()[0])
	else:
		slot = resumable[0]
	if not SaveManager.is_save_resumable(slot):
		return
	SaveManager.load_game(slot)
