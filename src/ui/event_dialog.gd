## Event Dialog UI
## Renders standard, skill-check, choice, and chain events, displaying rolls and resolved outcomes.
class_name EventDialog
extends PanelContainer

signal event_resolved(result: Dictionary)

# Node references
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $MarginContainer/VBoxContainer/DescLabel
@onready var choice_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoiceContainer
@onready var roll_section: HBoxContainer = $MarginContainer/VBoxContainer/RollSection
@onready var roll_result_lbl: Label = $MarginContainer/VBoxContainer/RollSection/RollResultLabel
@onready var btn_roll: Button = $MarginContainer/VBoxContainer/RollSection/BtnRoll
@onready var btn_close: Button = $MarginContainer/VBoxContainer/BtnClose

# Current event tracking
var active_character: Character
var event: Dictionary
var chosen_option: Dictionary
var resolved_effects: Array = []
var final_message: String = ""
var triggered_combat: Array = []
var teleported: bool = false

# Pending skill-check payload, so the roll button can rebind to a stable handler.
var _pending_check_data: Dictionary = {}
var _pending_option_or_event: Dictionary = {}


func _ready() -> void:
	btn_close.visible = false
	btn_close.pressed.connect(_on_close_pressed)
	roll_section.visible = false


## Initialize and show the dialog for an event.
func popup_event(character: Character, event_data: Dictionary) -> void:
	active_character = character
	event = event_data
	
	title_label.text = event.get("name", "An Event Occurs")
	desc_label.text = event.get("description", "")
	
	# Clear choices and reset UI state from potential previous events in a chain
	for child in choice_container.get_children():
		child.queue_free()

	choice_container.visible = true
	roll_section.visible = false
	btn_close.visible = false
	btn_close.text = "Close"
	btn_roll.disabled = false
	roll_result_lbl.text = ""

	# Handle event types
	var event_type: String = event.get("type", "normal")
	
	match event_type:
		"choice":
			_build_choice_buttons()
		"skill_check":
			_setup_skill_check_section(event)
		"loot":
			_resolve_loot_event()
		"chain":
			_resolve_chain_event()
		"combat":
			_resolve_direct_combat_event()
		_: # normal / event check fallback
			_resolve_simple_event()


func _build_choice_buttons() -> void:
	var choices: Array = event.get("choices", [])
	for option in choices:
		var btn := Button.new()
		btn.text = option.get("text", "Option")
		
		# Check if the player has enough gold (if required)
		var cond: Dictionary = option.get("condition", {})
		if not cond.is_empty():
			if cond.get("type", "") == "has_gold":
				var gold_needed = int(cond.get("amount", 0))
				if active_character.inventory.gold < gold_needed:
					btn.disabled = true
					btn.text += " (Requires %d gold)" % gold_needed

		btn.pressed.connect(func():
			_on_choice_selected(option)
		)
		choice_container.add_child(btn)


func _on_choice_selected(option: Dictionary) -> void:
	var command := PlayerCommand.event_choice(option)
	if command == null:
		return
	option = command.payload["option"]
	chosen_option = option
	
	# Check if this choice requires a skill check
	var check_data: Dictionary = option.get("check", {})
	if not check_data.is_empty():
		_setup_skill_check_section(option)
	else:
		# Direct effects
		var effects: Array = option.get("effects", [])
		var results := EventResolver.apply_effects(active_character, effects)
		
		var outcomes_msg: String = option.get("description", "You proceed.")
		for res in results:
			outcomes_msg += "\n" + res.get("message", "")
			if res.get("type", "") == "start_combat":
				triggered_combat = res.get("monster_ids", [])
			if res.get("type", "") == "teleport_random":
				teleported = true

		desc_label.text = outcomes_msg
		choice_container.visible = false
		btn_close.visible = true


func _setup_skill_check_section(option_or_event: Dictionary) -> void:
	# Hide choice buttons
	choice_container.visible = false
	roll_section.visible = true

	var check_data: Dictionary = option_or_event.get("check", {})
	var ability: String = check_data.get("ability", "STR")
	var dc: int = int(check_data.get("dc", 10))

	var mod := active_character.ability_scores.get_ability_modifier(ability)
	if active_character.is_proficient_in_save(ability): # approximate skill proficiency
		mod += active_character.proficiency_bonus

	btn_roll.text = "Roll %s Check (DC %d) [%s]" % [ability, dc, AbilityScores.format_modifier(mod)]
	# Persist the check payload and bind a stable handler. A one-shot lambda
	# (CONNECT_ONE_SHOT) breaks when a chained event re-opens the dialog -- the
	# button stays visible but never fires. Disconnect any prior binding first
	# so re-popups don't stack duplicate handlers.
	_pending_check_data = check_data
	_pending_option_or_event = option_or_event
	if btn_roll.pressed.is_connected(_on_btn_roll_pressed):
		btn_roll.pressed.disconnect(_on_btn_roll_pressed)
	btn_roll.pressed.connect(_on_btn_roll_pressed)


func _on_btn_roll_pressed() -> void:
	var command := PlayerCommand.event_roll()
	if command == null:
		return
	_perform_roll(_pending_check_data, _pending_option_or_event)


func _perform_roll(check_data: Dictionary, option_or_event: Dictionary) -> void:
	btn_roll.disabled = true
	
	# Roll dice
	var result := EventResolver.resolve_skill_check(active_character, check_data)
	roll_result_lbl.text = "Rolled: %d + %d = %d!" % [result["natural_roll"], result["modifier"], result["total"]]
	
	# Animate color briefly
	if result["success"]:
		roll_result_lbl.add_theme_color_override("font_color", Color.GREEN)
		_resolve_check_outcome(option_or_event.get("success", {}), true)
	else:
		roll_result_lbl.add_theme_color_override("font_color", Color.RED)
		_resolve_check_outcome(option_or_event.get("failure", {}), false)


func _resolve_check_outcome(outcome_data: Dictionary, success: bool) -> void:
	var desc: String = outcome_data.get("description", "Outcome resolved.")
	var effects: Array = outcome_data.get("effects", [])
	var results := EventResolver.apply_effects(active_character, effects)
	
	for res in results:
		desc += "\n" + res.get("message", "")
		if res.get("type", "") == "start_combat":
			triggered_combat = res.get("monster_ids", [])
		if res.get("type", "") == "teleport_random":
			teleported = true

	# Wait a small delay to see the roll, then show outcome
	await get_tree().create_timer(1.2).timeout
	
	roll_section.visible = false
	desc_label.text = desc
	btn_close.visible = true


func _resolve_loot_event() -> void:
	var effects: Array = event.get("effects", [])
	if effects.is_empty() and event.has("success_loot"):
		# Construct list from shorthand success_loot keys
		var items: Array = event.get("success_loot", [])
		for it in items:
			if it.begins_with("gold_"):
				effects.append({"type": "gold", "value": it.substr(5).to_int()})
			else:
				effects.append({"type": "give_item", "item_id": it})

	var results := EventResolver.apply_effects(active_character, effects)
	var desc: String = event.get("description", "You found something!")
	for res in results:
		desc += "\n" + res.get("message", "")

	desc_label.text = desc
	btn_close.visible = true


func _resolve_chain_event() -> void:
	var effects: Array = event.get("effects", [])
	var results := EventResolver.apply_effects(active_character, effects)
	
	# Log chain start
	var desc: String = event.get("description", "")
	for res in results:
		desc += "\n" + res.get("message", "")
		if res.get("type", "") == "teleport_random":
			teleported = true

	desc_label.text = desc
	
	# Instead of closing, clicking next button triggers the chain sub-event
	btn_close.text = "Next event..."
	btn_close.visible = true
	
	# Override close button to trigger chain
	btn_close.pressed.disconnect(_on_close_pressed)
	btn_close.pressed.connect(func():
		var chain_evt := EventChain.get_chain_event(event)
		if not chain_evt.is_empty():
			popup_event(active_character, chain_evt)
			btn_close.text = "Close"
			btn_close.visible = false
			btn_close.pressed.connect(_on_close_pressed, CONNECT_ONE_SHOT)
		else:
			_on_close_pressed()
	, CONNECT_ONE_SHOT)


func _resolve_direct_combat_event() -> void:
	var combat_data: Dictionary = event.get("data", {})
	var monsters: Array = combat_data.get("monsters", [])
	triggered_combat = monsters
	
	desc_label.text = event.get("description", "Combat is triggered!") + "\nPrepare to fight!"
	btn_close.text = "Enter Combat"
	btn_close.visible = true


func _resolve_simple_event() -> void:
	var effects: Array = event.get("effects", [])
	var results := EventResolver.apply_effects(active_character, effects)
	var desc: String = event.get("description", "")
	for res in results:
		desc += "\n" + res.get("message", "")
	
	desc_label.text = desc
	btn_close.visible = true


func _on_close_pressed() -> void:
	# Emit event finished result to overworld
	var result := {
		"message": title_label.text + " resolved.",
		"monsters": triggered_combat,
		"teleported": teleported
	}
	event_resolved.emit(result)
	queue_free()
