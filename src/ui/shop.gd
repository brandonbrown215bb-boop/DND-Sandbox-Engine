## Shop UI Controller
## Handles browsing and purchasing items from town merchants and resting at the tavern.
class_name ShopUI
extends PanelContainer

signal closed

@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var location_label: Label = $MarginContainer/VBoxContainer/Header/LocationLabel
@onready var player_selector: OptionButton = $MarginContainer/VBoxContainer/Header/HBoxContainer/PlayerSelector
@onready var gold_label: Label = $MarginContainer/VBoxContainer/Header/HBoxContainer/GoldLabel

@onready var item_list: ItemList = $MarginContainer/VBoxContainer/Body/HBoxContainer/ItemListContainer/ItemList
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/Body/HBoxContainer/DetailContainer/ItemNameLabel
@onready var item_desc_label: RichTextLabel = $MarginContainer/VBoxContainer/Body/HBoxContainer/DetailContainer/ItemDescLabel
@onready var price_label: Label = $MarginContainer/VBoxContainer/Body/HBoxContainer/DetailContainer/PriceLabel
@onready var btn_buy: Button = $MarginContainer/VBoxContainer/Body/HBoxContainer/DetailContainer/BtnBuy

@onready var btn_rest: Button = $MarginContainer/VBoxContainer/Footer/BtnRest
@onready var btn_close: Button = $MarginContainer/VBoxContainer/Footer/BtnClose

# Current state
var active_player_index: int = 0
var active_character: Character = null
var items_data: Array = []
var selected_item_idx: int = -1

const TAVERN_REST_COST := 10
const SHOP_ITEM_TYPES := ["weapon", "armor", "shield", "consumable"]


func _ready() -> void:
	# Connect buttons
	player_selector.item_selected.connect(_on_player_selected)
	item_list.item_selected.connect(_on_item_selected)
	btn_buy.pressed.connect(_on_buy_pressed)
	btn_rest.pressed.connect(_on_rest_pressed)
	btn_close.pressed.connect(_on_close_pressed)

	# Fetch buyable items
	_populate_items()

	# Set up player selector
	_populate_players()
	_update_player_data()


func setup_shop(town_name: String) -> void:
	location_label.text = "Town: " + town_name
	_update_rest_button_label()


func _populate_players() -> void:
	player_selector.clear()
	var player_count := PlayerManager.get_player_count()
	for i in player_count:
		var p := PlayerManager.get_player(i)
		var char_data: Character = p.get("character")
		if char_data != null:
			player_selector.add_item("%s (%s)" % [char_data.character_name, DataLoader.get_character_class(char_data.class_id).get("name", "Class")], i)
	
	active_player_index = PlayerManager.active_player_index
	player_selector.select(active_player_index)


func _update_player_data() -> void:
	var p := PlayerManager.get_player(active_player_index)
	active_character = p.get("character")
	if active_character != null:
		gold_label.text = "Gold: %d gp" % active_character.inventory.gold
	else:
		gold_label.text = "Gold: 0 gp"
	
	_update_buy_button_state()
	_update_rest_button_label()


func _populate_items() -> void:
	item_list.clear()
	items_data.clear()

	# Only expose item types the shop can sell and the runtime can use.
	var all_items := DataLoader.get_all_items()
	for item in all_items:
		if not _is_buyable_item(item):
			continue
		items_data.append(item)

	# Sort by type and value
	items_data.sort_custom(func(a, b):
		var type_a: String = a.get("type", "")
		var type_b: String = b.get("type", "")
		if type_a != type_b:
			return type_a < type_b
		return int(a.get("value", 0)) < int(b.get("value", 0))
	)

	for item in items_data:
		var name_str: String = item.get("name", "Unnamed Item")
		var val: int = int(item.get("value", 0))
		item_list.add_item("%s (%d gp)" % [name_str, val])

	if not items_data.is_empty():
		item_list.select(0)
		_on_item_selected(0)
	else:
		item_name_label.text = "No items available"
		item_desc_label.text = ""
		price_label.text = ""
		btn_buy.disabled = true


func _is_buyable_item(item: Dictionary) -> bool:
	var type := str(item.get("type", ""))
	if type not in SHOP_ITEM_TYPES or int(item.get("value", 0)) <= 0:
		return false
	if type != "consumable":
		return true
	var effects = item.get("effects", [])
	if not effects is Array or effects.is_empty():
		return false
	for effect in effects:
		if not effect is Dictionary or not EventResolver.is_effect_supported(str(effect.get("type", ""))):
			return false
	return true


func _on_player_selected(index: int) -> void:
	active_player_index = index
	_update_player_data()


func _on_item_selected(index: int) -> void:
	selected_item_idx = index
	var item: Dictionary = items_data[index]

	item_name_label.text = item.get("name", "Unnamed Item")
	price_label.text = "Cost: %d gp" % int(item.get("value", 0))
	
	# Build details
	var desc: String = item.get("description", "")
	var type: String = item.get("type", "")
	desc += "\n\n[color=gray]"
	desc += "Type: %s\n" % type.capitalize()
	if type == "weapon":
		desc += "Damage: %s (%s)\n" % [item.get("damage", "1d4"), item.get("damage_type", "bludgeoning")]
		desc += "Ability: %s\n" % item.get("ability", "STR")
		desc += "Range: %s hex(es)\n" % item.get("range", 1)
	elif type == "armor":
		desc += "Base AC: %s\n" % item.get("ac", 10)
		desc += "Armor Type: %s\n" % item.get("armor_type", "light").capitalize()
		if item.get("stealth_disadvantage", false):
			desc += "Stealth Check: Disadvantage\n"
	elif type == "shield":
		desc += "AC Bonus: +%s\n" % item.get("ac_bonus", 2)
	desc += "[/color]"
	
	item_desc_label.text = desc
	_update_buy_button_state()


func _update_buy_button_state() -> void:
	if active_character == null or selected_item_idx < 0:
		btn_buy.disabled = true
		return

	var item: Dictionary = items_data[selected_item_idx]
	var cost := int(item.get("value", 0))

	if active_character.inventory.gold < cost:
		btn_buy.disabled = true
		btn_buy.text = "Insufficient Gold"
	elif active_character.inventory.backpack.size() >= Inventory.MAX_BACKPACK_SIZE:
		btn_buy.disabled = true
		btn_buy.text = "Backpack Full"
	else:
		btn_buy.disabled = false
		btn_buy.text = "Purchase Item"


func _update_rest_button_label() -> void:
	if active_character == null:
		btn_rest.disabled = true
		return
		
	var player_count := PlayerManager.get_player_count()
	var total_cost := player_count * TAVERN_REST_COST
	btn_rest.text = "Rest at Tavern (%d gp total)" % total_cost

	var needs_healing := false
	for i in player_count:
		var char_data: Character = PlayerManager.get_player(i).get("character")
		if char_data != null and char_data.current_hp < char_data.max_hp:
			needs_healing = true
			break
	
	if active_character.inventory.gold < total_cost:
		btn_rest.disabled = true
	elif not needs_healing:
		btn_rest.disabled = true
		btn_rest.text = "Rest at Tavern (Already Full HP)"
	else:
		btn_rest.disabled = false


func _on_buy_pressed() -> void:
	if active_character == null or selected_item_idx < 0: return

	var item: Dictionary = items_data[selected_item_idx]
	var item_id: String = item.get("id", "")
	var command := PlayerCommand.inventory_buy(active_player_index, item_id)
	if command == null or not _is_buyable_item(item):
		return
	item_id = str(command.payload["item_id"])
	var cost := int(item.get("value", 0))

	# Add the item before charging so a failed inventory mutation cannot consume gold.
	if not active_character.inventory.add_item(item_id):
		return
	active_character.inventory.gold -= cost

	# Print success log to overworld HUD
	var parent_node = get_parent()
	if parent_node != null:
		var hud = parent_node.get("hud")
		if hud != null and hud.has_method("add_log"):
			var item_name: String = item.get("name", item_id)
			hud.add_log("[color=green]%s bought %s for %d gold.[/color]" % [active_character.character_name, item_name, cost])

	print("[Shop] %s bought %s. Gold remaining: %d" % [active_character.character_name, item_id, active_character.inventory.gold])
	
	_update_player_data()


func _on_rest_pressed() -> void:
	if active_character == null: return
	var command := PlayerCommand.inventory_rest()
	if command == null:
		return

	var player_count := PlayerManager.get_player_count()
	var total_cost := player_count * TAVERN_REST_COST

	active_character.inventory.gold -= total_cost
	
	# Heal all players and reset stats/spells/uses
	for i in player_count:
		var char_data: Character = PlayerManager.get_player(i).get("character")
		if char_data != null:
			char_data.current_hp = char_data.max_hp
			char_data.is_alive = true
			# Reset features
			for f_id in char_data.feature_uses:
				for f in char_data.features:
					if f.get("id", "") == f_id:
						char_data.feature_uses[f_id] = f.get("uses", 1)
						break
			# Reset spell slots
			char_data._update_spell_slots()

	var parent_node = get_parent()
	if parent_node != null:
		var hud = parent_node.get("hud")
		if hud != null and hud.has_method("add_log"):
			hud.add_log("[color=green]Party rested at the Tavern. HP, spell slots, and feature uses fully restored![/color]")

	print("[Shop] Party rested. Restored all resources.")
	_update_player_data()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
