class_name Batch040Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_040_successor_projection_flow")
	h._setup_world()
	Batch040Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	var prior_slots := b.spell_slots.duplicate(true)
	var spells: Array[String] = [Batch040Checks.REAP, Batch040Checks.SHIFT, Batch040Checks.MANTLE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b040_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 3}]})
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
	# S-163: an actual HUD cast with two declared forms and no selection is refused.
	b.spell_slots = {"2": 1}
	var features_before := b.features.size()
	await Batch036Controls.cast(h, combat, b, b, Batch040Checks.SHIFT)
	h._assert(not ActorProjectionRules.is_projected(b) and b.features.size() == features_before and int(b.spell_slots.get("2", 0)) == 1, "040 actual cast without a selected form leaves the actor unprojected and the slot unspent (slots=%s)" % str(b.spell_slots))
	# The single-form projection through the same production cast.
	b.spell_slots = {"3": 1}
	var int_before := b.ability_scores.get_score("INT")
	var hp_before := b.current_hp
	await Batch036Controls.cast(h, combat, b, b, Batch040Checks.MANTLE)
	h._assert(ActorProjectionRules.is_projected(b) and b.get_creature_type() == "fey" and b.ability_scores.get_score("INT") == 9 and b.current_hp == hp_before and b.features.size() == features_before and ActorProjectionRules.can_cast_spells(b), "040 actual cast projects into the declared form, keeping HP, features and casting (type=%s)" % b.get_creature_type())
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, b.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == 15, "040 actual monster attack reads the projected form's AC (%d)" % int(combat.last_monster_weapon_attack_result.get("target_ac", -1)))
	# S-120: an actual reaping cast kills the creature and a successor rises where it fell.
	enemy["current_hp"] = 10
	enemy["is_alive"] = true
	enemy["creature_type"] = "humanoid"
	b.spell_slots = {"1": 2}
	await Batch036Controls.cast(h, combat, b, enemy, Batch040Checks.REAP)
	var husks := AftermathSuccessorRules.actors(enemy)
	var joined := AftermathSuccessorRules.attach(combat, enemy)
	var placed: Array = combat.player_entities.filter(func(e): return e.get("combat_id", "") in joined)
	h._assert(not bool(enemy.get("is_alive", true)) and husks.size() == 1 and joined.size() == 1 and placed.size() == 1 and placed[0].hex_position == Vector2i(1, 0) and placed[0].created_owner_id == b.character_id, "040 actual final death raises one successor at the creature's hex on the caster's side (joined=%s)" % str(joined))
	h._assert(AftermathSuccessorRules.attach(combat, enemy).is_empty() and AftermathSuccessorRules.actors(enemy).size() == 1, "040 actual successor is not duplicated by a second placement")
	# The same carrier against a party member records the successor with the remains.
	var prior_a := {"hp": a.current_hp, "max": a.max_hp}
	a.current_hp = 12
	await Batch036Controls.cast(h, combat, b, a, Batch040Checks.REAP)
	var risen := AftermathSuccessorRules.actors(a)
	h._assert(a.is_dead() and str(a.corpse_state.get("remains", "")) == "bones" and risen.size() == 1 and CorpseRules.target_error(a, "revivify", int(GameManager.campaign_elapsed_seconds)) == "These remains have risen as a successor.", "040 actual party death records its successor and refuses revival while it stands")
	risen[0].current_hp = 9
	h._teardown_scene(combat)
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	b.spell_slots = prior_slots
	# Real SaveManager round trip: projected caster and the remains' successor.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_040_successor"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "040 actual real save with a projection and a successor (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var back := AftermathSuccessorRules.actors(na) if na != null else []
		h._assert(loaded and nb != null and nb != b and ActorProjectionRules.is_projected(nb) and nb.get_creature_type() == "fey" and nb.get_ac() == 15 and back.size() == 1 and back[0].current_hp == 9 and back[0].max_hp == 15, "040 actual real load keeps the projection and rebuilds the same successor (back=%s)" % str(back.map(func(x): return [x.character_id, x.current_hp])))
		if nb != null:
			SpellEffects.end_concentration(nb, [nb])
			h._assert(not ActorProjectionRules.is_projected(nb) and nb.ability_scores.get_score("INT") == int_before and nb.features.size() == prior_features.size() and nb.get_creature_type() != "fey", "040 actual concentration end after reload restores the same actor")
			b = nb
		if na != null: a = na
		SaveManager.delete_save(slot)
	a.corpse_state.clear()
	a.is_alive = true
	a.death_save_failures = 0
	a.max_hp = int(prior_a.max)
	a.current_hp = int(prior_a.hp)
	h._exit_test()
