## Event Dialog UI
## Renders standard, skill-check, choice, and chain events, displaying rolls and resolved outcomes.
class_name EventDialog
extends PanelContainer

signal event_resolved(result: Dictionary)

# Node references
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $MarginContainer/VBoxContainer/DescLabel
@onready var choice_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoiceContainer
@onready var roll_section: VBoxContainer = $MarginContainer/VBoxContainer/RollSection
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
var _primal_knowledge_choice: CheckBox
var _familiar_help_choice: CheckBox


func _ready() -> void:
	ModalSurface.install(self, func():
		if btn_close.visible: _on_close_pressed()
	, true)
	theme_type_variation = "OverlayPanel"
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

	var check_data: Dictionary = option_or_event.get("check", {}).duplicate(true)
	if is_instance_valid(_familiar_help_choice):
		_familiar_help_choice.queue_free()
		_familiar_help_choice = null
	if is_instance_valid(_primal_knowledge_choice):
		_primal_knowledge_choice.queue_free()
		_primal_knowledge_choice = null
	# Persist the check payload and bind a stable handler. A one-shot lambda
	# (CONNECT_ONE_SHOT) breaks when a chained event re-opens the dialog -- the
	# button stays visible but never fires. Disconnect any prior binding first
	# so re-popups don't stack duplicate handlers.
	_pending_check_data = check_data
	_pending_option_or_event = option_or_event
	var default_ability := str(check_data.get("ability", "STR"))
	var skill := str(check_data.get("skill", ""))
	if FamiliarRules.skill_help_available(active_character, check_data):
		_familiar_help_choice = CheckBox.new()
		_familiar_help_choice.text = "Ask familiar to Help (%s Advantage)" % skill
		_familiar_help_choice.button_pressed = false
		_familiar_help_choice.toggled.connect(func(enabled: bool): _pending_check_data["request_familiar_help"] = enabled)
		roll_section.add_child(_familiar_help_choice)
		roll_section.move_child(_familiar_help_choice, 0)
	if active_character.has_feature("barbarian_primal_knowledge") and default_ability != "STR" and active_character.get_skill_check_ability(default_ability, skill) == "STR":
		_primal_knowledge_choice = CheckBox.new()
		_primal_knowledge_choice.text = "Primal Knowledge: use Strength"
		_primal_knowledge_choice.button_pressed = bool(check_data.get("use_primal_knowledge", true))
		_primal_knowledge_choice.toggled.connect(func(enabled: bool):
			_pending_check_data["use_primal_knowledge"] = enabled
			_refresh_skill_check_label()
		)
		roll_section.add_child(_primal_knowledge_choice)
		roll_section.move_child(_primal_knowledge_choice, 0)
	_refresh_skill_check_label()
	if btn_roll.pressed.is_connected(_on_btn_roll_pressed):
		btn_roll.pressed.disconnect(_on_btn_roll_pressed)
	btn_roll.pressed.connect(_on_btn_roll_pressed)


func _refresh_skill_check_label() -> void:
	var skill := str(_pending_check_data.get("skill", ""))
	var ability := active_character.get_skill_check_ability(str(_pending_check_data.get("ability", "STR")), skill, bool(_pending_check_data.get("use_primal_knowledge", true)))
	var modifier := active_character.get_skill_check_modifier(skill, ability)
	btn_roll.text = "Roll %s Check (DC %d) [%s]" % [ability, int(_pending_check_data.get("dc", 10)), AbilityScores.format_modifier(modifier)]


func _on_btn_roll_pressed() -> void:
	var command := PlayerCommand.event_roll()
	if command == null:
		return
	_perform_roll(_pending_check_data, _pending_option_or_event)


func _perform_roll(check_data: Dictionary, option_or_event: Dictionary) -> void:
	if bool(check_data.get("request_familiar_help", false)) and not FamiliarRules.skill_help_available(active_character, check_data):
		roll_result_lbl.text = "Your familiar cannot Help now. Clear that choice to roll without its assistance."
		return
	btn_roll.disabled = true
	
	# Roll dice
	var result := EventResolver.resolve_skill_check(active_character, check_data)
	if not result["success"] and active_character.feature_uses.has("bardic_inspiration_die"):
		var die := str(active_character.feature_uses.get("bardic_inspiration_die", "1d6"))
		var inspiration_dialog := ConfirmationDialog.new()
		inspiration_dialog.title = "Bardic Inspiration — %s" % active_character.character_name
		inspiration_dialog.dialog_text = "Check failed: %d vs DC %d. Roll %s and add it to this check?" % [result["total"], result["dc"], die]
		inspiration_dialog.ok_button_text = "Use Inspiration"
		inspiration_dialog.cancel_button_text = "Keep Result"
		add_child(inspiration_dialog)
		var inspiration_decision := {"done": false, "accepted": false}
		inspiration_dialog.confirmed.connect(func(): inspiration_decision["accepted"] = true; inspiration_decision["done"] = true)
		inspiration_dialog.canceled.connect(func(): inspiration_decision["done"] = true)
		inspiration_dialog.close_requested.connect(func(): inspiration_decision["done"] = true)
		if GameManager.test_mode:
			inspiration_decision["done"] = true
		else:
			inspiration_dialog.popup_centered(Vector2i(460, 200))
		while not inspiration_decision["done"]:
			await get_tree().process_frame
		inspiration_dialog.queue_free()
		var inspiration := BardicInspirationRules.apply_to_test(active_character, int(result["total"]), int(result["dc"]), bool(inspiration_decision["accepted"]))
		if inspiration.get("used", false):
			result["total"] = int(inspiration["total"])
			result["success"] = bool(inspiration["success"])
			result["inspiration_bonus"] = int(inspiration["bonus"])
	if not result["success"] and active_character.has_feature("fighter_tactical_mind") and int(active_character.feature_uses.get("fighter_second_wind", 0)) > 0:
		var dialog := ConfirmationDialog.new()
		dialog.title = "Tactical Mind — %s" % active_character.character_name
		dialog.dialog_text = "Check failed: %d vs DC %d. Add 1d10? Spend one Second Wind only if it succeeds." % [result["total"], result["dc"]]
		dialog.ok_button_text = "Use Tactical Mind"
		dialog.cancel_button_text = "Keep Result"
		add_child(dialog)
		var decision := {"done": false, "accepted": false}
		dialog.confirmed.connect(func(): decision["accepted"] = true; decision["done"] = true)
		dialog.canceled.connect(func(): decision["done"] = true)
		dialog.close_requested.connect(func(): decision["done"] = true)
		if GameManager.test_mode:
			decision["done"] = true
		else:
			dialog.popup_centered(Vector2i(460, 200))
		while not decision["done"]:
			await get_tree().process_frame
		dialog.queue_free()
		if decision["accepted"]:
			var tactical := FighterRules.tactical_mind(active_character, result["total"], result["dc"])
			result["total"] = tactical["total"]
			result["modifier"] += tactical["bonus"]
			result["success"] = result["total"] >= result["dc"]
	var stroke_note := ""
	if not result["success"] and active_character.has_feature("rogue_stroke_of_luck") and int(active_character.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
		var stroke_dialog := ConfirmationDialog.new()
		stroke_dialog.title = "Stroke of Luck — %s" % active_character.character_name
		stroke_dialog.dialog_text = "Check failed: %d vs DC %d. Turn the d20 into a 20?" % [result["total"], result["dc"]]
		stroke_dialog.ok_button_text = "Use Stroke of Luck"
		stroke_dialog.cancel_button_text = "Keep Result"
		add_child(stroke_dialog)
		var stroke_decision := {"done": false, "accepted": false}
		stroke_dialog.confirmed.connect(func(): stroke_decision["accepted"] = true; stroke_decision["done"] = true)
		stroke_dialog.canceled.connect(func(): stroke_decision["done"] = true)
		stroke_dialog.close_requested.connect(func(): stroke_decision["done"] = true)
		if GameManager.test_mode:
			stroke_decision["done"] = true
		else:
			stroke_dialog.popup_centered(Vector2i(460, 200))
		while not stroke_decision["done"]:
			await get_tree().process_frame
		stroke_dialog.queue_free()
		var stroke_result := RogueRules.apply_stroke_of_luck(active_character, result, bool(stroke_decision["accepted"]))
		if stroke_result.get("used", false):
			result = stroke_result["result"]
			stroke_note = " (Stroke of Luck)"
	var inspiration_note := " + Bardic Inspiration %d" % int(result.get("inspiration_bonus", 0)) if result.has("inspiration_bonus") else ""
	roll_result_lbl.text = "Rolled: %d + %d%s = %d!%s" % [result["natural_roll"], result["modifier"], inspiration_note, result["total"], stroke_note]
	if bool(result.get("familiar_help", false)):
		roll_result_lbl.text += " (Familiar Help: Advantage)"
	
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
