class_name Batch032Controls
extends RefCounted

static func cast(h: Node, combat: Node, caster: Character, suffix: String, target) -> bool:
	h._p_focus(combat, caster)
	var pos: Vector2i = target.get("hex_position", Vector2i.ZERO) if target is Dictionary else Batch031Controls._position(combat, target)
	return await Batch031Controls._cast_to(h, combat, caster, "fixture:b032_" + suffix, pos)

static func receipt(combat: Node, index: int = 0) -> Dictionary:
	var records: Array = combat.last_spell_damage_receipts
	var value: Dictionary = records[index] if index < records.size() else {}
	print("B032 RECEIPT ", JSON.stringify(value))
	return value

static func run(h: Node) -> void:
	h._enter_test("batch_032_damage_responses_flow")
	h._setup_world()
	Batch032Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	var spells: Array[String] = []
	for id in DataLoader.spells:
		if str(id).begins_with("fixture:b032_"): spells.append(str(id))
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b032_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	b.spell_slots["1"] = 40
	for actor in [a, b]:
		actor.max_hp = 100
		actor.current_hp = 50
		actor.temp_hp = 0
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(2, 0)
	enemy["current_hp"] = 100
	enemy["max_hp"] = 100
	combat._update_grid_entities()
	var slots := int(b.spell_slots["1"])
	var acquired := await cast(h, combat, b, "absorb", a)
	var source := source_for(a, "absorb")
	h._assert(acquired and not source.is_empty() and int(b.spell_slots["1"]) == slots - 1 and not combat.turn_budget.action_available, "032 actual picker/target grants exact absorption source for one slot and Action")
	a.feature_uses["damage_immunities"] = ["fire"]
	a.current_hp = 50
	var attack: Dictionary = enemy.attacks[0].duplicate(true)
	attack["damage"] = "7"
	attack["damage_type"] = "fire"
	attack["extra_effects"] = []
	attack["attack_bonus_override"] = 100
	enemy["attacks"] = [attack]
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	var weapon: Dictionary = combat.last_monster_weapon_attack_result
	var wr: Dictionary = weapon.get("damage_components", [{}])[0].get("receipt", {})
	print("B032 WEAPON ", JSON.stringify(wr))
	h._assert(weapon.get("hit", false) and a.current_hp == 57 and wr.raw == 7 and wr.prevented == 7 and wr.absorbed == 7 and wr.resolved == 0 and wr.hp_loss == 0, "032 actual incoming weapon heals immune target from incoming seven without losing HP")
	h._assert(wr.replacement_receipts[0].reacting_source_instance_id == source and wr.replacement_receipts[0].original_cause_actor_id == str(enemy.id), "032 weapon replacement captures exact reacting source and real monster cause")
	attack["damage_type"] = "cold"
	enemy["attacks"] = [attack]
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(a.current_hp == 50, "032 nonmatching weapon type does ordinary damage without absorption")
	a.current_hp = 99
	slots = int(b.spell_slots["1"])
	var fired := await cast(h, combat, b, "fire", a)
	var r := receipt(combat)
	h._assert(fired and a.current_hp == 100 and r.replacement_receipts[0].healed == 1 and r.replacement_receipts[0].requested_healing == 7 and int(b.spell_slots["1"]) == slots - 1, "032 flat control retains seven requested healing and actual capped one for one payment")
	SpellEffects.remove(a, source, "control_source_loss")
	a.current_hp = 50
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 50 and r.replacement_receipts.is_empty() and r.prevented == 7, "032 removal of exact absorption source leaves immunity without healing")
	await cast(h, combat, b, "renamed_partial", a)
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 50 and r.replacement_receipts.is_empty(), "032 changed resolved-stage source cannot qualify after immunity resolves to zero")
	a.feature_uses.erase("damage_immunities")
	a.feature_uses["damage_resistances"] = ["fire"]
	a.add_modifier("roll", "save:CON", -100, 999)
	await cast(h, combat, b, "mixed", a)
	r = receipt(combat)
	var cold := receipt(combat, 1)
	h._assert(a.current_hp == 47 and r.raw == 7 and r.resolved == 1 and r.prevented == 6 and r.hp_loss == 1 and r.replacement_receipts[0].measured == 3 and r.replacement_receipts[0].replaced == 2 and r.replacement_receipts[0].healed == 1 and cold.raw == 3 and cold.hp_loss == 3 and cold.replacement_receipts.is_empty(), "032 mixed control replaces two of resisted three, heals capped one, and settles unrelated cold component once")
	Batch032Checks.clear(a)
	a.feature_uses.erase("damage_resistances")
	a.current_hp = 50
	b.current_hp = 100
	a.temp_hp = 10
	await cast(h, combat, b, "mirror", a)
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 50 and a.temp_hp == 3 and r.hp_loss == 0 and b.current_hp == 93 and r.countereffect_receipts[0].measured == 7, "032 resolved counter responds to seven Temporary HP damage with zero actual HP loss")
	Batch032Checks.clear(a)
	await cast(h, combat, b, "renamed_mirror", a)
	a.temp_hp = 10
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(b.current_hp == 93 and r.countereffect_receipts.is_empty(), "032 renamed HP-loss policy declines zero HP loss rather than using raw damage")
	a.temp_hp = 0
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(b.current_hp == 89 and r.countereffect_receipts[0].amount == 4, "032 renamed half-HP-loss policy rounds seven up to four counter-damage")
	Batch032Checks.clear(a)
	await cast(h, combat, b, "mirror", a)
	await cast(h, combat, b, "mirror", b)
	a.current_hp = 100
	b.current_hp = 100
	slots = int(b.spell_slots["1"])
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	var first: Dictionary = r.countereffect_receipts[0]
	var second: Dictionary = first.damage_receipt.countereffect_receipts[0]
	var stopped: Dictionary = second.damage_receipt.countereffect_receipts[0]
	h._assert(a.current_hp == 86 and b.current_hp == 93 and stopped.limited and int(b.spell_slots["1"]) == slots - 1 and not combat.turn_budget.action_available, "032 two reciprocal sources terminate after two derived consequences with one parent payment")
	h._assert(first.root_occurrence_id == second.root_occurrence_id and second.parent_consequence_id == first.consequence_id and first.original_cause_actor_id == b.character_id and first.reacting_source_instance_id != second.reacting_source_instance_id, "032 finite feedback receipts retain root, parent, original cause and independent source instances")
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 72 and b.current_hp == 86 and int(r.root_occurrence_id) != int(first.root_occurrence_id), "032 later unrelated hit qualifies normally after the first feedback chain terminates")
	Batch032Checks.clear(a)
	Batch032Checks.clear(b)
	a.current_hp = 50
	b.current_hp = 100
	await cast(h, combat, b, "mirror", a)
	attack["damage_type"] = "fire"
	attack["extra_effects"] = [{"type": "poison_save", "save": "CON", "dc": 1000, "damage": "3", "duration": 1}]
	enemy["attacks"] = [attack]
	enemy["current_hp"] = 100
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	wr = combat.last_monster_weapon_attack_result.damage_components[0].receipt
	h._assert(a.current_hp == 40 and int(enemy.current_hp) == 93 and wr.countereffect_receipts[0].recipient_id == str(enemy.id), "032 incoming weapon counter hits the live monster once while original poison rider deals three once")
	a.remove_condition("poisoned")
	Batch032Checks.clear(a)
	await cast(h, combat, b, "absorb", enemy)
	enemy["damage_immunities"] = ["fire"]
	enemy["current_hp"] = 50
	await cast(h, combat, b, "fire", enemy)
	r = receipt(combat)
	h._assert(int(enemy.current_hp) == 57 and r.hp_loss == 0 and r.replacement_receipts[0].healed == 7, "032 actual shared spell grants incoming absorption to a live monster and heals despite its immunity")
	Batch032Checks.clear(enemy)
	enemy["damage_immunities"] = []
	await cast(h, combat, b, "prevented_heal", a)
	await cast(h, combat, b, "raw_heal", a)
	a.feature_uses["damage_resistances"] = ["fire"]
	a.current_hp = 40
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 44 and r.hp_loss == 3 and r.prevented == 4 and r.countereffect_receipts.size() == 2, "032 independent prevented and capped raw-healing sources both qualify without suppressing each other")
	Batch032Checks.clear(a)
	a.feature_uses.erase("damage_resistances")
	await cast(h, combat, b, "absorbed_heal", a)
	a.current_hp = 40
	a.temp_hp = 7
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 47 and r.absorbed == 7 and r.hp_loss == 0 and r.countereffect_receipts[0].healed == 7, "032 actual absorbed-based follow-up heals captured Temporary HP absorption")
	# The existing Ward owner absorbs before immunity and Temporary HP.
	a.features.append({"id": "fixture:b032_ward", "effects": [{"type": "damage_ward_pool", "pool_id": "b032_ward", "max_hp_flat_bonus": 10, "max_hp_level_multiplier": 0, "max_hp_ability": "INT"}]})
	WardRules.sync_pools_on_acquire(a)
	var ward := WardRules.pool_state(a, "b032_ward")
	ward["active"] = true
	ward["created_since_long_rest"] = true
	ward["current_hp"] = 2
	a.current_hp = 40
	a.temp_hp = 5
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(r.settlement_absorbed == 7 and r.absorbed == 5 and r.resolved == 5 and r.hp_loss == 0 and int(ward.current_hp) == 0 and a.temp_hp == 0 and a.current_hp == 47, "032 ward two plus Temporary HP five remain separate from resolved five and zero HP loss")
	Batch032Checks.clear(a)
	a.features = a.features.filter(func(f): return str(f.get("id", "")) != "fixture:b032_ward")
	a.damage_wards.clear()
	await cast(h, combat, b, "hp_loss_heal", a)
	a.current_hp = 3
	# Cancel the earlier -100 and guarantee a save would succeed. Reaching zero
	# must end concentration without letting the subsequent healing erase it.
	a.add_modifier("roll", "save:CON", 200, 999)
	a.concentrating_on = {"spell_id": "shield_of_faith", "targets": [a]}
	await cast(h, combat, b, "fire", a)
	r = receipt(combat)
	h._assert(a.current_hp == 3 and r.hp_loss == 3 and r.knocked_out and r.countereffect_receipts[0].healed == 3 and a.concentrating_on.is_empty(), "032 settled healing cannot erase the captured zero-HP concentration consequence")
	Batch032Checks.clear(a)
	await _pending(h, combat, a, b)
	# Acquire a durable source through controls, then preserve identity/deadline.
	await cast(h, combat, b, "absorb", a)
	await cast(h, combat, b, "raw_heal", a)
	h._teardown_scene(combat)
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	b.spell_slots["1"] = 1
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	await _checkpoint(h, a, b)
	GameManager.test_mode = true
	h._exit_test()

static func source_for(target, suffix: String) -> String:
	for source in SpellEffects.records(target):
		if str(SpellEffects.records(target)[source].get("spell_id", "")) == "fixture:b032_" + suffix: return str(source)
	return ""

static func _pending(h: Node, combat: Node, a: Character, b: Character) -> void:
	a.current_hp = 100
	a.temp_hp = 0
	b.current_hp = 100
	await cast(h, combat, b, "concentration_mirror", a)
	var source := source_for(a, "concentration_mirror")
	b.add_modifier("roll", "save:CON", -100, 999)
	b.features.append({"id": "rogue_stroke_of_luck"})
	b.feature_uses["rogue_stroke_of_luck"] = 1
	var slots := int(b.spell_slots["1"])
	h._p_focus(combat, b)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == "fixture:b032_ordered": combat.hud._on_spell_selected(index); break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	combat._on_hex_clicked(Batch031Controls._position(combat, a))
	var saw_pending := false
	for _frame in 240:
		await h.get_tree().process_frame
		for child in combat.hud.get_children():
			if child is ConfirmationDialog and child.visible and str(child.title).contains("Stroke of Luck"): saw_pending = true; break
		if saw_pending: break
	h._assert(saw_pending and a.current_hp == 93 and b.current_hp == 93 and int(b.spell_slots["1"]) == slots - 1 and combat._cast_in_progress, "032 actual counter-recipient concentration choice locks ordered cast after one damage/slot reservation")
	h._assert(await h._answer_class_dialog(combat.hud, "Stroke of Luck", false), "032 player declines the pending concentration rescue through its actual control")
	for _frame in 240:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(a.current_hp == 90 and b.current_hp == 93 and not SpellEffects.records(a).has(source) and b.concentrating_on.is_empty() and int(b.spell_slots["1"]) == slots - 1 and int(b.feature_uses.rogue_stroke_of_luck) == 1 and not combat.turn_budget.action_available, "032 refusal/source loss resumes later step once without counter replay, extra payment or rescue use")
	b.features = b.features.filter(func(f): return str(f.get("id", "")) != "rogue_stroke_of_luck")
	b.add_modifier("roll", "save:CON", 100, 999)

static func _checkpoint(h: Node, a: Character, b: Character) -> void:
	var slot := "batch_032_responses"
	var bad_slot := "batch_032_responses_malformed"
	var sources: Dictionary = SpellEffects.records(a).duplicate(true)
	var saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(slot)
	h._assert(saved and sources.size() == 2, "032 allowed Overworld checkpoint stores both source-specific policies without causal state")
	if not saved: return
	var manifest := {"target_id": a.character_id, "owner_id": b.character_id, "sources": sources, "hp": a.current_hp, "slots": b.spell_slots, "cast_serial": b.spell_cast_serial, "pid": OS.get_process_id()}
	var file := FileAccess.open("user://batch_032_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	for route in ["party", "players"]:
		for defect in ["policy", "recipient", "transient", "source"]:
			var bad: Dictionary = SaveManager._read_save(slot).duplicate(true)
			var dto: Dictionary = bad.party.characters[a.character_id] if route == "party" else bad.players[0].character
			var record: Dictionary = dto.spell_effects[sources.keys()[0]]
			match defect:
				"policy": record.damage_response["measure"] = "hp_loss"
				"recipient": record["recipient_id"] = b.character_id
				"transient": record["_damage_cause"] = {"root": 1}
				"source": record["caster_id"] = "missing_owner"
			var bad_file := FileAccess.open(SaveManager.SAVE_DIR + bad_slot + ".sav", FileAccess.WRITE)
			bad_file.store_string(JSON.stringify(bad))
			bad_file.close()
			h._assert(not SaveManager.load_game(bad_slot) and PartyManager.characters.get(a.character_id) == a and SpellEffects.records(a) == sources, "032 malformed %s on %s DTO refuses before replacing live party" % [defect, route])
	OS.set_environment("B032_RELAUNCH_PHASE", "recover")
	var child_output: Array = []
	var child_exit := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/batch_032_fresh_relaunch.tscn"], child_output, true)
	OS.set_environment("B032_RELAUNCH_PHASE", "")
	var child_text := "\n".join(PackedStringArray(child_output))
	h._assert(child_exit == 0 and child_text.contains("BATCH 032 FRESH RELAUNCH PASSED"), "032 fresh process restores source policies, identity, deadlines, HP and spent slots without replay; exit=%d output=%s" % [child_exit, child_text])
