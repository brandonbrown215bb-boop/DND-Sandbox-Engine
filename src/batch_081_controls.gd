class_name Batch081Controls
extends RefCounted
## Batch 081 (#45 follow-up, S-119): declared death fallback and explicit object
## destruction through the HUD spell picker and target click. Power Word Kill
## kills at 100 HP or fewer and otherwise deals 12d12 Psychic; the 073 death
## fixture with no fallback is still refused before paying; the object spell
## destroys a dropped item through the existing destruction handling and
## refuses creatures before paying; a real save/load and
## batch_081_declared_fallback_reload keep the results.

const SLOT := "batch_081_declared_fallback"
const SPELLS := [Batch081Checks.PWK, Batch073Checks.ENDING, Batch081Checks.UNMAKE]

static func _cast(h: Node, combat: Node, caster: Character, spell_id: String, target_hex: Vector2i, level: String) -> bool:
	combat.hud.update_hud(caster, combat.tracker)
	combat.hud._show_spell_selection()
	var selected := -1
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == spell_id and not combat.hud.spell_list.is_item_disabled(index):
			selected = index
			break
	if selected < 0: return false
	combat.hud._on_spell_selected(selected)
	await Batch027Controls.answer(h, combat, "", level)
	await combat._on_hex_clicked(target_hex)
	for _frame in 240:
		await combat.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	return not combat._cast_in_progress and combat.pending_action_type.is_empty()

static func run(h: Node) -> void:
	h._enter_test("batch_081_declared_fallback_flow")
	h._setup_world()
	Batch071Checks.load_fixtures()
	Batch081Checks.load_fixtures()
	var alice: Character = PlayerManager.get_player(0).get("character")
	var bob: Character = PlayerManager.get_player(1).get("character")
	var prior := {}
	for c in [alice, bob]:
		prior[c] = [c.known_spells.duplicate(), c.wizard_spellbook.duplicate(), c.feature_choices.duplicate(true), c.features.duplicate(true), c.spell_slots.duplicate(true)]
		c.known_spells.assign(SPELLS)
		c.wizard_spellbook.assign(SPELLS)
		c.feature_choices[c.get_spellcasting_feature_id()] = SPELLS.duplicate()
		c.features.append({"id": "fixture:b081_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": SPELLS.duplicate(), "ability": "INT", "maximum_spell_level": 9}]})
		c.spell_slots["1"] = 4
		c.spell_slots["9"] = 3
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
	var gob: Dictionary = combat.monster_entities[0]
	gob["hex_position"] = Vector2i(2, 0)
	gob["max_hp"] = 80
	gob["current_hp"] = 80
	var giant := Batch071Checks.monster("b081_giant", 150)
	giant["hex_position"] = Vector2i(3, 0)
	combat.monster_entities.append(giant)
	var inv := Inventory.new()
	inv.add_item("dagger")
	var record: Dictionary = inv.backpack_instances()[0]
	var item := CombatObjectRules.make_dropped_item(record, Vector2i(2, 2), alice.character_id)
	combat.dropped_combat_items.append(item)
	combat._update_grid_entities()
	Batch071Controls._turn(combat, alice)
	var dead := Batch071Checks.monster("b081_corpse", 0)
	dead["is_alive"] = false
	dead["zero_hp_aftermath"] = {"outcome": "death", "remains": "intact", "cause": "earlier"}
	dead["hex_position"] = Vector2i(1, 2)
	combat.monster_entities.append(dead)
	combat._update_grid_entities()
	await _cast(h, combat, alice, Batch081Checks.PWK, Vector2i(1, 2), "Level 9")
	h._assert(int(alice.spell_slots["9"]) == 3 and combat.turn_budget.action_available and dead.zero_hp_aftermath.cause == "earlier", "081 live Power Word Kill at an already-dead creature is refused before any slot or Action")
	var ok: bool = await _cast(h, combat, alice, Batch081Checks.PWK, Vector2i(2, 0), "Level 9")
	h._assert(ok and not bool(gob.is_alive) and int(gob.current_hp) == 0 and gob.get("zero_hp_aftermath", {}).get("cause", "") == "power_word_kill" and int(alice.spell_slots["9"]) == 2 and not combat.turn_budget.action_available, "081 live Power Word Kill kills the 80-HP goblin outright; one 9th-level slot and the Action paid")
	Batch071Controls._turn(combat, alice)
	ok = await _cast(h, combat, alice, Batch081Checks.PWK, Vector2i(3, 0), "Level 9")
	var dealt := 150 - int(giant.current_hp)
	h._assert(ok and bool(giant.is_alive) and dealt >= 12 and dealt <= 144 and not giant.has("zero_hp_aftermath") and int(alice.spell_slots["9"]) == 1, "081 live Power Word Kill on the 150-HP creature deals 12d12 Psychic instead (%d) and records no death" % dealt)
	Batch071Controls._turn(combat, bob)
	await _cast(h, combat, bob, Batch073Checks.ENDING, Vector2i(3, 0), "Level 1")
	h._assert(int(giant.current_hp) == 150 - dealt and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "081 live a death effect with no declared fallback is refused above its limit; no damage, no slot")
	await _cast(h, combat, bob, Batch081Checks.UNMAKE, Vector2i(3, 0), "Level 1")
	h._assert(bool(giant.is_alive) and int(giant.current_hp) == 150 - dealt and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "081 live the object spell at a creature is refused before any slot or Action")
	var ring := Batch081Checks.loose_object("b081_live_ring", 5, true)
	ring["position"] = [4, 2]
	combat.dropped_combat_items.append(ring)
	combat._update_grid_entities()
	await _cast(h, combat, bob, Batch081Checks.UNMAKE, Vector2i(4, 2), "Level 1")
	h._assert(int(ring.hp) == 5 and not bool(ring.get("removed", false)) and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available, "081 review live: a magical object is refused before any slot or Action")
	ok = await _cast(h, combat, bob, Batch081Checks.UNMAKE, Vector2i(2, 2), "Level 1")
	h._assert(ok and int(item.hp) == 0 and bool(item.get("copy_destroyed", false)) and bool(item.get("removed", false)) and str(item.get("destroyed_cause", "")) == "unmade_object" and int(bob.spell_slots["1"]) == 3 and CombatObjectRules.at(combat.hex_grid, Vector2i(2, 2)).is_empty(), "081 live the dropped dagger is destroyed through the existing destruction handling; one slot paid")
	Batch071Controls._turn(combat, bob)
	await _cast(h, combat, bob, Batch081Checks.UNMAKE, Vector2i(2, 2), "Level 1")
	h._assert(int(bob.spell_slots["1"]) == 3 and combat.turn_budget.action_available, "081 review live: the destroyed dagger's square refuses a second cast before any slot or Action")
	# Character target for the save: Bob has more than 100 HP, then Alice falls to it.
	Batch071Controls._turn(combat, alice)
	bob.max_hp = 200
	bob.current_hp = 130
	ok = await _cast(h, combat, alice, Batch081Checks.PWK, Vector2i(0, 1), "Level 9")
	var bob_hp := bob.current_hp
	h._assert(ok and not bob.is_dead() and bob_hp < 130 and bob_hp >= 130 - 144 and bob.corpse_state.is_empty(), "081 live a 130-HP ally takes the Psychic fallback (%d HP left)" % bob_hp)
	alice.current_hp = 90
	Batch071Controls._turn(combat, bob)
	bob.spell_slots["9"] = 1
	ok = await _cast(h, combat, bob, Batch081Checks.PWK, Vector2i.ZERO, "Level 9")
	var serial := alice.body_death_serial
	h._assert(ok and alice.is_dead() and alice.corpse_state.get("cause", "") == "power_word_kill" and alice.death_save_failures == 3 and int(bob.spell_slots["9"]) == 0, "081 live a 90-HP ally dies outright from Power Word Kill")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	for c in prior:
		c.known_spells.assign(prior[c][0]); c.wizard_spellbook.assign(prior[c][1]); c.feature_choices = prior[c][2]; c.features = prior[c][3]; c.spell_slots = prior[c][4]
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "081 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var na: Character = PartyManager.characters.get(alice.character_id, null)
		var nb: Character = PartyManager.characters.get(bob.character_id, null)
		h._assert(loaded and na != null and nb != null and na.is_dead() and na.body_death_serial == serial and na.corpse_state.get("cause", "") == "power_word_kill" and not nb.is_dead() and nb.current_hp == bob_hp, "081 live real load keeps the one death and the fallback damage")
		var f := FileAccess.open("user://batch_081_ids.txt", FileAccess.WRITE)
		f.store_string("%s|%d|%s|%d" % [alice.character_id, serial, bob.character_id, bob_hp])
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_081_declared_fallback_reload")
	Batch081Checks.load_fixtures()
	var parts := FileAccess.get_file_as_string("user://batch_081_ids.txt").strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var na: Character = PartyManager.characters.get(parts[0], null) if parts.size() == 4 else null
	var nb: Character = PartyManager.characters.get(parts[2], null) if parts.size() == 4 else null
	h._assert(loaded and na != null and na.is_dead() and na.body_death_serial == int(parts[1]) and na.corpse_state.get("cause_source", {}).get("policy_id", "") == "power_word_kill", "081 fresh process the Power Word Kill death loads once")
	h._assert(nb != null and not nb.is_dead() and nb.current_hp == int(parts[3]) and nb.corpse_state.is_empty(), "081 fresh process the ally that took the fallback stays alive at the same HP")
	h._assert(na != null and not ZeroHpAftermathRules.explicit_cast_error(na, DataLoader.get_spell(Batch081Checks.PWK)).is_empty(), "081 fresh process the loaded corpse is still refused")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://batch_081_ids.txt"))
	h._exit_test()
