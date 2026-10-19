## Real CombatHUD controls for source-owned spell permission/payment rows.
class_name Batch021Controls
extends RefCounted

static func run(harness: Node) -> void:
	harness._enter_test("batch_021_spell_permissions_flow")
	SpellPermissionChecks.load_fixtures()
	harness._setup_world()
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 10, "DEX": 14, "CON": 14, "INT": 10, "WIS": 16, "CHA": 12})
	var bard := Character.new()
	bard.initialize("Permission Bard", "human", "bard", scores)
	var spellcasting_id := bard.get_spellcasting_feature_id()
	bard.feature_choices[spellcasting_id] = ["healing_word"]
	bard.known_spells = ["healing_word"]
	bard.spell_slots = {"1": 1}
	bard.features.append({"id": "fixture_healing_word_innate", "type": "passive", "effects": [{"type": "spell_free_cast", "spells": ["healing_word"], "uses": 1, "ability": "WIS"}]})
	bard.feature_uses["free_spell_cast:fixture_healing_word_innate"] = 1
	bard.features.append({"id": "fixture_healing_word_points", "type": "passive", "effects": [{"type": "always_prepared_spells", "spells": ["healing_word"], "ability": "WIS", "point_payment": {"resource_id": "fixture_points", "cost": 2}}]})
	bard.feature_uses["fixture_points"] = 2
	PlayerManager.set_player_character(0, bard)
	PartyManager.reset()
	PartyManager.register_player_character(0, bard)
	var combat: Node = await harness._spawn_scene("res://scenes/combat.tscn", 1.0)
	combat.current_player_idx = 0
	combat.active_character = bard
	combat.active_combatant = {"id": "player_0", "is_player": true, "entity": bard}
	combat.turn_budget.reset(bard, combat.player_entities)
	combat.remaining_attack_swings = 0
	combat.hud.update_hud(bard, combat.tracker)
	combat.hud._show_spell_selection()
	var slot_entry: Dictionary = {}
	var free_entry: Dictionary = {}
	var point_entry: Dictionary = {}
	for spell_entry in combat.hud.spells_registered:
		if str(spell_entry.get("id", "")) != "healing_word":
			continue
		match str(spell_entry.get("_spell_payment_kind", "")):
			"slot":
				if slot_entry.is_empty(): slot_entry = spell_entry
			"free_cast":
				if free_entry.is_empty(): free_entry = spell_entry
			"points":
				if point_entry.is_empty(): point_entry = spell_entry
	harness._assert(not slot_entry.is_empty() and slot_entry.get("_source_permission_id", "") == "class:%s" % spellcasting_id, "Class permission exposes the owning-class slot choice in the real combat picker")
	harness._assert(not free_entry.is_empty() and free_entry.get("_spell_payment_source_id", "") == "fixture_healing_word_innate" and free_entry.get("_spellcasting_ability", "") == "WIS", "Innate permission exposes its own free-use source and ability in the picker")
	harness._assert(not point_entry.is_empty() and point_entry.get("_spell_payment_kind", "") == "points", "Authored point payment appears as a separate real combat choice")
	var free_index: int = combat.hud.spells_registered.find(free_entry)
	if free_index >= 0:
		combat.hud._on_spell_selected(free_index)
		harness._assert(combat.pending_action_type == "spell" and combat.pending_spell_data.get("_spell_payment_source_id", "") == "fixture_healing_word_innate", "Choosing the innate row carries its exact source into the pending cast")
		combat._cancel_pending_action()
		harness._assert(bard.feature_uses.get("free_spell_cast:fixture_healing_word_innate", 0) == 1 and bard.spell_slots.get("1", 0) == 1, "Canceling before cast commitment leaves the selected payment untouched")
		var forged := slot_entry.duplicate(true)
		forged["_spell_payment_kind"] = "free_cast"
		forged["_spell_payment_source_id"] = "fixture_healing_word_innate"
		combat._on_hud_action("cast_spell", {"spell":forged})
		harness._assert(combat.pending_action_type.is_empty() and combat.turn_budget.bonus_action_available and bard.feature_uses["free_spell_cast:fixture_healing_word_innate"] == 1, "Forged cross-source payment is refused by the real HUD command path before targeting or spending")
		var stale := _resource_context(bard, free_entry, combat.hud, combat.turn_budget)
		var innate: Dictionary = bard.features.filter(func(feature): return feature.get("id", "") == "fixture_healing_word_innate")[0]
		bard.features.erase(innate)
		harness._assert(not SpellCastResources.commit_metamagic(stale) and not SpellCastResources.commit_spell_resource(_resource_context(bard, free_entry, combat.hud, combat.turn_budget)) and bard.spell_slots["1"] == 1 and bard.feature_uses["free_spell_cast:fixture_healing_word_innate"] == 1, "Source loss after selection refuses before Metamagic or spell payment")
		bard.features.append(innate)
		var free_context := _resource_context(bard, free_entry, combat.hud, combat.turn_budget)
		var free_committed := SpellCastResources.commit_spell_resource(free_context)
		harness._assert(free_committed and bard.feature_uses.get("free_spell_cast:fixture_healing_word_innate", 1) == 0 and bard.spell_slots.get("1", 0) == 1, "Cast resource commitment spends the selected innate use and preserves the slot")
		var point_context := _resource_context(bard, point_entry, combat.hud, combat.turn_budget)
		var points_committed := SpellCastResources.commit_spell_resource(point_context)
		harness._assert(points_committed and bard.feature_uses.get("fixture_points", -1) == 0 and bard.spell_slots.get("1", 0) == 1, "Cast resource commitment spends the authored point cost without also spending a slot")
		var slot_context := _resource_context(bard, slot_entry, combat.hud, combat.turn_budget)
		var slot_committed := SpellCastResources.commit_spell_resource(slot_context)
		harness._assert(slot_committed and bard.spell_slots.get("1", 1) == 0, "Cast resource commitment spends the selected class slot")
		var sorcerer := Character.new()
		sorcerer.initialize("Point caster", "human", "sorcerer", scores)
		sorcerer.features.append({"id":"fixture:point_cast","type":"passive","effects":[{"type":"always_prepared_spells","spells":["healing_word"],"point_payment":{"resource_id":"sorcery_points","cost":2}}]})
		sorcerer.feature_uses["sorcery_points"] = 2
		var point_row: Dictionary = SpellPermissionRules.payment_choices(sorcerer, "healing_word").filter(func(row): return row._spell_payment_kind == "points")[0]
		point_row["_metamagic_distant"] = true
		var combined := _resource_context(sorcerer, point_row, combat.hud, combat.turn_budget)
		harness._assert(not SpellCastResources.commit_metamagic(combined) and sorcerer.get_sorcery_points() == 2, "Spell point and Metamagic costs preflight together without partial payment")
		sorcerer.feature_uses["sorcery_points"] = 3
		combined = _resource_context(sorcerer, point_row, combat.hud, combat.turn_budget)
		harness._assert(SpellCastResources.commit_metamagic(combined) and SpellCastResources.commit_spell_resource(combined) and sorcerer.get_sorcery_points() == 0, "An affordable point cast pays both declared costs exactly once")
		sorcerer.feature_uses["sorcery_points"] = 2
		combined = _resource_context(sorcerer, point_row, combat.hud, combat.turn_budget)
		combined.spell["_metamagic_distant_free"] = true
		harness._assert(not SpellCastResources.commit_metamagic(combined) and sorcerer.get_sorcery_points() == 2, "A stale free Metamagic selection cannot silently substitute a paid point")
	harness._teardown_scene(combat)
	await harness.get_tree().process_frame
	await _sources(harness)
	harness._exit_test()

static func _sources(harness: Node) -> void:
	GameManager.current_state = GameManager.GameState.OVERWORLD
	var c := SpellPermissionChecks.actor()
	var sources := SpellRepertoireRules.sources(c)
	for source in sources:
		var panel := ClassTraining.new()
		panel._build_repertoire(c, source, func(): pass)
		for child in panel.get_children():
			if child is OptionButton:
				for index in child.item_count:
					if child.get_item_metadata(index) == "fixture:021_shared0": child.select(index)
		for child in panel.get_children():
			if child is Button and not child is OptionButton:
				child.pressed.emit()
				var before := c.to_dict().duplicate(true)
				child.pressed.emit()
				harness._assert(c.feature_choices.get(source.id, []) == ["fixture:021_shared0"] and c.to_dict() == before, "Actual preparation control trains only its source and refuses replay: " + str(source.name))
		panel.free()
	for index in 2: c.inventory.add_item("fixture:021_ring")
	var rings: Array = c.inventory.backpack_instances().filter(func(copy): return copy.definition_id == "fixture:021_ring")
	for index in 2:
		c.inventory.equip_instance(Inventory.Slot.RING_1 if index == 0 else Inventory.Slot.RING_2, str(rings[index].instance_id))
		c.inventory.attune_instance(str(rings[index].instance_id), c.character_id)
	PlayerManager.set_player_character(0, c)
	PartyManager.reset()
	PartyManager.register_player_character(0, c)
	var combat: Node = await harness._spawn_scene("res://scenes/combat.tscn", 1.0)
	combat.current_player_idx = 0
	combat.active_character = c
	combat.active_combatant = {"id":"player_0","is_player":true,"entity":c}
	combat.turn_budget.reset(c, combat.player_entities)
	combat.hud.update_hud(c, combat.tracker)
	combat.hud._show_spell_selection()
	var item_rows: Array = combat.hud.spells_registered.filter(func(row): return row.get("_spell_payment_kind", "") == "item_charges")
	harness._assert(item_rows.size() == 2 and item_rows[0]._source_permission_id != item_rows[1]._source_permission_id, "Actual picker keeps two identical item copies as distinct spell permissions")
	if item_rows.size() == 2:
		var row: Dictionary = item_rows[0]
		var first := str(row._spell_payment_source_id)
		var second := str(item_rows[1]._spell_payment_source_id)
		combat.hud._on_spell_selected(combat.hud.spells_registered.find(row))
		harness._assert(combat.pending_action_type == "spell" and combat.pending_spell_data._spell_payment_source_id == first, "Actual item spell selection reaches targeting with the exact copy")
		combat._cancel_pending_action()
		harness._assert(c.inventory.get_instance(first).state.charges == 3 and c.inventory.get_instance(second).state.charges == 3, "Canceling an item spell spends neither copy")
		var cast := _resource_context(c, row, combat.hud, combat.turn_budget)
		harness._assert(SpellCastResources.commit_spell_resource(cast) and c.inventory.get_instance(first).state.charges == 2 and c.inventory.get_instance(second).state.charges == 3, "Item cast pays only the chosen copy's declared charge")
		c.current_hp = maxi(1, c.max_hp - 4)
		var hp_before := c.current_hp
		combat.turn_budget.reset(c, combat.player_entities)
		combat.hud._show_spell_selection()
		var actual_index := -1
		for index in combat.hud.spells_registered.size():
			if combat.hud.spells_registered[index].get("_spell_payment_kind", "") == "item_charges" and combat.hud.spells_registered[index].get("_spell_payment_source_id", "") == first: actual_index = index
		if actual_index >= 0:
			combat.hud._on_spell_selected(actual_index)
			await combat._execute_player_spell(combat.player_entities[0].hex_position)
		harness._assert(actual_index >= 0 and c.current_hp == hp_before + 2 and c.inventory.get_instance(first).state.charges == 1 and c.inventory.get_instance(second).state.charges == 3 and not combat.turn_budget.action_available, "Actual item Cast and target controls resolve healing and pay one charge and one action")
		c.inventory.unattune_instance(first, c.character_id)
		harness._assert(CombatCommand.from_hud_for_character("cast_spell", {"spell":row}, c) == null and not SpellCastResources.commit_spell_resource(_resource_context(c, row, combat.hud, combat.turn_budget)), "Losing item attunement rejects stale command and payment without substitution")
	harness._teardown_scene(combat)
	await harness.get_tree().process_frame


static func _resource_context(caster: Character, spell: Dictionary, hud: CombatHUD, budget: CombatTurnBudget) -> SpellCastContext:
	var cast := SpellCastContext.new()
	cast.caster = caster
	cast.spell = spell.duplicate(true)
	cast.hud = hud
	cast.turn_budget = budget
	cast.highlight_reachable = func(): pass
	return cast
