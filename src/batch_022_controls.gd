## Real CombatHUD controls for combined ordinary and Pact spell slot pools.
class_name Batch022Controls
extends RefCounted

static func run(harness: Node) -> void:
	harness._enter_test("batch_022_slot_ritual_flow")
	harness._setup_world()
	var scores := AbilityScores.new()
	scores.from_dict({"STR":10,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":16})
	var bard := Character.new()
	bard.initialize("Pact Payment Bard", "human", "bard", scores)
	bard.level = 7
	bard.class_levels = {"bard":4,"warlock":3}
	bard._update_spell_slots()
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	var combat: Node = await harness._spawn_scene("res://scenes/combat.tscn", 1.0)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"id":"player_0","is_player":true,"entity":bard}
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.hud.update_hud(bard, combat.tracker)
	combat.hud._show_spell_selection()
	var pact_row: Dictionary = {}
	var ordinary_row: Dictionary = {}
	for row in combat.hud.spells_registered:
		if str(row.get("id", "")) != "healing_word" or str(row.get("_spell_payment_kind", "")) != "slot": continue
		if str(row.get("_spell_slot_pool_id", "")) == "pact": pact_row = row
		if str(row.get("_spell_slot_pool_id", "")) == "ordinary": ordinary_row = row
	harness._assert(not pact_row.is_empty() and not ordinary_row.is_empty(), "Real picker offers ordinary and Pact slot payments for the prepared Bard spell")
	if not pact_row.is_empty():
		var pact_before := bard.pact_spell_slots.duplicate(true)
		var ordinary_before := bard.spell_slots.duplicate(true)
		combat.hud._on_spell_selected(combat.hud.spells_registered.find(pact_row))
		harness._assert(combat.pending_action_type == "spell" and combat.pending_spell_data.get("_spell_slot_pool_id", "") == "pact" and combat.pending_spell_data.get("_spellcasting_ability", "") == "CHA", "Choosing Pact payment in the actual picker keeps its pool and the Bard's casting ability")
		combat._cancel_pending_action()
		harness._assert(bard.pact_spell_slots == pact_before and bard.spell_slots == ordinary_before, "Canceling the selected Pact cast spends neither slot pool")
		var command := CombatCommand.from_hud_for_character("cast_spell", {"spell":pact_row}, bard)
		var cast := _resource_context(bard, pact_row, combat.hud, combat.turn_budget)
		var committed := SpellCastResources.commit_spell_resource(cast)
		harness._assert(command != null and command.payload.spell.get("_spell_slot_pool_id", "") == "pact" and committed and bard.pact_spell_slots.get("2", -1) == int(pact_before.get("2", 0)) - 1 and bard.spell_slots == ordinary_before, "Command validation and payment commit spend only the exact Pact pool")
		bard.short_rest()
		harness._assert(bard.pact_spell_slots == pact_before and bard.spell_slots == ordinary_before, "Short Rest restores Pact slots and leaves ordinary slots unchanged")
	harness._teardown_scene(combat)
	await harness.get_tree().process_frame
	await _ritual_controls(harness)
	harness._exit_test()


static func _ritual_controls(harness: Node) -> void:
	var c := SpellSlotChecks.ritual_actor()
	PlayerManager.set_player_character(0, c)
	PartyManager.reset()
	PartyManager.register_player_character(0, c)
	for index in 2: c.inventory.add_item("fixture:022_ring")
	var rings := c.inventory.backpack_instances().filter(func(copy): return copy.definition_id == "fixture:022_ring")
	for index in 2:
		c.inventory.equip_instance(Inventory.Slot.RING_1 if index == 0 else Inventory.Slot.RING_2, str(rings[index].instance_id))
		c.inventory.attune_instance(str(rings[index].instance_id), c.character_id)
	var combat: Node = await harness._spawn_scene("res://scenes/combat.tscn", 1.0)
	combat.current_player_idx = 0
	combat.active_character = c
	combat.active_combatant = {"id":"player_0","is_player":true,"entity":c}
	combat.turn_budget.reset(c, combat.player_entities)
	combat.hud.update_hud(c, combat.tracker)
	combat.hud._show_spell_selection()
	var normal: Array = combat.hud.spells_registered.filter(func(row): return row.get("id", "") == "fixture:022_renewal")
	harness._assert(normal.size() == 1 and normal[0].get("_spellcasting_ability", "") == "CHA" and normal[0].get("_spell_payment_kind", "") == "slot", "Real combat picker offers only the normal permission, never ritual-only feature/item payments")
	var slots := c.spell_slots.duplicate(true)
	if normal.size() == 1:
		combat.hud._on_spell_selected(combat.hud.spells_registered.find(normal[0]))
		combat._cancel_pending_action()
	harness._assert(c.spell_slots == slots, "Canceling the normal version of a ritual spell spends nothing")
	harness._teardown_scene(combat)
	await harness.get_tree().process_frame
	GameManager.current_state = GameManager.GameState.OVERWORLD
	CharacterSheet.show_sheet(c)
	await harness.get_tree().process_frame
	var buttons := _ritual_buttons()
	var renewal: Array = buttons.filter(func(button): return button.get_meta("ritual_choice").spell_id == "fixture:022_renewal")
	harness._assert(CharacterSheet.is_open() and renewal.size() == 3, "Actual exploration sheet offers the feature and both exact attuned item copies as distinct ritual sources")
	var clock := int(GameManager.campaign_elapsed_seconds)
	c.current_hp = 1
	var item_buttons: Array = renewal.filter(func(button): return button.get_meta("ritual_choice").permission.kind == "item")
	if item_buttons.size() == 2:
		var choice: Dictionary = item_buttons[0].get_meta("ritual_choice")
		item_buttons[0].pressed.emit()
		await harness.get_tree().process_frame
		harness._assert(c.current_hp == 5 and c.spell_slots == slots and GameManager.campaign_elapsed_seconds == clock + 606, "Pressing the actual item ritual button applies its INT effect and 606-second time without a slot")
		var success_status := CharacterSheet._content.find_child("RitualStatus", true, false) as Label
		harness._assert(CharacterSheet._content.get_children().any(func(child): return child is Label and child.text.contains("HP 5/")) and success_status != null and success_status.text.contains("ritual; no spell slot used"), "Successful ritual refreshes visible sheet vitals and keeps its result message")
		harness._assert(c.inventory.get_instance(str(rings[0].instance_id)).state.charges == 3 and c.inventory.get_instance(str(rings[1].instance_id)).state.charges == 3, "Explicit ritual access leaves both item copies' normal-cast charges intact")
		c.inventory.unequip(Inventory.Slot.RING_1)
		clock = int(GameManager.campaign_elapsed_seconds)
		var hp := c.current_hp
		var stale_buttons := _ritual_buttons().filter(func(button): return button.get_meta("ritual_choice").permission.id == choice.permission.id and button.get_meta("ritual_choice").spell_id == choice.spell_id)
		if not stale_buttons.is_empty(): stale_buttons[0].pressed.emit()
		harness._assert(c.current_hp == hp and c.spell_slots == slots and GameManager.campaign_elapsed_seconds == clock, "Lost exact-copy source refuses through the real button without switching to its sibling or feature")
		var status := CharacterSheet._content.find_child("RitualStatus", true, false) as Label
		harness._assert(status != null and status.text.contains("cannot cast"), "Ritual refusal is visible in the sheet")
	var material: Array = _ritual_buttons().filter(func(button): return button.get_meta("ritual_choice").spell_id == "fixture:022_material" and button.get_meta("ritual_choice").permission.kind == "feature")
	if material.size() == 1:
		clock = int(GameManager.campaign_elapsed_seconds)
		material[0].pressed.emit()
		harness._assert(GameManager.campaign_elapsed_seconds == clock and c.spell_slots == slots, "Actual ritual button refuses a missing component before advancing time or spending")
		c.inventory.add_item("fixture:022_dust")
		material[0].pressed.emit()
		harness._assert(GameManager.campaign_elapsed_seconds == clock + 606 and not c.inventory.has_item("fixture:022_dust") and c.spell_slots == slots, "Actual feature ritual button consumes the required material and preserves slots")
		await harness.get_tree().process_frame
	var lasting: Array = _ritual_buttons().filter(func(button): return button.get_meta("ritual_choice").spell_id == "fixture:022_lasting" and button.get_meta("ritual_choice").permission.kind == "feature")
	if lasting.size() == 1:
		lasting[0].pressed.emit()
		await harness.get_tree().process_frame
		var source := str(c.concentrating_on.get("effect_source", ""))
		harness._assert(c.spell_effects.get(source, {}).get("remaining_seconds", 0) == 60 and c.has_condition("blessed"), "Actual party-member ritual begins its full effect duration after the ten-minute delay")
		GameManager.advance_campaign_time(6)
		harness._assert(c.spell_effects.get(source, {}).get("remaining_seconds", 0) == 54, "Completed ritual duration ticks normally with subsequent exploration time")
		c.spell_effects[source].remaining_seconds = 3600
		var feature_buttons: Array = _ritual_buttons().filter(func(button): return button.get_meta("ritual_choice").spell_id == "fixture:022_renewal" and button.get_meta("ritual_choice").permission.kind == "feature")
		if feature_buttons.size() == 1: feature_buttons[0].pressed.emit()
		await harness.get_tree().process_frame
		harness._assert(not c.spell_effects.has(source) and c.concentrating_on.is_empty() and not c.has_condition("blessed"), "Even a non-concentration ritual ends the previous long concentration when casting begins")
	c.protection_from_energy_type = "fire"
	c.concentrating_on = {"spell_id":"protection_from_energy","targets":[c]}
	var native_test_buttons := _ritual_buttons().filter(func(button): return button.get_meta("ritual_choice").spell_id == "fixture:022_renewal" and button.get_meta("ritual_choice").permission.kind == "feature")
	if not native_test_buttons.is_empty(): native_test_buttons[0].pressed.emit()
	await harness.get_tree().process_frame
	harness._assert(c.protection_from_energy_type.is_empty() and c.concentrating_on.is_empty(), "Starting a ritual also removes prior native concentration benefits without an effect-source ID")
	CharacterSheet.close_sheet()
	GameManager.current_state = GameManager.GameState.COMBAT
	CharacterSheet.show_sheet(c)
	await harness.get_tree().process_frame
	harness._assert(_ritual_buttons().is_empty(), "Combat character sheet exposes no exploration ritual controls")
	CharacterSheet.close_sheet()
	await harness.get_tree().process_frame


static func _ritual_buttons() -> Array:
	return CharacterSheet._content.find_children("*", "Button", true, false).filter(func(button): return button.has_meta("ritual_choice"))

static func _resource_context(caster: Character, spell: Dictionary, hud: CombatHUD, budget: CombatTurnBudget) -> SpellCastContext:
	var cast := SpellCastContext.new()
	cast.caster = caster
	cast.spell = spell.duplicate(true)
	cast.hud = hud
	cast.turn_budget = budget
	cast.highlight_reachable = func(): pass
	return cast
