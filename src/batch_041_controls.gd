class_name Batch041Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_041_bond_equipment_flow")
	h._setup_world()
	Batch041Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	var prior_slots := b.spell_slots.duplicate(true)
	var spells: Array[String] = [Batch041Checks.GUISE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b041_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 2}]})
	var charm := Batch041Checks.add_copy(b, Batch041Checks.CHARM)
	b.inventory.equip_instance(Inventory.Slot.RING_1, charm)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	var normal_ac := b.get_ac()
	# S-164: the HUD cast offers no equipment choice, so three legal policies refuse.
	b.spell_slots = {"2": 1}
	await Batch036Controls.cast(h, combat, b, b, Batch041Checks.GUISE)
	h._assert(not ActorProjectionRules.is_projected(b) and b.get_ac() == normal_ac and SourceBenefitRules.total(b, "AC") == 2, "041 actual cast without a chosen equipment policy leaves the actor and its copies unchanged")
	# The same production resolver with the merged policy chosen.
	var r := Batch041Checks.guise(b, "merged")
	h._assert(r.get("projection", {}).get("projected", false) and b.inventory.equipped_instance_id(Inventory.Slot.RING_1) == charm and SourceBenefitRules.total(b, "AC") == 0, "041 actual merged projection keeps the charm worn with its effect suppressed")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, b.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == 12, "041 actual monster attack reads the form AC without the merged charm (%d)" % int(combat.last_monster_weapon_attack_result.get("target_ac", -1)))
	# The hit may break Concentration; recast so the save round trip carries a live projection.
	if not ActorProjectionRules.is_projected(b): Batch041Checks.guise(b, "merged")
	b.current_hp = b.max_hp
	# S-161: an exact equipped weapon copy bonds, and dropping it in play ends only that bond.
	var prior_a_features := a.features.duplicate(true)
	a.features.append(DataLoader.get_character_class(Batch041Checks.CLASS_ID).features_by_level["1"][0].duplicate(true))
	var weapon := a.inventory.equipped_instance_id(Inventory.Slot.WEAPON)
	var bonded := BondRules.bond(a, Batch041Checks.BLADE, weapon)
	var spare := Batch041Checks.add_copy(a, "dagger")
	var kept := BondRules.bond(a, Batch041Checks.BLADE, spare)
	h._assert(bonded.get("bonded", false) and kept.get("bonded", false) and kept.released == weapon and BondRules.bonded(a, Batch041Checks.BLADE) == [spare], "041 actual equipped copy bonds and a legal replacement releases only it (weapon=%s)" % weapon)
	a.inventory.equip_instance(Inventory.Slot.WEAPON, spare)
	var dropped := a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	h._assert(str(dropped.get("instance_id", "")) == spare and BondRules.bonded(a, Batch041Checks.BLADE).is_empty() and a.inventory.owned_instances().any(func(c): return str(c.instance_id) == weapon), "041 actual dropped bonded copy ends that bond; the other copy stays owned")
	a.inventory.receive_instance(dropped)
	a.features = prior_a_features
	a.exclusive_bonds.clear()
	h._teardown_scene(combat)
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	b.spell_slots = prior_slots
	# Real SaveManager round trip in session with the merged projection live.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_041_equipment"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "041 actual real save with a merged projection (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and nb != null and nb != b and ActorProjectionRules.equipment_policy(nb) == "merged" and nb.get_ac() == 12 and SourceBenefitRules.total(nb, "AC") == 0 and nb.inventory.equipped_instance_id(Inventory.Slot.RING_1) == charm, "041 actual real load keeps the merged copy worn and suppressed (ac=%d proj=%s pol=%s total=%d ring=%s effects=%s)" % [nb.get_ac(), str(ActorProjectionRules.is_projected(nb)), ActorProjectionRules.equipment_policy(nb), SourceBenefitRules.total(nb, "AC"), nb.inventory.equipped_instance_id(Inventory.Slot.RING_1), str(nb.spell_effects.keys())])
		if nb != null:
			SpellEffects.end_concentration(nb, [nb])
			h._assert(not ActorProjectionRules.is_projected(nb) and nb.get_ac() == normal_ac and SourceBenefitRules.total(nb, "AC") == 2, "041 actual concentration end after reload restores the merged charm's effect")
			b = nb
		SaveManager.delete_save(slot)
	b.inventory.unequip(Inventory.Slot.RING_1)
	h._exit_test()
