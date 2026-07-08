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


func _ready() -> void:
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
		campaign_desc.text = "[color=red]No campaigns found! Check your data directory.[/color]"
		start_button.disabled = true


func _display_mod_errors() -> void:
	var errors := DataLoader.get_load_errors()
	if errors.is_empty():
		error_log.text = "[color=green]All core and mod assets loaded successfully![/color]"
	else:
		var err_text := "[color=orange]Modding Warning/Errors detected:[/color]\n"
		for err in errors:
			err_text += "- %s\n" % err
		error_log.text = err_text


func _on_campaign_selected(index: int) -> void:
	selected_campaign_idx = index
	var campaign: Dictionary = campaigns_list[index]
	var name_str: String = campaign.get("name", "Unnamed Campaign")
	var desc_str: String = campaign.get("description", "No description provided.")
	var author_str: String = campaign.get("author", "Unknown Creator")
	
	campaign_desc.text = "[font_size=20][b]%s[/b][/font_size]\n[color=gray]Created by %s[/color]\n\n%s" % [name_str, author_str, desc_str]

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
