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
var last_skill_check_result: Dictionary = {}

# Pending skill-check payload, so the roll button can rebind to a stable handler.
var _pending_check_data: Dictionary = {}
var _pending_option_or_event: Dictionary = {}
var _pending_authored_context: Dictionary = {}
var _primal_knowledge_choice: CheckBox
var _familiar_help_choice: CheckBox
var _popup_generation: int = 0
var _active_ability_bonus_menu: PopupMenu
var _active_ability_bonus_decision: Dictionary = {}


func _ready() -> void:
	ModalSurface.install(self, func():
		if btn_close.visible: _on_close_pressed()
	, true)
	theme_type_variation = "OverlayPanel"
	btn_close.visible = false
	btn_close.pressed.connect(_on_close_pressed)
	roll_section.visible = false


func _exit_tree() -> void:
	_cancel_ability_bonus_prompt()
	SpellDamageRolls.cancel_ability_check_requests_for_host(self)
	var parent_node := get_parent()
	if parent_node != null:
		for sibling in parent_node.get_children():
			if sibling is ModalSurface and sibling.content == self:
				sibling.queue_free()


## Initialize and show the dialog for an event.
func popup_event(character: Character, event_data: Dictionary) -> void:
	_popup_generation += 1
	_cancel_ability_bonus_prompt()
	SpellDamageRolls.cancel_ability_check_requests_for_host(self)
	active_character = character
	event = event_data.duplicate(true)
	var incoming_event_id := str(event.get("id", ""))
	var loaded_event: Dictionary = DataLoader.get_event_record(incoming_event_id)
	if not loaded_event.is_empty():
		event = loaded_event.get("event", {}).duplicate(true)
	last_skill_check_result.clear()
	_pending_authored_context.clear()
	
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
			_setup_skill_check_section(event, str(event.get("id", "")))
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
		_setup_skill_check_section(option, str(event.get("id", "")))
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


func _setup_skill_check_section(option_or_event: Dictionary, origin_event_id: String = "") -> void:
	# Hide choice buttons
	choice_container.visible = false
	roll_section.visible = true
	if is_instance_valid(_familiar_help_choice):
		_familiar_help_choice.queue_free()
		_familiar_help_choice = null
	if is_instance_valid(_primal_knowledge_choice):
		_primal_knowledge_choice.queue_free()
		_primal_knowledge_choice = null

	var check_data: Dictionary = option_or_event.get("check", {}).duplicate(true)
	_pending_authored_context.clear()
	var check_id := str(check_data.get("id", ""))
	var authoritative: Dictionary = {}
	if check_data.has("check_context"):
		authoritative = DataLoader.get_event_check_record(origin_event_id, check_id)
		var authoritative_check: Dictionary = authoritative.get("check", {})
		var declared_context: Variant = authoritative_check.get("check_context", {})
		if authoritative.is_empty() or not declared_context is Dictionary or declared_context.is_empty():
			_refuse_unverified_check()
			return
		check_data = authoritative_check
		option_or_event = authoritative.get("check_owner", {})
		_pending_authored_context = declared_context.duplicate(true)
		_pending_authored_context["origin_event_id"] = origin_event_id
		_pending_authored_context["origin_check_id"] = check_id
		_pending_authored_context["source_table_id"] = str(authoritative.get("table_id", ""))
	else:
		if not check_id.is_empty():
			authoritative = DataLoader.get_event_check_record(origin_event_id, check_id)
			if not authoritative.is_empty():
				check_data = authoritative.get("check", check_data).duplicate(true)
				option_or_event = authoritative.get("check_owner", option_or_event).duplicate(true)
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


func _refuse_unverified_check() -> void:
	_pending_check_data.clear()
	_pending_option_or_event.clear()
	_pending_authored_context.clear()
	btn_roll.disabled = true
	roll_section.visible = true
	choice_container.visible = false
	roll_result_lbl.text = "This check is unavailable because its authored event and check could not be verified."
	btn_close.visible = true
	btn_close.text = "Close"


func _refresh_skill_check_label() -> void:
	var skill := str(_pending_check_data.get("skill", ""))
	var ability := active_character.get_skill_check_ability(str(_pending_check_data.get("ability", "STR")), skill, bool(_pending_check_data.get("use_primal_knowledge", true)))
	var modifier := active_character.get_skill_check_modifier(skill, ability)
	btn_roll.text = "Roll %s Check (DC %d) [%s]" % [ability, int(_pending_check_data.get("dc", 10)), AbilityScores.format_modifier(modifier)]


func _on_btn_roll_pressed() -> void:
	var command := PlayerCommand.event_roll()
	if command == null:
		return
	_perform_roll(_pending_check_data, _pending_option_or_event, _pending_authored_context)


func _perform_roll(check_data: Dictionary, option_or_event: Dictionary, authored_context: Dictionary = {}) -> void:
	var roll_generation := _popup_generation
	var roll_owner: Character = active_character
	if roll_owner == null or not is_inside_tree():
		return
	check_data = check_data.duplicate(true)
	option_or_event = option_or_event.duplicate(true)
	authored_context = authored_context.duplicate(true)
	if bool(check_data.get("request_familiar_help", false)) and not FamiliarRules.skill_help_available(roll_owner, check_data):
		roll_result_lbl.text = "Your familiar cannot Help now. Clear that choice to roll without its assistance."
		return
	btn_roll.disabled = true
	
	# Roll dice
	var result := EventResolver.resolve_skill_check(roll_owner, check_data, {}, authored_context)
	if not result["success"] and roll_owner.feature_uses.has("bardic_inspiration_die"):
		var die := str(roll_owner.feature_uses.get("bardic_inspiration_die", "1d6"))
		var inspiration_dialog := ConfirmationDialog.new()
		inspiration_dialog.title = "Bardic Inspiration — %s" % roll_owner.character_name
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
		if not _is_current_roll(roll_generation, roll_owner):
			return
		var inspiration := BardicInspirationRules.apply_to_test(roll_owner, int(result["total"]), int(result["dc"]), bool(inspiration_decision["accepted"]))
		if inspiration.get("used", false):
			result["total"] = int(inspiration["total"])
			result["success"] = bool(inspiration["success"])
			result["inspiration_bonus"] = int(inspiration["bonus"])
			result["check_bonus_dice"].append({"source": "bardic_inspiration", "label": "Bardic Inspiration", "sides": int(str(inspiration.get("die", "1d6")).trim_prefix("1d")), "value": int(inspiration["bonus"]), "roll": inspiration.get("roll_details", {}).duplicate(true), "included_in_modifier": false, "applied_before_total_floor": false, "payment_already_settled": true})
	if not result["success"] and roll_owner.has_feature("fighter_tactical_mind") and int(roll_owner.feature_uses.get("fighter_second_wind", 0)) > 0:
		var dialog := ConfirmationDialog.new()
		dialog.title = "Tactical Mind — %s" % roll_owner.character_name
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
		if not _is_current_roll(roll_generation, roll_owner):
			return
		if decision["accepted"]:
			var tactical := FighterRules.tactical_mind(roll_owner, result["total"], result["dc"])
			result["total"] = tactical["total"]
			result["modifier"] += tactical["bonus"]
			result["check_bonus_dice"].append({"source": "fighter_tactical_mind", "label": "Tactical Mind", "sides": 10, "value": int(tactical["bonus"]), "roll": tactical.get("roll_details", {}).duplicate(true), "included_in_modifier": true, "applied_before_total_floor": false, "payment_already_settled": bool(tactical.get("spent", false))})
			result["success"] = result["total"] >= result["dc"]
	var stroke_note := ""
	if not result["success"] and roll_owner.has_feature("rogue_stroke_of_luck") and int(roll_owner.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
		var stroke_dialog := ConfirmationDialog.new()
		stroke_dialog.title = "Stroke of Luck — %s" % roll_owner.character_name
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
		if not _is_current_roll(roll_generation, roll_owner):
			return
		var stroke_result := RogueRules.apply_stroke_of_luck(roll_owner, result, bool(stroke_decision["accepted"]))
		if stroke_result.get("used", false):
			result = stroke_result["result"]
			result["stroke_of_luck_used"] = true
			stroke_note = " (Stroke of Luck)"
	if not GameManager.test_mode and not authored_context.is_empty():
		var post_roll_options := SpellDamageRolls.ability_check_post_roll_options(roll_owner, result)
		if not post_roll_options.is_empty():
			var request := SpellDamageRolls.create_ability_check_post_roll_request(roll_owner, result, self)
			if bool(request.get("success", false)):
				roll_result_lbl.text = "Rolled: %d + %d = %d vs DC %d. Choose one owned check change or decline." % [result["natural_roll"], result["modifier"], result["total"], result["dc"]]
				var selected_offer_id := await _request_ability_check_bonus_choice(post_roll_options, int(result["total"]), int(result["dc"]))
				if not _is_current_roll(roll_generation, roll_owner):
					return
				var settlement := SpellDamageRolls.settle_ability_check_post_roll(roll_owner, request, selected_offer_id)
				if bool(settlement.get("success", false)):
					result = settlement["check_result"]
				else:
					return
	var inspiration_note := " + Bardic Inspiration %d" % int(result.get("inspiration_bonus", 0)) if result.has("inspiration_bonus") else ""
	var post_roll_note := " + owned bonus %d" % int(result.get("post_roll_bonus", 0)) if result.has("post_roll_bonus") else ""
	if not _is_current_roll(roll_generation, roll_owner):
		return
	last_skill_check_result = result.duplicate(true)
	roll_result_lbl.text = "Rolled: %d + %d%s%s = %d!%s" % [result["natural_roll"], result["modifier"], inspiration_note, post_roll_note, result["total"], stroke_note]
	if bool(result.get("familiar_help", false)):
		roll_result_lbl.text += " (Familiar Help: Advantage)"
	
	# Animate color briefly
	if result["success"]:
		roll_result_lbl.add_theme_color_override("font_color", Color.GREEN)
		_resolve_check_outcome(option_or_event.get("success", {}), true)
	else:
		roll_result_lbl.add_theme_color_override("font_color", Color.RED)
		_resolve_check_outcome(option_or_event.get("failure", {}), false)


func _request_ability_check_bonus_choice(options: Array[Dictionary], total: int, dc: int) -> String:
	var choices: Array[String] = [""]
	var labels := {"": "Decline"}
	for option in options:
		var offer_id := str(option.get("offer_id", ""))
		var source_id := str(option.get("source_instance_id", ""))
		if source_id.is_empty() or offer_id.is_empty():
			continue
		choices.append(offer_id)
		var action_label := ""
		if str(option.get("operation_kind", "")) == "mandatory_reroll":
			var scope := "reroll the kept natural d20" if str(option.get("reroll_mode", "")) == "natural_only" else "reroll the whole test"
			var dice_policy := "keep captured bonus dice" if str(option.get("bonus_dice_policy", "")) == "keep" else "reroll captured bonus dice"
			action_label = "%s; %s" % [scope, dice_policy]
		else:
			var policy := str(option.get("payment_policy", "pay_on_choice"))
			var payment_note := "paid only if this converts to success" if policy == "pay_on_converted_success" else "paid when chosen"
			var bonus_label := "roll d%d" % int(option.get("die_size", 0)) if str(option.get("bonus_kind", "numeric")) == "die" else "+%d" % int(option.get("amount", 0))
			action_label = "%s on this check; %s" % [bonus_label, payment_note]
		labels[offer_id] = "%s — %s (%d use%s)" % [str(option.get("label", source_id)), action_label, int(option.get("cost", 0)), "" if int(option.get("cost", 0)) == 1 else "s"]
	if choices.size() <= 1:
		return ""
	var menu := PopupMenu.new()
	_active_ability_bonus_menu = menu
	menu.title = "Ability check: %d vs DC %d" % [total, dc]
	for index in choices.size():
		menu.add_item(str(labels.get(choices[index], choices[index])), index)
	add_child(menu)
	var decision := {"selected": -1, "done": false}
	_active_ability_bonus_decision = decision
	menu.id_pressed.connect(func(id: int):
		decision["selected"] = id
		decision["done"] = true
	)
	menu.popup_hide.connect(func(): decision["done"] = true)
	menu.popup_centered(Vector2i(420, 200))
	var timeout_at_msec := Time.get_ticks_msec() + 30000
	while not decision["done"] and Time.get_ticks_msec() < timeout_at_msec and is_inside_tree():
		await get_tree().process_frame
	if is_instance_valid(menu):
		menu.queue_free()
	if _active_ability_bonus_menu == menu:
		_active_ability_bonus_menu = null
	if _active_ability_bonus_decision == decision:
		_active_ability_bonus_decision = {}
	var selected := int(decision["selected"])
	return choices[selected] if selected > 0 and selected < choices.size() else ""


func _is_current_roll(generation: int, roll_owner: Character) -> bool:
	return is_inside_tree() and generation == _popup_generation and active_character == roll_owner


func _cancel_ability_bonus_prompt() -> void:
	if not _active_ability_bonus_decision.is_empty():
		_active_ability_bonus_decision["done"] = true
	if is_instance_valid(_active_ability_bonus_menu):
		_active_ability_bonus_menu.hide()
		_active_ability_bonus_menu.queue_free()
	_active_ability_bonus_menu = null
	_active_ability_bonus_decision = {}


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
		"teleported": teleported,
		"check_result": last_skill_check_result.duplicate(true),
	}
	event_resolved.emit(result)
	queue_free()
