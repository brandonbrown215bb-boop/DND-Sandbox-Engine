class_name Batch044Controls
extends RefCounted

static func _prepare(b: Character) -> Dictionary:
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "slots": b.spell_slots.duplicate(true)}
	var spells: Array[String] = [Batch044Checks.HUSH, Batch044Checks.UNMAKE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b044_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	return prior

static func _restore(b: Character, prior: Dictionary) -> void:
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	b.spell_slots = prior.slots

static func run(h: Node) -> void:
	h._enter_test("batch_044_parts_magic_flow")
	h._setup_world()
	Batch044Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := _prepare(b)
	var ring := Batch044Checks.add(b, Batch044Checks.MANTLE)
	var host := Batch044Checks.add(b, Batch044Checks.HOST)
	var g1 := Batch044Checks.add(b, Batch044Checks.GEM)
	var g2 := Batch044Checks.add(b, Batch044Checks.GEM)
	# S-210: the HUD attach route fills both gem sockets on the exact host.
	var at1 := AttachmentRules.attach_any(b.inventory, g1)
	var at2 := AttachmentRules.attach_any(b.inventory, g2)
	b.inventory.equip_instance(Inventory.Slot.RING_1, ring)
	b.inventory.equip_instance(Inventory.Slot.RING_2, host)
	h._assert(at1.success and at2.success and AttachmentRules.attached(b.inventory, host).size() == 2 and SourceBenefitRules.total(b, "AC") == 3, "044 actual HUD attach completes the worn host's set (AC bonus=%d)" % SourceBenefitRules.total(b, "AC"))
	var full_ac := b.get_ac()
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
	enemy["hex_position"] = Vector2i(1, 1)
	combat._update_grid_entities()
	# S-203: the HUD self-cast suppresses the listed properties on b's worn copies.
	b.spell_slots = {"1": 2}
	await Batch036Controls.cast(h, combat, b, b, Batch044Checks.HUSH)
	var stop := DataLoader.get_spell(Batch044Checks.STOP)
	h._assert(b.get_ac() == full_ac - 3 and not SpellPermissionRules.for_spell(b, stop).is_empty() and b.inventory.equipped_instance_id(Inventory.Slot.RING_1) == ring, "044 actual HUD cast suppresses the ring benefit and the set but keeps the spell permission (ac %d -> %d)" % [full_ac, b.get_ac()])
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, b.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == full_ac - 3, "044 actual monster attack reads the suppressed AC (%d)" % int(combat.last_monster_weapon_attack_result.get("target_ac", -1)))
	if not b.concentrating_on.is_empty(): SpellEffects.end_concentration(b, [b])
	h._assert(b.get_ac() == full_ac, "044 actual concentration end restores the still-worn copies without re-equipping")
	combat._reset_turn_action_economy()
	await Batch036Controls.cast(h, combat, b, b, Batch044Checks.UNMAKE)
	h._assert(SpellPermissionRules.for_spell(b, stop).is_empty() and b.get_ac() == full_ac and b.inventory.get_instance(ring).state.get("destroyed_magic", {}).has("spell_permissions"), "044 actual HUD cast destroys only the ring's spell permission")
	# Real detach of one gem disables only its set.
	var off := AttachmentRules.detach(b.inventory, host, "gem_b")
	h._assert(off.success and Batch044Checks.owns(b, g2) and b.get_ac() == full_ac - 1, "044 actual detach disables only the set that needs that gem")
	AttachmentRules.attach_any(b.inventory, g2)
	b.current_hp = b.max_hp
	# Recast so the real save carries a live suppression.
	combat._reset_turn_action_economy()
	b.spell_slots = {"1": 1}
	await Batch036Controls.cast(h, combat, b, b, Batch044Checks.HUSH)
	var live_source := str(b.concentrating_on.get("effect_source", ""))
	h._teardown_scene(combat)
	_restore(b, prior)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_044_parts_magic"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = not live_source.is_empty() and block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "044 actual real save with attached parts, live suppression and destroyed magic (block='%s' source=%s)" % [block, live_source])
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and nb != null and nb != b and AttachmentRules.attached(nb.inventory, host).keys().size() == 2 and nb.get_ac() == full_ac - 3 and SpellPermissionRules.for_spell(nb, stop).is_empty(), "044 actual real load keeps the exact parts, the live suppression and the destroyed permission")
		if nb != null:
			SpellEffects.end_concentration(nb, [nb])
			h._assert(nb.get_ac() == full_ac and SpellPermissionRules.for_spell(nb, stop).is_empty(), "044 actual concentration end after reload restores only the suppressed properties")
		SaveManager.delete_save(slot)
	h._exit_test()
