class_name Batch031Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_031_linked_damage_flow")
	h._setup_world()
	Batch031Checks.load_fixtures()
	var alice: Character = PlayerManager.get_player(0).get("character")
	var bob: Character = PlayerManager.get_player(1).get("character")
	var link_spell := "fixture:b031_split_link"
	var redirect_spell := "fixture:b031_renamed_redirect_link"
	var flat_spell := "fixture:b031_flat_arc"
	var ordered_spell := "fixture:b031_ordered_arc"
	var combined_spell := "fixture:b031_combined_link"
	var test_spells := [link_spell, redirect_spell, flat_spell, ordered_spell, combined_spell]
	var prior_known_spells := bob.known_spells.duplicate()
	var prior_spellbook := bob.wizard_spellbook.duplicate()
	var prior_feature_choices := bob.feature_choices.duplicate(true)
	var prior_features := bob.features.duplicate(true)
	bob.known_spells.assign(test_spells)
	bob.wizard_spellbook.assign(test_spells)
	bob.feature_choices[bob.get_spellcasting_feature_id()] = test_spells.duplicate()
	bob.features.append({"id": "fixture:b031_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": test_spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	bob.spell_slots["1"] = 4
	alice.willingness = "willing"
	bob.willingness = "willing"
	# Ordinary receipt checks keep this link alive deterministically. Dedicated
	# regressions below force failure and knockout instead.
	bob.add_modifier("roll", "save:CON", 100, 999)
	alice.feature_uses["damage_resistances"] = ["fire"]
	bob.feature_uses["damage_vulnerabilities"] = ["fire"]
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		if entry.get("character") == alice: entry["hex_position"] = Vector2i.ZERO
		if entry.get("character") == bob: entry["hex_position"] = Vector2i(0, 1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(2, 0)
	enemy["armor_class"] = 5
	combat._update_grid_entities()
	h._p_focus(combat, bob)
	var linked_cast := await _cast_to(h, combat, bob, link_spell, _position(combat, alice))
	h._assert(linked_cast and _has_link(alice, bob), "031 actual spell picker and target click grant the exact timed link to the willing recipient")
	var link_source := _source_for(alice, bob)
	h._assert(not link_source.is_empty() and int(bob.spell_slots.get("1", 0)) == 3 and not combat.turn_budget.action_available, "031 link acquisition costs one Action and one level-1 slot once")
	# Exercise the real incoming monster weapon path. The attack profile is fixed
	# in this harness so each recipient's typed settlement can be inspected.
	var saved_attacks: Array = enemy.get("attacks", []).duplicate(true)
	var weapon_attack: Dictionary = enemy.get("attacks", [])[0].duplicate(true)
	weapon_attack["damage"] = "5"
	weapon_attack["damage_type"] = "cold"
	weapon_attack["attack_bonus"] = 100
	weapon_attack["attack_bonus_override"] = 100
	enemy["attacks"] = [weapon_attack]
	alice.feature_uses["damage_resistances"] = ["cold"]
	bob.feature_uses["damage_vulnerabilities"] = ["cold"]
	alice.current_hp = 40
	bob.current_hp = 40
	var alice_base_ac := alice.base_ac
	alice.base_ac = 1
	var alice_before_weapon := alice.current_hp
	var bob_before_weapon := bob.current_hp
	_seed_hit()
	await combat._execute_monster_attack(enemy, alice.character_name, 0)
	var weapon_result: Dictionary = combat.last_monster_weapon_attack_result
	var weapon_components: Array = weapon_result.get("damage_components", [])
	var weapon_receipt: Dictionary = weapon_components[0].get("receipt", {}) if not weapon_components.is_empty() else {}
	var weapon_recipients: Array = weapon_receipt.get("recipient_receipts", [])
	h._assert(weapon_result.get("hit", false) and weapon_result.has("attack_roll") and weapon_receipt.get("damage_link", {}).get("amount_transferred", -1) == 2, "031 one actual monster weapon roll is split once across the exact linked pair")
	h._assert(weapon_recipients.size() == 2 and weapon_recipients[0].raw == 3 and weapon_recipients[0].resolved == 1 and weapon_recipients[1].raw == 2 and weapon_recipients[1].resolved == 4 and alice.current_hp == alice_before_weapon - 1 and bob.current_hp == bob_before_weapon - 4, "031 weapon recipient receipts preserve separate raw/resolved values and apply each actor's own defense")
	h._assert(str(weapon_receipt.get("damage_source_actor_id", "")) == str(enemy.get("id", "")) and int(weapon_receipt.get("damage_occurrence_id", 0)) > 0 and weapon_result.get("damage_components", []).size() == 1, "031 weapon settlement retains the original attacker and occurrence identity with one parent damage component")
	alice.base_ac = alice_base_ac
	enemy["attacks"] = saved_attacks

	# Flat shared spell: one odd fire packet is split, then resistance,
	# vulnerability and Temporary HP settle independently for each actor.
	alice.current_hp = 40
	bob.current_hp = 40
	alice.feature_uses["damage_resistances"] = ["fire"]
	bob.feature_uses["damage_vulnerabilities"] = ["fire"]
	alice.temp_hp = 1
	bob.temp_hp = 3
	var alice_hp := alice.current_hp
	var bob_hp := bob.current_hp
	h._p_focus(combat, bob)
	var flat_cast := await _cast_to(h, combat, bob, flat_spell, _position(combat, alice))
	var flat_components: Array = combat.last_spell_damage_receipts
	var flat_receipt: Dictionary = flat_components[0] if not flat_components.is_empty() else {}
	var recipients: Array = flat_receipt.get("recipient_receipts", [])
	h._assert(flat_cast and int(bob.spell_slots.get("1", 0)) == 2 and not combat.turn_budget.action_available, "031 flat damage control commits one parent Action and slot for both recipients")
	h._assert(recipients.size() == 2 and recipients[0].raw == 3 and recipients[0].prevented == 2 and recipients[0].resolved == 1 and recipients[0].ward_absorbed == 0 and recipients[0].temp_hp_absorbed == 1 and recipients[0].hp_loss == 0 and recipients[1].raw == 2 and recipients[1].prevented == 0 and recipients[1].resolved == 4 and recipients[1].ward_absorbed == 0 and recipients[1].temp_hp_absorbed == 3 and recipients[1].hp_loss == 1, "031 flat control exposes separate raw, prevention, ward/Temporary HP, resolved and HP-loss receipts")
	h._assert(alice.current_hp == alice_hp and bob.current_hp == bob_hp - 1 and int(flat_receipt.get("damage_link", {}).get("amount_transferred", -1)) == 2, "031 flat split conserves odd raw damage before independent defenses change final HP loss")

	# Ordered damage retains one spell payment and exposes each step's own linked
	# settlement; the later packet does not replay the first packet.
	alice.temp_hp = 0
	bob.temp_hp = 0
	alice_hp = alice.current_hp
	bob_hp = bob.current_hp
	h._p_focus(combat, bob)
	var ordered_cast := await _cast_to(h, combat, bob, ordered_spell, _position(combat, alice))
	var ordered_components: Array = combat.last_spell_damage_receipts
	var ordered_result: Dictionary = ordered_components[0] if not ordered_components.is_empty() else {}
	h._assert(ordered_cast and int(bob.spell_slots.get("1", 0)) == 1 and not combat.turn_budget.action_available, "031 ordered shared-spell target click settles the parent cost once across ordered continuation")
	h._assert(alice.current_hp < alice_hp and bob.current_hp < bob_hp and ordered_components.size() == 2 and ordered_result.get("recipient_receipts", []).size() == 2 and ordered_components[1].get("recipient_receipts", []).size() == 2, "031 ordered spell continues through both typed damage steps and exposes both recipients for each single parent cast")

	# End only the selected source, then prove a renamed full redirect through a
	# second actual picker/target flow.
	SpellEffects.remove(alice, link_source, "fixture_source_removal")
	bob.spell_slots["1"] = 1
	h._p_focus(combat, bob)
	var redirect_cast := await _cast_to(h, combat, bob, redirect_spell, _position(combat, alice))
	h._assert(redirect_cast and _source_for(alice, bob) != link_source, "031 source removal ends only the old exact link and the renamed definition reacquires independently")
	bob.spell_slots["1"] = 1
	var before_redirect_alice := alice.current_hp
	var before_redirect_bob := bob.current_hp
	h._p_focus(combat, bob)
	var redirect_damage_cast := await _cast_to(h, combat, bob, flat_spell, _position(combat, alice))
	var redirect_components: Array = combat.last_spell_damage_receipts
	var redirect_receipt: Dictionary = redirect_components[0] if not redirect_components.is_empty() else {}
	h._assert(redirect_damage_cast and alice.current_hp == before_redirect_alice and bob.current_hp < before_redirect_bob and int(redirect_receipt.get("damage_link", {}).get("amount_transferred", -1)) == 5, "031 renamed redirect control sends the full occurrence to the linked recipient with no second parent payment")
	alice.concentrating_on = {"spell_id": "shield_of_faith", "targets": [alice]}
	alice.add_modifier("roll", "save:CON", -100, 999)
	bob.spell_slots["1"] = 1
	h._p_focus(combat, bob)
	before_redirect_alice = alice.current_hp
	var untouched_cast := await _cast_to(h, combat, bob, flat_spell, _position(combat, alice))
	h._assert(untouched_cast and alice.current_hp == before_redirect_alice and not alice.concentrating_on.is_empty(), "031 R1 actual full-redirect control preserves the untouched original's concentration")
	alice.concentrating_on.clear()
	SpellEffects.remove(alice, _source_for(alice, bob), "regression_reset")
	bob.add_modifier("roll", "save:CON", -200, 999)
	bob.spell_slots["1"] = 2
	h._p_focus(combat, bob)
	await _cast_to(h, combat, bob, link_spell, _position(combat, alice))
	var failing_source := _source_for(alice, bob)
	h._p_focus(combat, bob)
	var failed_concentration_cast := await _cast_to(h, combat, bob, flat_spell, _position(combat, alice))
	h._assert(failed_concentration_cast and bob.concentrating_on.is_empty() and not SpellEffects.records(alice).has(failing_source) and int(bob.spell_slots["1"]) == 0, "031 R1 actual flat control drops the linked recipient's concentration without repeating parent payment")
	bob.spell_slots["1"] = 2
	h._p_focus(combat, bob)
	await _cast_to(h, combat, bob, link_spell, _position(combat, alice))
	h._p_focus(combat, bob)
	var failed_ordered_cast := await _cast_to(h, combat, bob, ordered_spell, _position(combat, alice))
	var failed_ordered_receipts: Array = combat.last_spell_damage_receipts
	h._assert(failed_ordered_cast and bob.concentrating_on.is_empty() and int(bob.spell_slots["1"]) == 0 and failed_ordered_receipts.size() == 2 and not failed_ordered_receipts[0].get("recipient_receipts", []).is_empty() and failed_ordered_receipts[1].get("recipient_receipts", []).is_empty(), "031 R1 actual ordered control settles linked concentration before the later step without repeating slot or Action payment")
	bob.spell_slots["1"] = 1
	h._p_focus(combat, bob)
	await _cast_to(h, combat, bob, link_spell, _position(combat, alice))
	var knockout_source := _source_for(alice, bob)
	bob.current_hp = 1
	enemy["attacks"] = [weapon_attack]
	for _attempt in 3:
		_seed_hit()
		await combat._execute_monster_attack(enemy, alice.character_name, 0)
		if bool(combat.last_monster_weapon_attack_result.get("hit", false)): break
	h._assert(bob.current_hp == 0 and bob.concentrating_on.is_empty() and not SpellEffects.records(alice).has(knockout_source), "031 R1 actual monster weapon hit ends linked concentration immediately on knockout (HP=%d concentration=%s source=%s retained=%s hit=%s)" % [bob.current_hp, str(bob.concentrating_on), knockout_source, str(SpellEffects.records(alice).has(knockout_source)), str(combat.last_monster_weapon_attack_result.get("hit", false))])
	enemy["attacks"] = saved_attacks
	bob.current_hp = 40
	bob.is_alive = true
	bob.death_save_failures = 0
	bob.remove_condition("unconscious")
	bob.add_modifier("roll", "save:CON", 200, 999)
	bob.spell_slots["1"] = 1
	h._p_focus(combat, bob)
	await _cast_to(h, combat, bob, redirect_spell, _position(combat, alice))
	var poison_source := _source_for(alice, bob)
	bob.current_hp = 1
	var poison_attack := weapon_attack.duplicate(true)
	poison_attack["damage"] = "0"
	poison_attack["extra_effects"] = [{"type": "poison_save", "save": "CON", "dc": 1000, "damage": "4", "duration": 1}]
	enemy["attacks"] = [poison_attack]
	var poison_original_hp := alice.current_hp
	for _attempt in 3:
		_seed_hit()
		await combat._execute_monster_attack(enemy, alice.character_name, 0)
		if bool(combat.last_monster_weapon_attack_result.get("hit", false)): break
	h._assert(alice.current_hp == poison_original_hp and bob.current_hp == 0 and bob.concentrating_on.is_empty() and not SpellEffects.records(alice).has(poison_source), "031 R1 poison-only full redirect retains its recipient receipt and ends linked concentration on knockout")
	enemy["attacks"] = saved_attacks
	bob.current_hp = 40
	bob.is_alive = true
	bob.death_save_failures = 0
	bob.remove_condition("unconscious")
	alice.remove_condition("poisoned")
	bob.spell_slots["1"] = 1
	h._p_focus(combat, bob)
	var combined_cast := await _cast_to(h, combat, bob, combined_spell, _position(combat, alice))
	h._assert(combined_cast and alice.has_condition("blessed") and not _source_for(alice, bob).is_empty(), "031 R3 actual cast grants a condition and damage link under the same source before saving")

	h._teardown_scene(combat)
	bob.known_spells.assign(prior_known_spells)
	bob.wizard_spellbook.assign(prior_spellbook)
	bob.feature_choices = prior_feature_choices
	bob.features = prior_features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var checkpoint_source := _source_for(alice, bob)
	var checkpoint_record: Dictionary = SpellEffects.records(alice).get(checkpoint_source, {})
	var checkpoint_slot := "batch_031_damage_links"
	var checkpoint_bad_slot := "batch_031_damage_links_malformed"
	var checkpoint_saved := not checkpoint_source.is_empty() and int(checkpoint_record.get("remaining_seconds", 0)) > 0 and SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(checkpoint_slot)
	h._assert(checkpoint_saved, "031 source-owned damage link writes through the supported Overworld checkpoint")
	if checkpoint_saved:
		var manifest := {"target_id": alice.character_id, "caster_id": bob.character_id, "source_id": checkpoint_source, "policy": checkpoint_record.get("damage_link", {}).duplicate(true), "conditions": checkpoint_record.get("conditions", []).duplicate(), "remaining_seconds": int(checkpoint_record.get("remaining_seconds", 0))}
		var manifest_file := FileAccess.open("user://batch_031_damage_links_manifest.json", FileAccess.WRITE)
		if manifest_file != null:
			manifest_file.store_string(JSON.stringify(manifest, "\t"))
			manifest_file.close()
		var malformed: Dictionary = SaveManager._read_save(checkpoint_slot).duplicate(true)
		var malformed_record: Dictionary = malformed.get("party", {}).get("characters", {}).get(alice.character_id, {}).get("spell_effects", {}).get(checkpoint_source, {})
		if not malformed_record.is_empty(): malformed_record["damage_link"]["share_percent"] = 1000
		var malformed_file := FileAccess.open(SaveManager.SAVE_DIR + checkpoint_bad_slot + ".sav", FileAccess.WRITE)
		if malformed_file != null:
			malformed_file.store_string(JSON.stringify(malformed, "\t"))
			malformed_file.close()
		var malformed_refused: bool = malformed_file != null and not SaveManager.load_game(checkpoint_bad_slot) and PartyManager.characters.get(alice.character_id) == alice and SpellEffects.records(alice).get(checkpoint_source, {}).get("damage_link", {}) == checkpoint_record.get("damage_link", {})
		h._assert(malformed_refused, "031 malformed saved link is rejected before the live party or exact source changes")
		for route in ["party", "players"]:
			for defect in ["link_policy", "condition_source"]:
				var bad: Dictionary = SaveManager._read_save(checkpoint_slot).duplicate(true)
				var dto: Dictionary = bad["party"]["characters"][alice.character_id] if route == "party" else bad["players"][0]["character"]
				if defect == "link_policy": dto["spell_effects"][checkpoint_source]["damage_link"]["share_percent"] = 1000
				else: dto["condition_sources"]["blessed"].erase(checkpoint_source)
				var bad_file := FileAccess.open(SaveManager.SAVE_DIR + checkpoint_bad_slot + ".sav", FileAccess.WRITE)
				if bad_file != null:
					bad_file.store_string(JSON.stringify(bad))
					bad_file.close()
				h._assert(bad_file != null and not SaveManager.load_game(checkpoint_bad_slot) and PartyManager.characters.get(alice.character_id) == alice and alice.has_condition("blessed") and SpellEffects.records(alice).has(checkpoint_source), "031 R3 malformed %s refuses on the %s full-save path before changing the live combined source" % [defect, route])
		OS.set_environment("B031_LINK_RELAUNCH_PHASE", "recover")
		var child_output: Array = []
		var child_exit := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/batch_031_fresh_relaunch.tscn"], child_output, true)
		OS.set_environment("B031_LINK_RELAUNCH_PHASE", "")
		var child_text := "\n".join(PackedStringArray(child_output))
		h._assert(child_exit == 0 and child_text.contains("BATCH 031 FRESH RELAUNCH PASSED"), "031 fresh Godot process restores the exact linked source, recipient and lifetime; exit=%d output=%s" % [child_exit, child_text])
	SaveManager.delete_save(checkpoint_slot)
	SaveManager.delete_save(checkpoint_bad_slot)

static func _seed_hit() -> void:
	# Both faces are safe if current visibility gives Advantage/Disadvantage.
	for candidate in 10000:
		seed(candidate)
		if randi_range(1, 20) == 15 and randi_range(1, 20) == 15:
			seed(candidate)
			return

static func _cast_to(h: Node, combat: Node, caster: Character, spell_id: String, target_hex: Vector2i) -> bool:
	combat.hud.update_hud(caster, combat.tracker)
	combat.hud._show_spell_selection()
	var selected := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == spell_id and not combat.hud.spell_list.is_item_disabled(index):
			selected = index
			break
	if selected < 0: return false
	combat.hud._on_spell_selected(selected)
	await Batch027Controls.answer(h, combat, "", "Level 1")
	await combat._on_hex_clicked(target_hex)
	for _frame in 240:
		await combat.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	return not combat._cast_in_progress and combat.pending_action_type.is_empty()

static func _position(combat: Node, actor: Character) -> Vector2i:
	for entry in combat.player_entities:
		if entry.get("character") == actor: return entry.get("hex_position", Vector2i.ZERO)
	return Vector2i.ZERO

static func _has_link(target: Character, caster: Character) -> bool:
	return not _source_for(target, caster).is_empty()

static func _source_for(target: Character, caster: Character) -> String:
	for source in SpellEffects.records(target):
		var record: Dictionary = SpellEffects.records(target)[source]
		if str(record.get("caster_id", "")) == caster.character_id and record.get("damage_link") is Dictionary:
			return str(source)
	return ""
