class_name Batch039Controls
extends RefCounted

static func run(h: Node) -> void:
	h._enter_test("batch_039_created_actor_flow")
	h._setup_world()
	Batch039Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	var spells: Array[String] = [Batch039Checks.CONJURE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b039_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 2}]})
	b.spell_slots["2"] = 3
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
	enemy["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	# S-154: actual HUD cast creates the owned actor.
	await Batch036Controls.cast(h, combat, b, b, Batch039Checks.CONJURE)
	var source := str(b.concentrating_on.get("effect_source", ""))
	var live := CreatedActorRules.actors(b)
	h._assert(not source.is_empty() and live.size() == 1 and int(b.spell_slots["2"]) == 2 and CreatedActorRules.owner_of(live[0]) == b.character_id, "039 actual cast creates one owner-linked warden and pays one slot (source=%s)" % source)
	var joined := CreatedActorRules.attach(combat, b, Vector2i(0, 1))
	var warden: Character = live[0]
	h._assert(joined.size() == 1 and combat.player_entities.any(func(e): return e.get("combat_id", "") == warden.character_id), "039 actual warden joins the owner's side of the encounter")
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, warden.character_name, 0)
	h._assert(int(combat.last_monster_weapon_attack_result.get("target_ac", -1)) == 13 and warden.max_hp == 20, "039 actual monster attack reads the template AC (%d)" % int(combat.last_monster_weapon_attack_result.get("target_ac", -1)))
	# S-131: actual withering hit takes the maximum to 0.
	var saved_attacks: Array = enemy.get("attacks", []).duplicate(true)
	enemy["attacks"] = DataLoader.get_monster("fixture:b039_witherer").attacks.duplicate(true)
	var prior := {"max": a.max_hp, "hp": a.current_hp, "ac": a.base_ac}
	a.max_hp = 6
	a.current_hp = 6
	a.base_ac = 1
	Batch031Controls._seed_hit()
	await combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(a.max_hp == 0 and not a.is_alive and not a.is_downed() and str(a.corpse_state.get("remains", "")) == "dust" and str(a.corpse_state.get("cause", "")) == "withered", "039 actual withering hit reduces the maximum to 0: death with dust, not unconsciousness (max=%d)" % a.max_hp)
	h._assert(not CorpseRules.target_error(a, "revivify", int(GameManager.campaign_elapsed_seconds)).is_empty(), "039 actual revival refuses while the maximum is 0")
	enemy["attacks"] = saved_attacks
	var keep := b.concentrating_on.duplicate()
	CreatedActorRules.sync(b) # Record the damaged HP before the source record is withdrawn.
	var record: Dictionary = b.spell_effects[source].duplicate(true)
	b.spell_effects.erase(source)
	CreatedActorRules.attach(combat, b, Vector2i(0, 1))
	h._assert(not combat.player_entities.any(func(e): return e.get("combat_id", "") == warden.character_id), "039 actual encounter drops the warden once its source record is gone")
	b.spell_effects[source] = record
	b.concentrating_on = keep
	h._teardown_scene(combat)
	a.max_hp_sources.clear()
	a.corpse_state.clear()
	a.is_alive = true
	a.death_save_failures = 0
	a.max_hp = int(prior.max)
	a.current_hp = int(prior.hp)
	a.base_ac = int(prior.ac)
	# The fixture permission is not a saved spellbook entry; the cast record stays live.
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	# S-154 real SaveManager round trip with the live warden.
	var hp := warden.current_hp
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_039_created"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "039 actual real save with a live created actor (block='%s')" % block)
	if saved:
		CreatedActorRules._live.clear()
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back := CreatedActorRules.actors(nb) if nb != null else []
		h._assert(loaded and nb != null and nb != b and back.size() == 1 and back[0].character_id == warden.character_id and back[0].current_hp == hp and back[0].max_hp == 20 and back[0].base_ac == 13, "039 actual real load rebuilds the same warden with its damaged current HP (hp=%d loaded=%s same=%s back=%s)" % [hp, str(loaded), str(nb == b), str(back.map(func(x): return [x.character_id, x.current_hp, x.max_hp, x.base_ac]))])
		if nb != null:
			SpellEffects.end_concentration(nb, [nb])
			h._assert(CreatedActorRules.actors(nb).is_empty(), "039 actual concentration end after reload ends the warden")
			b = nb
		SaveManager.delete_save(slot)
	h._exit_test()
